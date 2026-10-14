<?php
// Países, estados/províncias e cidades (base GeoNames, CC BY 4.0) para o cadastro e os shows por cidade.
declare(strict_types=1);

const GEO_VERSION = '1';

/**
 * Importa a base de api/data/ na primeira consulta depois de publicada (ou de mudar GEO_VERSION).
 * Arquivos: countries.tsv (code, name), states.tsv (country, code, name), cities.tsv.gz
 * (id, country, state, name, search_name, population) — gerados por tool/geo/build_geo.js.
 */
function ensure_geo(): void
{
    if (meta_get('geo') === GEO_VERSION) {
        return;
    }
    $dir = dirname(__DIR__) . '/data';
    if (!is_readable("$dir/countries.tsv") || !is_readable("$dir/states.tsv") || !is_readable("$dir/cities.tsv.gz")) {
        fail(503, 'geo_not_ready');
    }
    $pdo = db();
    if (!(int) $pdo->query("SELECT GET_LOCK('waxclub_geo', 0)")->fetchColumn()) {
        fail(503, 'geo_importing', ['retryAfter' => 30]);
    }
    try {
        if (meta_get('geo') === GEO_VERSION) {
            return;
        }
        set_time_limit(900);
        ignore_user_abort(true);
        $pdo->exec('DELETE FROM geo_cities');
        $pdo->exec('DELETE FROM geo_states');
        $pdo->exec('DELETE FROM geo_countries');

        $states = [];
        $insState = $pdo->prepare('INSERT INTO geo_states (country_code, code, name) VALUES (?, ?, ?)');
        foreach (file("$dir/states.tsv", FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
            [$cc, $code, $name] = array_pad(explode("\t", $line), 3, '');
            $insState->execute([$cc, $code, $name]);
            $states[$cc] = true;
        }
        $insCountry = $pdo->prepare('INSERT INTO geo_countries (code, name, has_states) VALUES (?, ?, ?)');
        foreach (file("$dir/countries.tsv", FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
            [$cc, $name] = array_pad(explode("\t", $line), 2, '');
            $insCountry->execute([$cc, $name, isset($states[$cc]) ? 1 : 0]);
        }

        // cidades em lotes de 1000 linhas
        $gz = gzopen("$dir/cities.tsv.gz", 'rb');
        $batch = [];
        $flush = function () use (&$batch, $pdo): void {
            if (!$batch) {
                return;
            }
            $marks = implode(',', array_fill(0, count($batch), '(?, ?, ?, ?, ?, ?)'));
            $pdo->prepare("INSERT IGNORE INTO geo_cities (id, country_code, state_code, name, search_name, population) VALUES $marks")
                ->execute(array_merge(...$batch));
            $batch = [];
        };
        while (($line = gzgets($gz)) !== false) {
            $f = explode("\t", rtrim($line, "\r\n"));
            if (count($f) < 6) {
                continue;
            }
            $batch[] = [(int) $f[0], $f[1], $f[2], $f[3], $f[4], (int) $f[5]];
            if (count($batch) >= 1000) {
                $flush();
            }
        }
        $flush();
        gzclose($gz);
        meta_set('geo', GEO_VERSION);
    } finally {
        $pdo->query("SELECT RELEASE_LOCK('waxclub_geo')");
    }
}

/** Texto de busca: minúsculo e sem acentos (igual ao search_name da base). */
function geo_search_text(string $q): string
{
    $q = mb_strtolower(trim($q));
    $ascii = function_exists('transliterator_transliterate')
        ? transliterator_transliterate('Any-Latin; Latin-ASCII', $q)
        : iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $q);
    return preg_replace('/[^a-z0-9 \'\-]/', '', strtolower((string) $ascii));
}

function geo_country(string $cc): ?array
{
    ensure_geo();
    $q = db()->prepare('SELECT * FROM geo_countries WHERE code = ?');
    $q->execute([strtoupper($cc)]);
    return $q->fetch() ?: null;
}

function geo_state(string $cc, string $code): ?array
{
    $q = db()->prepare('SELECT * FROM geo_states WHERE country_code = ? AND code = ?');
    $q->execute([strtoupper($cc), $code]);
    return $q->fetch() ?: null;
}

function geo_city(int $id): ?array
{
    $q = db()->prepare('SELECT * FROM geo_cities WHERE id = ?');
    $q->execute([$id]);
    return $q->fetch() ?: null;
}

/**
 * Confere país, estado e cidade escolhidos no cadastro; devolve as colunas do usuário.
 * O estado é obrigatório quando o país tem estados/províncias na base.
 */
function validate_location(array $src): array
{
    $cc = strtoupper((string) ($src['countryCode'] ?? ''));
    $country = preg_match('/^[A-Z]{2}$/', $cc) ? geo_country($cc) : null;
    if (!$country) {
        fail(422, 'invalid_country');
    }
    $stateCode = trim((string) ($src['stateCode'] ?? ''));
    $state = null;
    if ((int) $country['has_states'] === 1) {
        $state = $stateCode !== '' ? geo_state($cc, $stateCode) : null;
        if (!$state) {
            fail(422, 'invalid_state');
        }
    }
    $city = geo_city((int) ($src['cityId'] ?? 0));
    if (!$city || $city['country_code'] !== $cc || ($state && $city['state_code'] !== $state['code'])) {
        fail(422, 'invalid_city');
    }
    return [
        'country_code' => $cc,
        'state_code' => $state['code'] ?? null,
        'state_name' => $state['name'] ?? null,
        'city_id' => (int) $city['id'],
        'city' => mb_substr($city['name'], 0, 100),
    ];
}

// GET /v1/geo/countries
function geo_countries(): void
{
    ensure_geo();
    $rows = db()->query('SELECT code, name, has_states FROM geo_countries ORDER BY name')->fetchAll();
    json_out(200, ['countries' => array_map(fn($r) => [
        'code' => $r['code'],
        'name' => $r['name'],
        'hasStates' => (bool) $r['has_states'],
    ], $rows)]);
}

// GET /v1/geo/states?country=BR
function geo_states(): void
{
    ensure_geo();
    $q = db()->prepare('SELECT code, name FROM geo_states WHERE country_code = ? ORDER BY name');
    $q->execute([strtoupper((string) ($_GET['country'] ?? ''))]);
    json_out(200, ['states' => $q->fetchAll()]);
}

// GET /v1/geo/cities?country=BR&state=27&q=sao (as mais populosas primeiro; até 50)
function geo_cities(): void
{
    ensure_geo();
    $cc = strtoupper((string) ($_GET['country'] ?? ''));
    $state = (string) ($_GET['state'] ?? '');
    $text = geo_search_text((string) ($_GET['q'] ?? ''));
    $limit = max(1, min(50, (int) ($_GET['limit'] ?? 30)));
    $sql = 'SELECT id, name, state_code FROM geo_cities WHERE country_code = ?';
    $args = [$cc];
    if ($state !== '') {
        $sql .= ' AND state_code = ?';
        $args[] = $state;
    }
    if ($text !== '') {
        $sql .= ' AND search_name LIKE ?';
        $args[] = str_replace(['%', '_'], ['\%', '\_'], $text) . '%';
    }
    $sql .= " ORDER BY population DESC, name LIMIT $limit";
    $q = db()->prepare($sql);
    $q->execute($args);
    json_out(200, ['cities' => array_map(fn($r) => [
        'id' => (int) $r['id'],
        'name' => $r['name'],
        'stateCode' => $r['state_code'],
    ], $q->fetchAll())]);
}
