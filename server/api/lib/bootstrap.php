<?php
// Configuração, banco (com migrações automáticas) e utilitários HTTP da API do WaxClub.
declare(strict_types=1);

const API_VERSION = '1.0';

ini_set('display_errors', '0');
error_reporting(E_ALL);

set_exception_handler(function (Throwable $e): void {
    error_log('[waxclub-api] ' . $e->getMessage() . ' @ ' . $e->getFile() . ':' . $e->getLine());
    if (!headers_sent()) {
        json_out(500, ['error' => 'internal_error']);
    }
});

// ---------- configuração ----------

/** Lê o waxclub.env, que fica FORA da pasta pública (domains/waxclub.com.br/waxclub.env). */
function env_config(): array
{
    static $cfg = null;
    if ($cfg !== null) {
        return $cfg;
    }
    $path = getenv('WAXCLUB_ENV') ?: dirname(__DIR__, 3) . '/waxclub.env';
    if (!is_readable($path)) {
        fail(503, 'server_not_configured');
    }
    $cfg = [];
    foreach (file($path, FILE_IGNORE_NEW_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#' || strpos($line, '=') === false) {
            continue;
        }
        [$k, $v] = explode('=', $line, 2);
        $v = trim($v);
        $q = $v[0] ?? '';
        if (strlen($v) >= 2 && ($q === '"' || $q === "'") && substr($v, -1) === $q) {
            $v = substr($v, 1, -1);
        }
        $cfg[trim($k)] = $v;
    }
    return $cfg;
}

function cfg(string $key, string $default = ''): string
{
    $c = env_config();
    return isset($c[$key]) && $c[$key] !== '' ? $c[$key] : $default;
}

// ---------- banco ----------

function db(): PDO
{
    static $pdo = null;
    if ($pdo !== null) {
        return $pdo;
    }
    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        cfg('DB_HOST', 'localhost'),
        cfg('DB_PORT', '3306'),
        cfg('DB_NAME')
    );
    try {
        $pdo = new PDO($dsn, cfg('DB_USER'), cfg('DB_PASS'), [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    } catch (PDOException $e) {
        error_log('[waxclub-api] db: ' . $e->getMessage());
        fail(503, 'database_unavailable');
    }
    $pdo->exec("SET time_zone = '+00:00'");
    migrate($pdo);
    return $pdo;
}

/** Cada versão do esquema roda uma única vez; a versão atual fica na tabela meta. */
function migrations(): array
{
    return [
        1 => [
            "CREATE TABLE IF NOT EXISTS users (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                email VARCHAR(254) NOT NULL,
                google_sub VARCHAR(64) NULL,
                display_name VARCHAR(100) NULL,
                city VARCHAR(100) NULL,
                created_at DATETIME(3) NOT NULL,
                last_login_at DATETIME(3) NULL,
                UNIQUE KEY uq_users_email (email),
                UNIQUE KEY uq_users_google (google_sub)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
            "CREATE TABLE IF NOT EXISTS login_codes (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                email VARCHAR(254) NOT NULL,
                code_hash CHAR(64) NOT NULL,
                attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
                ip VARCHAR(45) NULL,
                created_at DATETIME(3) NOT NULL,
                expires_at DATETIME(3) NOT NULL,
                used_at DATETIME(3) NULL,
                KEY ix_codes_email (email, created_at),
                KEY ix_codes_ip (ip, created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
            "CREATE TABLE IF NOT EXISTS sessions (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                user_id BIGINT UNSIGNED NOT NULL,
                token_hash CHAR(64) NOT NULL,
                device VARCHAR(100) NULL,
                created_at DATETIME(3) NOT NULL,
                last_used_at DATETIME(3) NOT NULL,
                expires_at DATETIME(3) NOT NULL,
                UNIQUE KEY uq_sessions_token (token_hash),
                KEY ix_sessions_user (user_id),
                CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
            "CREATE TABLE IF NOT EXISTS collection_items (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                user_id BIGINT UNSIGNED NOT NULL,
                item_key VARCHAR(255) NOT NULL,
                album VARCHAR(255) NOT NULL,
                artist VARCHAR(255) NOT NULL,
                cover_url VARCHAR(500) NULL,
                year VARCHAR(10) NULL,
                format VARCHAR(100) NULL,
                discogs_release_id VARCHAR(20) NULL,
                musicbrainz_release_id VARCHAR(40) NULL,
                label VARCHAR(255) NULL,
                catalog_number VARCHAR(100) NULL,
                barcode VARCHAR(64) NULL,
                rating TINYINT UNSIGNED NULL,
                media_condition VARCHAR(60) NULL,
                sleeve_condition VARCHAR(60) NULL,
                notes TEXT NULL,
                added_at DATETIME(3) NOT NULL,
                updated_at DATETIME(3) NOT NULL,
                deleted TINYINT(1) NOT NULL DEFAULT 0,
                UNIQUE KEY uq_items_user_key (user_id, item_key),
                KEY ix_items_user_updated (user_id, updated_at),
                CONSTRAINT fk_items_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
            "CREATE TABLE IF NOT EXISTS plays (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                user_id BIGINT UNSIGNED NOT NULL,
                album VARCHAR(255) NOT NULL,
                artist VARCHAR(255) NOT NULL,
                track VARCHAR(255) NOT NULL,
                track_artist VARCHAR(255) NULL,
                played_at DATETIME(3) NOT NULL,
                received_at DATETIME(3) NOT NULL,
                dedup CHAR(40) NOT NULL,
                UNIQUE KEY uq_plays_dedup (user_id, dedup),
                KEY ix_plays_user_received (user_id, received_at),
                CONSTRAINT fk_plays_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
        ],
        // ?since= usa a hora do servidor em que o item mudou (o updated_at vem do relógio do celular)
        2 => [
            "ALTER TABLE collection_items ADD COLUMN synced_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)",
            "UPDATE collection_items SET synced_at = updated_at",
            "ALTER TABLE collection_items ADD KEY ix_items_user_synced (user_id, synced_at)",
        ],
        // 1.3.21: login obrigatório com senha, perfil com nome de usuário e local, base de cidades
        3 => [
            "ALTER TABLE users
                ADD COLUMN username VARCHAR(30) NULL AFTER email,
                ADD COLUMN password_hash VARCHAR(255) NULL,
                ADD COLUMN email_verified_at DATETIME(3) NULL,
                ADD COLUMN country_code CHAR(2) NULL,
                ADD COLUMN state_code VARCHAR(20) NULL,
                ADD COLUMN state_name VARCHAR(120) NULL,
                ADD COLUMN city_id INT UNSIGNED NULL",
            "ALTER TABLE users ADD UNIQUE KEY uq_users_username (username)",
            // quem já entrou pelo código do e-mail já confirmou o endereço
            "UPDATE users SET email_verified_at = created_at WHERE email_verified_at IS NULL",
            "ALTER TABLE login_codes ADD COLUMN purpose VARCHAR(16) NOT NULL DEFAULT 'login'",
            "CREATE TABLE IF NOT EXISTS auth_failures (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                email VARCHAR(254) NOT NULL,
                ip VARCHAR(45) NULL,
                created_at DATETIME(3) NOT NULL,
                KEY ix_fail_email (email, created_at),
                KEY ix_fail_ip (ip, created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
            "CREATE TABLE IF NOT EXISTS geo_countries (
                code CHAR(2) PRIMARY KEY,
                name VARCHAR(120) NOT NULL,
                has_states TINYINT(1) NOT NULL DEFAULT 0
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
            "CREATE TABLE IF NOT EXISTS geo_states (
                country_code CHAR(2) NOT NULL,
                code VARCHAR(20) NOT NULL,
                name VARCHAR(120) NOT NULL,
                PRIMARY KEY (country_code, code)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
            "CREATE TABLE IF NOT EXISTS geo_cities (
                id INT UNSIGNED PRIMARY KEY,
                country_code CHAR(2) NOT NULL,
                state_code VARCHAR(20) NOT NULL DEFAULT '',
                name VARCHAR(200) NOT NULL,
                search_name VARCHAR(200) NOT NULL,
                population INT UNSIGNED NOT NULL DEFAULT 0,
                KEY ix_city_state (country_code, state_code, search_name),
                KEY ix_city_country (country_code, search_name)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
        ],
        // 1.4.2: curiosidades dos discos compartilhadas (uma linha por curiosidade, por disco e idioma)
        4 => [
            "CREATE TABLE IF NOT EXISTS record_curiosities (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                record_key VARCHAR(255) NOT NULL,
                track_key VARCHAR(255) NOT NULL DEFAULT '',
                kind VARCHAR(8) NOT NULL,
                lang CHAR(2) NOT NULL,
                position TINYINT UNSIGNED NOT NULL DEFAULT 0,
                text TEXT NOT NULL,
                source VARCHAR(60) NOT NULL,
                url VARCHAR(500) NULL,
                discogs_release_id VARCHAR(20) NULL,
                created_by BIGINT UNSIGNED NULL,
                created_at DATETIME(3) NOT NULL,
                KEY ix_curiosities_record (record_key(150), kind, track_key(100), lang)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
        ],
    ];
}

function migrate(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS meta (
        k VARCHAR(64) PRIMARY KEY,
        v VARCHAR(255) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $current = (int) ($pdo->query("SELECT v FROM meta WHERE k = 'schema'")->fetchColumn() ?: 0);
    foreach (migrations() as $version => $statements) {
        if ($version <= $current) {
            continue;
        }
        foreach ($statements as $sql) {
            $pdo->exec($sql);
        }
        $pdo->prepare("REPLACE INTO meta (k, v) VALUES ('schema', ?)")->execute([(string) $version]);
    }
}

function schema_version(): int
{
    return (int) (meta_get('schema') ?? 0);
}

function meta_get(string $key): ?string
{
    $q = db()->prepare('SELECT v FROM meta WHERE k = ?');
    $q->execute([$key]);
    $v = $q->fetchColumn();
    return $v === false ? null : (string) $v;
}

function meta_set(string $key, string $value): void
{
    db()->prepare('REPLACE INTO meta (k, v) VALUES (?, ?)')->execute([$key, $value]);
}

// ---------- tempo ----------

/** Agora em UTC no formato do MySQL (com milissegundos). */
function now_sql(string $modify = ''): string
{
    $d = new DateTimeImmutable('now', new DateTimeZone('UTC'));
    if ($modify !== '') {
        $d = $d->modify($modify);
    }
    return $d->format('Y-m-d H:i:s.v');
}

/** ISO 8601 do app (qualquer fuso) -> DATETIME UTC; null se inválido. */
function iso_to_sql(?string $iso): ?string
{
    if ($iso === null || $iso === '') {
        return null;
    }
    try {
        $d = new DateTimeImmutable($iso, new DateTimeZone('UTC'));
    } catch (Exception $e) {
        return null;
    }
    return $d->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s.v');
}

function sql_to_iso(?string $sql): ?string
{
    if ($sql === null) {
        return null;
    }
    $d = new DateTimeImmutable($sql, new DateTimeZone('UTC'));
    return $d->format('Y-m-d\TH:i:s.v\Z');
}

// ---------- HTTP ----------

function json_out(int $status, array $data): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
}

/** Responde com erro e encerra. */
function fail(int $status, string $error, array $extra = []): void
{
    json_out($status, ['error' => $error] + $extra);
    exit;
}

/** Corpo JSON da requisição (até 1 MB). */
function body(): array
{
    static $data = null;
    if ($data !== null) {
        return $data;
    }
    $raw = file_get_contents('php://input', false, null, 0, 1048577);
    if ($raw === false || strlen($raw) > 1048576) {
        fail(413, 'body_too_large');
    }
    if (trim($raw) === '') {
        return $data = [];
    }
    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        fail(400, 'invalid_json');
    }
    return $data = $decoded;
}

/** Texto do corpo: aparado, limitado e null quando vazio. */
function str_field(array $src, string $key, int $max): ?string
{
    if (!isset($src[$key]) || !is_scalar($src[$key])) {
        return null;
    }
    $v = trim((string) $src[$key]);
    if ($v === '') {
        return null;
    }
    return mb_substr($v, 0, $max);
}

function client_ip(): string
{
    return substr($_SERVER['REMOTE_ADDR'] ?? '', 0, 45);
}

function bearer_token(): ?string
{
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if ($h === '' && function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strcasecmp($name, 'Authorization') === 0) {
                $h = $value;
            }
        }
    }
    return preg_match('/^Bearer\s+(\S+)$/i', $h, $m) ? $m[1] : null;
}
