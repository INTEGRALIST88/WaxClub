<?php
// Contas: login por código no e-mail (magic code) ou Google, sessões por token Bearer.
declare(strict_types=1);

const SESSION_DAYS = 180;
const CODE_MINUTES = 15;
const CODE_MAX_ATTEMPTS = 5;

function normalize_email(?string $email): ?string
{
    $email = strtolower(trim((string) $email));
    if ($email === '' || strlen($email) > 254 || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return null;
    }
    return $email;
}

function code_hash(string $email, string $code): string
{
    return hash('sha256', $email . '|' . $code);
}

function user_json(array $u): array
{
    return [
        'id' => (int) $u['id'],
        'email' => $u['email'],
        'displayName' => $u['display_name'],
        'city' => $u['city'],
        'google' => $u['google_sub'] !== null,
        'createdAt' => sql_to_iso($u['created_at']),
    ];
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
    $u = db()->prepare('SELECT * FROM users WHERE id = ?');
    $u->execute([$userId]);
    return ['token' => $token, 'user' => user_json($u->fetch())];
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
    $q = db()->prepare('SELECT id FROM users WHERE email = ?');
    $q->execute([$email]);
    $id = $q->fetchColumn();
    if ($id) {
        return (int) $id;
    }
    db()->prepare('INSERT INTO users (email, created_at) VALUES (?, ?)')->execute([$email, now_sql()]);
    return (int) db()->lastInsertId();
}

// POST /v1/auth/email/start {email}
function auth_email_start(): void
{
    $email = normalize_email(body()['email'] ?? null);
    if ($email === null) {
        fail(422, 'invalid_email');
    }
    $hourAgo = now_sql('-1 hour');
    $byEmail = db()->prepare('SELECT COUNT(*) FROM login_codes WHERE email = ? AND created_at > ?');
    $byEmail->execute([$email, $hourAgo]);
    $byIp = db()->prepare('SELECT COUNT(*) FROM login_codes WHERE ip = ? AND created_at > ?');
    $byIp->execute([client_ip(), $hourAgo]);
    if ((int) $byEmail->fetchColumn() >= 5 || (int) $byIp->fetchColumn() >= 20) {
        fail(429, 'too_many_requests');
    }

    $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    db()->prepare('INSERT INTO login_codes (email, code_hash, ip, created_at, expires_at) VALUES (?, ?, ?, ?, ?)')
        ->execute([$email, code_hash($email, $code), client_ip(), now_sql(), now_sql('+' . CODE_MINUTES . ' minutes')]);

    if (!send_login_email($email, $code)) {
        // etapa e código SMTP ajudam a diagnosticar (ex.: "auth 535" = senha da caixa recusada); sem dados sensíveis
        fail(502, 'email_failed', ['stage' => $GLOBALS['smtp_error'] ?? 'mail']);
    }
    // mesma resposta para conta nova ou existente
    json_out(200, ['sent' => true, 'expiresInMinutes' => CODE_MINUTES, 'delivery' => $GLOBALS['mail_delivery'] ?? 'mail']);
}

function send_login_email(string $email, string $code): bool
{
    $from = cfg('MAIL_FROM', 'no-reply@waxclub.com.br');
    $subject = "Your WaxClub code: $code";
    $text = "Your WaxClub sign-in code is:\r\n\r\n    $code\r\n\r\n"
        . 'It expires in ' . CODE_MINUTES . " minutes. If you didn't ask for it, you can ignore this email.\r\n\r\n"
        . "WaxClub - Vinyl Social Club\r\nhttps://waxclub.com.br\r\n";
    $headers = [
        'Date: ' . date(DATE_RFC2822),
        'Message-ID: <' . bin2hex(random_bytes(16)) . '@waxclub.com.br>',
        'From: WaxClub <' . $from . '>',
        'Reply-To: ' . $from,
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: 8bit',
    ];
    // Pela caixa no-reply (SMTP autenticado): sai assinado com o DKIM do domínio e não cai no spam
    if (cfg('SMTP_PASS') !== '' && smtp_send($from, $email, $subject, $text, $headers)) {
        $GLOBALS['mail_delivery'] = 'smtp';
        return true;
    }
    // sem SMTP (ou SMTP recusado): envio local do servidor, que pode cair no spam
    $GLOBALS['mail_delivery'] = isset($GLOBALS['smtp_error']) ? 'fallback (' . $GLOBALS['smtp_error'] . ')' : 'mail';    return mail($email, $subject, $text, implode("\r\n", $headers), '-f' . $from);
}

/** Cliente SMTP mínimo (SSL implícito na porta 465, AUTH LOGIN). */
function smtp_send(string $from, string $to, string $subject, string $text, array $headers): bool
{
    $host = cfg('SMTP_HOST', 'smtp.hostinger.com');
    $port = (int) cfg('SMTP_PORT', '465');
    $user = cfg('SMTP_USER', $from);
    $sock = @stream_socket_client("ssl://$host:$port", $errno, $errstr, 15);
    if (!$sock) {
        error_log("[waxclub-api] smtp connect: $errstr");
        $GLOBALS['smtp_error'] = "connect $errno";
        return false;
    }
    stream_set_timeout($sock, 15);
    $read = function () use ($sock): string {
        $resp = '';
        while (($line = fgets($sock, 1024)) !== false) {
            $resp .= $line;
            if (strlen($line) < 4 || $line[3] === ' ') {
                break;
            }
        }
        return $resp;
    };
    $cmd = function (string $line, string $expect, string $stage) use ($sock, $read): bool {
        if ($line !== '') {
            fwrite($sock, $line . "\r\n");
        }
        $resp = $read();
        if (strncmp($resp, $expect, 3) !== 0) {
            error_log('[waxclub-api] smtp: ' . trim($resp));
            $GLOBALS['smtp_error'] = $stage . ' ' . (substr($resp, 0, 3) ?: 'timeout');
            return false;
        }
        return true;
    };
    $body = preg_replace('/^\./m', '..', str_replace(["\r\n", "\n"], ["\n", "\r\n"], $text));
    $subjectHeader = 'Subject: =?UTF-8?B?' . base64_encode($subject) . '?=';
    $data = implode("\r\n", array_merge($headers, ['To: <' . $to . '>', $subjectHeader])) . "\r\n\r\n" . $body . "\r\n.";
    $ok = $cmd('', '220', 'greeting')
        && $cmd('EHLO api.waxclub.com.br', '250', 'ehlo')
        && $cmd('AUTH LOGIN', '334', 'auth')
        && $cmd(base64_encode($user), '334', 'auth-user')
        && $cmd(base64_encode(cfg('SMTP_PASS')), '235', 'auth-pass')
        && $cmd('MAIL FROM:<' . $from . '>', '250', 'mail-from')
        && $cmd('RCPT TO:<' . $to . '>', '250', 'rcpt-to')
        && $cmd('DATA', '354', 'data')
        && $cmd($data, '250', 'send');
    fwrite($sock, "QUIT\r\n");
    fclose($sock);
    return $ok;
}

// POST /v1/auth/email/verify {email, code, device?}
function auth_email_verify(): void
{
    $email = normalize_email(body()['email'] ?? null);
    $code = preg_replace('/\D/', '', (string) (body()['code'] ?? ''));
    if ($email === null || strlen($code) !== 6) {
        fail(422, 'invalid_code');
    }
    $q = db()->prepare('SELECT * FROM login_codes WHERE email = ? AND used_at IS NULL AND expires_at > ?
                        ORDER BY id DESC LIMIT 1');
    $q->execute([$email, now_sql()]);
    $row = $q->fetch();
    if (!$row || (int) $row['attempts'] >= CODE_MAX_ATTEMPTS) {
        fail(401, 'code_expired');
    }
    if (!hash_equals($row['code_hash'], code_hash($email, $code))) {
        db()->prepare('UPDATE login_codes SET attempts = attempts + 1 WHERE id = ?')->execute([$row['id']]);
        fail(401, 'invalid_code', ['attemptsLeft' => max(0, CODE_MAX_ATTEMPTS - 1 - (int) $row['attempts'])]);
    }
    db()->prepare('UPDATE login_codes SET used_at = ? WHERE id = ?')->execute([now_sql(), $row['id']]);
    json_out(200, open_session(find_or_create_user($email)));
}

// POST /v1/auth/google {idToken, device?}
function auth_google(): void
{
    $clientIds = array_filter(array_map('trim', explode(',', cfg('GOOGLE_CLIENT_IDS'))));
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
    json_out(200, open_session((int) $id));
}

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

// PATCH /v1/me {displayName?, city?}
function me_patch(): void
{
    $user = require_user();
    $b = body();
    $fields = ['displayName' => 'display_name', 'city' => 'city'];
    foreach ($fields as $json => $col) {
        if (array_key_exists($json, $b)) {
            db()->prepare("UPDATE users SET $col = ? WHERE id = ?")->execute([str_field($b, $json, 100), $user['id']]);
        }
    }
    $q = db()->prepare('SELECT * FROM users WHERE id = ?');
    $q->execute([$user['id']]);
    json_out(200, ['user' => user_json($q->fetch())]);
}

// DELETE /v1/me — apaga a conta, as sessões, a coleção e as audições
function me_delete(): void
{
    $user = require_user();
    db()->prepare('DELETE FROM login_codes WHERE email = ?')->execute([$user['email']]);
    db()->prepare('DELETE FROM users WHERE id = ?')->execute([$user['id']]);
    json_out(200, ['deleted' => true]);
}
