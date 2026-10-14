<?php
// Contas: cadastro com senha (e-mail confirmado por código), login, "esqueci a senha", Google e perfil
// (nome de usuário + país/estado/cidade). Sessões por token Bearer.
declare(strict_types=1);

const SESSION_DAYS = 180;
const CODE_MINUTES = 15;
const CODE_MAX_ATTEMPTS = 5;
const PASSWORD_MIN = 8;
const GOOGLE_WEB_CLIENT_ID = '191594960482-stdsa9ahvrou6k025ftecf5vhs2pj1ll.apps.googleusercontent.com';
const RESERVED_USERNAMES = ['admin', 'administrator', 'root', 'support', 'help', 'waxclub', 'api', 'system', 'moderator', 'staff'];

function normalize_email(?string $email): ?string
{
    $email = strtolower(trim((string) $email));
    if ($email === '' || strlen($email) > 254 || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return null;
    }
    return $email;
}

/** Nome de usuário: 3 a 20 caracteres, letras minúsculas, números, ponto e sublinhado. */
function normalize_username(?string $u): ?string
{
    $u = strtolower(trim((string) $u));
    if (!preg_match('/^[a-z0-9._]{3,20}$/', $u) || $u[0] === '.' || substr($u, -1) === '.' || strpos($u, '..') !== false) {
        return null;
    }
    return in_array($u, RESERVED_USERNAMES, true) ? null : $u;
}

function username_taken(string $username, int $exceptUserId = 0): bool
{
    $q = db()->prepare('SELECT COUNT(*) FROM users WHERE username = ? AND id <> ?');
    $q->execute([$username, $exceptUserId]);
    return (int) $q->fetchColumn() > 0;
}

function valid_password($p): ?string
{
    $p = is_string($p) ? $p : '';
    return strlen($p) >= PASSWORD_MIN && strlen($p) <= 128 ? $p : null;
}

function user_json(array $u): array
{
    $complete = $u['username'] !== null && $u['country_code'] !== null && $u['city_id'] !== null;
    return [
        'id' => (int) $u['id'],
        'email' => $u['email'],
        'username' => $u['username'],
        'displayName' => $u['display_name'],
        'countryCode' => $u['country_code'],
        'stateCode' => $u['state_code'],
        'stateName' => $u['state_name'],
        'cityId' => $u['city_id'] !== null ? (int) $u['city_id'] : null,
        'city' => $u['city'],
        'emailVerified' => $u['email_verified_at'] !== null,
        'hasPassword' => $u['password_hash'] !== null,
        'google' => $u['google_sub'] !== null,
        'profileComplete' => $complete,
        'createdAt' => sql_to_iso($u['created_at']),
    ];
}

function load_user(int $id): array
{
    $q = db()->prepare('SELECT * FROM users WHERE id = ?');
    $q->execute([$id]);
    return $q->fetch();
}

function user_by_email(string $email): ?array
{
    $q = db()->prepare('SELECT * FROM users WHERE email = ?');
    $q->execute([$email]);
    return $q->fetch() ?: null;
}

/** Cria a sessão e devolve o token (só o hash fica no banco). */
function open_session(int $userId): array
{
    $token = 'wx_' . bin2hex(random_bytes(32));
    $device = str_field(body(), 'device', 100);
    $now = now_sql();
    db()->prepare('INSERT INTO sessions (user_id, token_hash, device, created_at, last_used_at, expires_at)
                   VALUES (?, ?, ?, ?, ?, ?)')
        ->execute([$userId, hash('sha256', $token), $device, $now, $now, now_sql('+' . SESSION_DAYS . ' days')]);
    db()->prepare('UPDATE users SET last_login_at = ? WHERE id = ?')->execute([$now, $userId]);
    return ['token' => $token, 'user' => user_json(load_user($userId))];
}

/** Usuário da sessão atual; responde 401 se não houver. A validade se renova a cada uso. */
function require_user(): array
{
    $token = bearer_token();
    if ($token === null) {
        fail(401, 'unauthorized');
    }
    $q = db()->prepare('SELECT s.id AS session_id, s.last_used_at, u.* FROM sessions s
                        JOIN users u ON u.id = s.user_id
                        WHERE s.token_hash = ? AND s.expires_at > ?');
    $q->execute([hash('sha256', $token), now_sql()]);
    $row = $q->fetch();
    if (!$row) {
        fail(401, 'unauthorized');
    }
    // grava no máximo uma vez por hora
    if (strtotime($row['last_used_at'] . ' UTC') < time() - 3600) {
        db()->prepare('UPDATE sessions SET last_used_at = ?, expires_at = ? WHERE id = ?')
            ->execute([now_sql(), now_sql('+' . SESSION_DAYS . ' days'), $row['session_id']]);
    }
    return $row;
}

function find_or_create_user(string $email): int
{
    $u = user_by_email($email);
    if ($u) {
        return (int) $u['id'];
    }
    db()->prepare('INSERT INTO users (email, created_at) VALUES (?, ?)')->execute([$email, now_sql()]);
    return (int) db()->lastInsertId();
}

// ---------- códigos de 6 dígitos por e-mail ----------

function code_hash(string $email, string $purpose, string $code): string
{
    // códigos de login antigos (1.3.20) não tinham finalidade no hash
    return hash('sha256', $purpose === 'login' ? "$email|$code" : "$email|$purpose|$code");
}

/** Gera e envia um código (até 5 por hora por e-mail e 20 por IP). */
function issue_code(string $email, string $purpose): void
{
    $hourAgo = now_sql('-1 hour');
    $byEmail = db()->prepare('SELECT COUNT(*) FROM login_codes WHERE email = ? AND created_at > ?');
    $byEmail->execute([$email, $hourAgo]);
    $byIp = db()->prepare('SELECT COUNT(*) FROM login_codes WHERE ip = ? AND created_at > ?');
    $byIp->execute([client_ip(), $hourAgo]);
    if ((int) $byEmail->fetchColumn() >= 5 || (int) $byIp->fetchColumn() >= 20) {
        fail(429, 'too_many_requests');
    }
    $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    db()->prepare('INSERT INTO login_codes (email, code_hash, purpose, ip, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)')
        ->execute([$email, code_hash($email, $purpose, $code), $purpose, client_ip(), now_sql(), now_sql('+' . CODE_MINUTES . ' minutes')]);

    $texts = [
        'login' => ["Your WaxClub code: $code", 'Your WaxClub sign-in code is:'],
        'verify' => ["Confirm your WaxClub email: $code", 'Welcome to WaxClub! Enter this code in the app to confirm your email:'],
        'reset' => ["Reset your WaxClub password: $code", 'Enter this code in the app to choose a new password:'],
    ];
    [$subject, $intro] = $texts[$purpose];
    $text = "$intro\r\n\r\n    $code\r\n\r\n"
        . 'It expires in ' . CODE_MINUTES . " minutes. If you didn't ask for it, you can ignore this email.\r\n\r\n"
        . "WaxClub - Vinyl Social Club\r\nhttps://waxclub.com.br\r\n";
    if (!send_mail($email, $subject, $text)) {
        fail(502, 'email_failed', ['stage' => $GLOBALS['smtp_error'] ?? 'mail']);
    }
}

/** Confere o código mais recente daquela finalidade; responde 401 se errado ou vencido. */
function consume_code(string $email, string $purpose, $rawCode): void
{
    $code = preg_replace('/\D/', '', (string) $rawCode);
    if (strlen($code) !== 6) {
        fail(422, 'invalid_code');
    }
    $q = db()->prepare('SELECT * FROM login_codes WHERE email = ? AND purpose = ? AND used_at IS NULL AND expires_at > ?
                        ORDER BY id DESC LIMIT 1');
    $q->execute([$email, $purpose, now_sql()]);
    $row = $q->fetch();
    if (!$row || (int) $row['attempts'] >= CODE_MAX_ATTEMPTS) {
        fail(401, 'code_expired');
    }
    if (!hash_equals($row['code_hash'], code_hash($email, $purpose, $code))) {
        db()->prepare('UPDATE login_codes SET attempts = attempts + 1 WHERE id = ?')->execute([$row['id']]);
        fail(401, 'invalid_code', ['attemptsLeft' => max(0, CODE_MAX_ATTEMPTS - 1 - (int) $row['attempts'])]);
    }
    db()->prepare('UPDATE login_codes SET used_at = ? WHERE id = ?')->execute([now_sql(), $row['id']]);
}

// ---------- cadastro e login com senha ----------

/** Corpo comum de cadastro/perfil: nome de usuário + local. Devolve as colunas a gravar. */
function profile_fields(array $b, int $exceptUserId = 0): array
{
    $username = normalize_username($b['username'] ?? null);
    if ($username === null) {
        fail(422, 'invalid_username');
    }
    if (username_taken($username, $exceptUserId)) {
        fail(409, 'username_taken');
    }
    return ['username' => $username] + validate_location($b);
}

// POST /v1/auth/register {email, password, username, countryCode, stateCode?, cityId}
function auth_register(): void
{
    $b = body();
    $email = normalize_email($b['email'] ?? null);
    if ($email === null) {
        fail(422, 'invalid_email');
    }
    $password = valid_password($b['password'] ?? null);
    if ($password === null) {
        fail(422, 'weak_password', ['min' => PASSWORD_MIN]);
    }
    $existing = user_by_email($email);
    if ($existing && $existing['email_verified_at'] !== null) {
        fail(409, 'email_taken');
    }
    $cols = profile_fields($b, $existing ? (int) $existing['id'] : 0);
    $cols['password_hash'] = password_hash($password, PASSWORD_DEFAULT);
    if ($existing) {
        // cadastro anterior não confirmado: os dados novos substituem os antigos
        $set = implode(', ', array_map(fn($c) => "$c = ?", array_keys($cols)));
        db()->prepare("UPDATE users SET $set WHERE id = ?")->execute([...array_values($cols), $existing['id']]);
    } else {
        $cols['email'] = $email;
        $cols['created_at'] = now_sql();
        $names = implode(', ', array_keys($cols));
        $marks = implode(', ', array_fill(0, count($cols), '?'));
        db()->prepare("INSERT INTO users ($names) VALUES ($marks)")->execute(array_values($cols));
    }
    issue_code($email, 'verify');
    json_out(200, ['pending' => 'verify_email', 'email' => $email, 'expiresInMinutes' => CODE_MINUTES]);
}

// POST /v1/auth/verify-email {email, code, device?}
function auth_verify_email(): void
{
    $email = normalize_email(body()['email'] ?? null);
    $user = $email ? user_by_email($email) : null;
    if (!$user) {
        fail(401, 'code_expired');
    }
    consume_code($email, 'verify', body()['code'] ?? '');
    db()->prepare('UPDATE users SET email_verified_at = COALESCE(email_verified_at, ?) WHERE id = ?')
        ->execute([now_sql(), $user['id']]);
    json_out(200, open_session((int) $user['id']));
}

// POST /v1/auth/verify-email/resend {email}
function auth_verify_resend(): void
{
    $email = normalize_email(body()['email'] ?? null);
    $user = $email ? user_by_email($email) : null;
    if ($user && $user['email_verified_at'] === null) {
        issue_code($email, 'verify');
    }
    json_out(200, ['sent' => true]);
}

// POST /v1/auth/login {email, password, device?}
function auth_login(): void
{
    $email = normalize_email(body()['email'] ?? null);
    $password = (string) (body()['password'] ?? '');
    if ($email === null || $password === '') {
        fail(422, 'invalid_credentials');
    }
    $since = now_sql('-15 minutes');
    $byEmail = db()->prepare('SELECT COUNT(*) FROM auth_failures WHERE email = ? AND created_at > ?');
    $byEmail->execute([$email, $since]);
    $byIp = db()->prepare('SELECT COUNT(*) FROM auth_failures WHERE ip = ? AND created_at > ?');
    $byIp->execute([client_ip(), $since]);
    if ((int) $byEmail->fetchColumn() >= 10 || (int) $byIp->fetchColumn() >= 30) {
        fail(429, 'too_many_attempts');
    }
    $user = user_by_email($email);
    if (!$user || $user['password_hash'] === null || !password_verify($password, $user['password_hash'])) {
        db()->prepare('INSERT INTO auth_failures (email, ip, created_at) VALUES (?, ?, ?)')
            ->execute([$email, client_ip(), now_sql()]);
        // conta sem senha (Google ou código do e-mail): o app oferece "esqueci a senha"
        fail(401, $user && $user['password_hash'] === null ? 'no_password' : 'invalid_credentials');
    }
    if ($user['email_verified_at'] === null) {
        issue_code($email, 'verify');
        fail(403, 'email_not_verified', ['email' => $email]);
    }
    if (password_needs_rehash($user['password_hash'], PASSWORD_DEFAULT)) {
        db()->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
            ->execute([password_hash($password, PASSWORD_DEFAULT), $user['id']]);
    }
    json_out(200, open_session((int) $user['id']));
}

// POST /v1/auth/password/forgot {email} — mesma resposta exista ou não a conta
function auth_password_forgot(): void
{
    $email = normalize_email(body()['email'] ?? null);
    if ($email === null) {
        fail(422, 'invalid_email');
    }
    if (user_by_email($email)) {
        issue_code($email, 'reset');
    }
    json_out(200, ['sent' => true, 'expiresInMinutes' => CODE_MINUTES]);
}

// POST /v1/auth/password/reset {email, code, password, device?}
function auth_password_reset(): void
{
    $email = normalize_email(body()['email'] ?? null);
    $user = $email ? user_by_email($email) : null;
    if (!$user) {
        fail(401, 'code_expired');
    }
    $password = valid_password(body()['password'] ?? null);
    if ($password === null) {
        fail(422, 'weak_password', ['min' => PASSWORD_MIN]);
    }
    consume_code($email, 'reset', body()['code'] ?? '');
    // o código chegou no e-mail: o endereço fica confirmado; as outras sessões são encerradas
    db()->prepare('UPDATE users SET password_hash = ?, email_verified_at = COALESCE(email_verified_at, ?) WHERE id = ?')
        ->execute([password_hash($password, PASSWORD_DEFAULT), now_sql(), $user['id']]);
    db()->prepare('DELETE FROM sessions WHERE user_id = ?')->execute([$user['id']]);
    db()->prepare('DELETE FROM auth_failures WHERE email = ?')->execute([$email]);
    json_out(200, open_session((int) $user['id']));
}

// GET /v1/auth/username-available?u=nome
function auth_username_available(): void
{
    $u = normalize_username($_GET['u'] ?? null);
    json_out(200, ['valid' => $u !== null, 'available' => $u !== null && !username_taken($u)]);
}

// ---------- login antigo por código (app 1.3.20) ----------

// POST /v1/auth/email/start {email}
function auth_email_start(): void
{
    $email = normalize_email(body()['email'] ?? null);
    if ($email === null) {
        fail(422, 'invalid_email');
    }
    issue_code($email, 'login');
    json_out(200, ['sent' => true, 'expiresInMinutes' => CODE_MINUTES, 'delivery' => $GLOBALS['mail_delivery'] ?? 'mail']);
}

// POST /v1/auth/email/verify {email, code, device?}
function auth_email_verify(): void
{
    $email = normalize_email(body()['email'] ?? null);
    if ($email === null) {
        fail(422, 'invalid_code');
    }
    consume_code($email, 'login', body()['code'] ?? '');
    $id = find_or_create_user($email);
    db()->prepare('UPDATE users SET email_verified_at = COALESCE(email_verified_at, ?) WHERE id = ?')->execute([now_sql(), $id]);
    json_out(200, open_session($id));
}

// ---------- Google ----------

// POST /v1/auth/google {idToken, device?}
function auth_google(): void
{
    // ID do cliente "Aplicativo da Web" do projeto Google Cloud "waxclub" (público; o .env pode trocar ou somar outros)
    $clientIds = array_filter(array_map('trim', explode(',', cfg('GOOGLE_CLIENT_IDS', GOOGLE_WEB_CLIENT_ID))));
    if (!$clientIds) {
        fail(503, 'google_not_configured');
    }
    $idToken = (string) (body()['idToken'] ?? '');
    if ($idToken === '' || strlen($idToken) > 4096) {
        fail(422, 'invalid_token');
    }
    // O próprio Google confere assinatura e validade do token
    $ch = curl_init('https://oauth2.googleapis.com/tokeninfo?id_token=' . rawurlencode($idToken));
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10]);
    $resp = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    $info = is_string($resp) ? json_decode($resp, true) : null;
    if ($status !== 200 || !is_array($info)) {
        fail(401, 'invalid_token');
    }
    $issOk = in_array($info['iss'] ?? '', ['accounts.google.com', 'https://accounts.google.com'], true);
    $verified = ($info['email_verified'] ?? '') === 'true' || ($info['email_verified'] ?? false) === true;
    $email = normalize_email($info['email'] ?? null);
    if (!$issOk || !in_array($info['aud'] ?? '', $clientIds, true) || !$verified || $email === null
        || (int) ($info['exp'] ?? 0) < time() || empty($info['sub'])) {
        fail(401, 'invalid_token');
    }
    $sub = substr((string) $info['sub'], 0, 64);

    $q = db()->prepare('SELECT id FROM users WHERE google_sub = ?');
    $q->execute([$sub]);
    $id = $q->fetchColumn();
    if (!$id) {
        // mesma conta do login por e-mail, se o endereço já existir
        $id = find_or_create_user($email);
        db()->prepare('UPDATE users SET google_sub = ? WHERE id = ? AND google_sub IS NULL')->execute([$sub, $id]);
        $name = isset($info['name']) ? mb_substr((string) $info['name'], 0, 100) : null;
        if ($name) {
            db()->prepare('UPDATE users SET display_name = ? WHERE id = ? AND display_name IS NULL')->execute([$name, $id]);
        }
    }
    // o Google já confirmou o e-mail
    db()->prepare('UPDATE users SET email_verified_at = COALESCE(email_verified_at, ?) WHERE id = ?')->execute([now_sql(), $id]);
    json_out(200, open_session((int) $id));
}

// ---------- sessão e perfil ----------

// POST /v1/auth/logout
function auth_logout(): void
{
    $user = require_user();
    db()->prepare('DELETE FROM sessions WHERE id = ?')->execute([$user['session_id']]);
    json_out(200, ['ok' => true]);
}

// GET /v1/me
function me_get(): void
{
    json_out(200, ['user' => user_json(require_user())]);
}

// PATCH /v1/me {username?, countryCode?, stateCode?, cityId?, displayName?}
// Nome de usuário e local vão juntos (completar o cadastro de quem entrou pelo Google ou pelo código).
function me_patch(): void
{
    $user = require_user();
    $b = body();
    $cols = [];
    if (array_key_exists('username', $b) || array_key_exists('countryCode', $b)) {
        $cols = profile_fields($b + ['username' => $user['username']], (int) $user['id']);
    }
    if (array_key_exists('displayName', $b)) {
        $cols['display_name'] = str_field($b, 'displayName', 100);
    }
    if ($cols) {
        $set = implode(', ', array_map(fn($c) => "$c = ?", array_keys($cols)));
        db()->prepare("UPDATE users SET $set WHERE id = ?")->execute([...array_values($cols), $user['id']]);
    }
    json_out(200, ['user' => user_json(load_user((int) $user['id']))]);
}

// DELETE /v1/me — apaga a conta, as sessões, a coleção e as audições
function me_delete(): void
{
    $user = require_user();
    db()->prepare('DELETE FROM login_codes WHERE email = ?')->execute([$user['email']]);
    db()->prepare('DELETE FROM auth_failures WHERE email = ?')->execute([$user['email']]);
    db()->prepare('DELETE FROM users WHERE id = ?')->execute([$user['id']]);
    json_out(200, ['deleted' => true]);
}
