<?php
// WaxBrain: chaves de IA do usuário (BYOK), guardadas CRIPTOGRAFADAS e ligadas à conta. A senha de
// criptografia (BRAIN_SECRET) fica só no waxclub.env, fora do banco e fora da pasta pública: quem copiar
// apenas o banco não consegue usar as chaves. Só o dono lê, grava e apaga as dele; nada vai para log.
declare(strict_types=1);

const BRAIN_PROVIDERS = ['gemini', 'groq', 'openrouter', 'mistral', 'openai', 'anthropic', 'xai'];
const BRAIN_STATUSES = ['ok', 'invalid', 'limit', 'offline'];
const BRAIN_KEY_MAX = 300;

/** Senha de 32 bytes vinda do BRAIN_SECRET: 64 hex viram os próprios bytes; qualquer outro texto com 32+
 *  caracteres vira o SHA-256 dele. Nula se o servidor ainda não foi configurado (ou senha curta demais). */
function brain_secret(): ?string
{
    $s = trim(cfg('BRAIN_SECRET'));
    if (preg_match('/^[0-9a-fA-F]{64}$/', $s)) {
        return hex2bin($s);
    }
    return strlen($s) >= 32 ? hash('sha256', $s, true) : null;
}

function brain_secret_or_fail(): string
{
    $s = brain_secret();
    if ($s === null) {
        fail(503, 'brain_not_configured');
    }
    return $s;
}

/** AES-256-GCM: devolve [cifra+etiqueta, nonce]. */
function brain_encrypt(string $plain, string $secret): array
{
    $nonce = random_bytes(12);
    $tag = '';
    $cipher = openssl_encrypt($plain, 'aes-256-gcm', $secret, OPENSSL_RAW_DATA, $nonce, $tag);
    if ($cipher === false) {
        fail(500, 'brain_crypto_failed');
    }
    return [$cipher . $tag, $nonce];
}

function brain_decrypt(string $blob, string $nonce, string $secret): ?string
{
    if (strlen($blob) < 17) {
        return null;
    }
    $plain = openssl_decrypt(substr($blob, 0, -16), 'aes-256-gcm', $secret, OPENSSL_RAW_DATA, $nonce, substr($blob, -16));
    return $plain === false ? null : $plain;
}

function brain_provider(string $p): string
{
    if (!in_array($p, BRAIN_PROVIDERS, true)) {
        fail(404, 'unknown_provider');
    }
    return $p;
}

// GET /v1/brain — chips da conta, sem as chaves (só o final, para exibir)
function brain_list(): void
{
    $user = require_user();
    if (brain_secret() === null) {
        json_out(200, ['configured' => false, 'chips' => []]);
    }
    $q = db()->prepare('SELECT provider, position, key_hint, status, validated_at, updated_at FROM brain_keys
                        WHERE user_id = ? ORDER BY position, provider');
    $q->execute([(int) $user['id']]);
    $chips = array_map(fn(array $r): array => [
        'provider' => $r['provider'],
        'position' => (int) $r['position'],
        'hint' => $r['key_hint'],
        'status' => $r['status'],
        'validatedAt' => sql_to_iso($r['validated_at']),
        'updatedAt' => sql_to_iso($r['updated_at']),
    ], $q->fetchAll());
    json_out(200, ['configured' => true, 'chips' => $chips]);
}

// GET /v1/brain/{provider}/key — a chave, só para o dono (o app guarda no cofre do celular)
function brain_key(string $provider): void
{
    $user = require_user();
    $secret = brain_secret_or_fail();
    $q = db()->prepare('SELECT key_cipher, key_nonce FROM brain_keys WHERE user_id = ? AND provider = ?');
    $q->execute([(int) $user['id'], brain_provider($provider)]);
    $r = $q->fetch();
    if (!$r) {
        fail(404, 'not_found');
    }
    $key = brain_decrypt($r['key_cipher'], $r['key_nonce'], $secret);
    if ($key === null) {
        fail(409, 'brain_key_unreadable'); // senha do servidor trocada: o usuário encaixa de novo
    }
    json_out(200, ['key' => $key]);
}

// PUT /v1/brain/{provider} — corpo: {key, position, status}
function brain_put(string $provider): void
{
    $user = require_user();
    $secret = brain_secret_or_fail();
    $provider = brain_provider($provider);
    $b = body();
    $key = is_string($b['key'] ?? null) ? trim($b['key']) : '';
    if ($key === '' || strlen($key) > BRAIN_KEY_MAX || preg_match('/\s/', $key)) {
        fail(422, 'invalid_key');
    }
    $position = max(0, min(50, (int) ($b['position'] ?? 0)));
    $status = in_array($b['status'] ?? 'ok', BRAIN_STATUSES, true) ? $b['status'] : 'ok';
    [$cipher, $nonce] = brain_encrypt($key, $secret);
    $now = now_sql();
    db()->prepare('INSERT INTO brain_keys (user_id, provider, position, key_cipher, key_nonce, key_hint, status, validated_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                   ON DUPLICATE KEY UPDATE position = VALUES(position), key_cipher = VALUES(key_cipher),
                     key_nonce = VALUES(key_nonce), key_hint = VALUES(key_hint), status = VALUES(status),
                     validated_at = VALUES(validated_at), updated_at = VALUES(updated_at)')
        ->execute([(int) $user['id'], $provider, $position, $cipher, $nonce, substr($key, -4), $status, $now, $now]);
    json_out(200, ['ok' => true]);
}

// DELETE /v1/brain/{provider} — desencaixa (apaga a chave da conta)
function brain_delete(string $provider): void
{
    $user = require_user();
    db()->prepare('DELETE FROM brain_keys WHERE user_id = ? AND provider = ?')
        ->execute([(int) $user['id'], brain_provider($provider)]);
    json_out(200, ['ok' => true]);
}

// PUT /v1/brain/order — corpo: {providers: [...]} na nova ordem de prioridade
function brain_order(): void
{
    $user = require_user();
    $list = body()['providers'] ?? null;
    if (!is_array($list)) {
        fail(422, 'invalid_order');
    }
    $q = db()->prepare('UPDATE brain_keys SET position = ? WHERE user_id = ? AND provider = ?');
    foreach (array_values($list) as $i => $p) {
        if (is_string($p) && in_array($p, BRAIN_PROVIDERS, true)) {
            $q->execute([$i, (int) $user['id'], $p]);
        }
    }
    json_out(200, ['ok' => true]);
}
