<?php
// Plugin A3 "Imagined Music": busca de fotos no Unsplash (API oficial) para as cenas que o agente monta a
// partir da letra. A chave do Unsplash fica só aqui (UNSPLASH_ACCESS_KEY no waxclub.env): o app pede ao
// nosso servidor, que pergunta ao Unsplash. As imagens são exibidas pelos endereços do próprio Unsplash
// (hotlinking, como as regras da API exigem), com crédito ao fotógrafo; nada é copiado para cá.
// As respostas da busca ficam guardadas por alguns dias para economizar o limite de pedidos.
declare(strict_types=1);

const IMAGINE_CACHE_DAYS = 7;
const IMAGINE_UTM = 'utm_source=waxclub&utm_medium=referral';

function imagine_key(): string
{
    $k = trim(cfg('UNSPLASH_ACCESS_KEY'));
    if ($k === '') {
        fail(503, 'imagine_not_configured');
    }
    return $k;
}

/** Link com a marcação de origem que o Unsplash pede nos créditos. */
function imagine_utm(?string $url): ?string
{
    if (!is_string($url) || $url === '') {
        return null;
    }
    return $url . (strpos($url, '?') === false ? '?' : '&') . IMAGINE_UTM;
}

function imagine_unsplash(string $url, string $key): array
{
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 12,
        CURLOPT_HTTPHEADER => ['Authorization: Client-ID ' . $key, 'Accept-Version: v1'],
    ]);
    $resp = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return [$status, is_string($resp) ? json_decode($resp, true) : null];
}

// GET /v1/imagine/search?q=<busca em inglês>
function imagine_search(): void
{
    require_user();
    $q = strtolower(trim(preg_replace('/\s+/', ' ', (string) ($_GET['q'] ?? ''))));
    if ($q === '' || mb_strlen($q) > 160) {
        fail(422, 'invalid_query');
    }
    $hash = sha1($q);
    $cached = db()->prepare('SELECT json FROM imagine_cache WHERE qhash = ? AND created_at > ?');
    $cached->execute([$hash, now_sql('-' . IMAGINE_CACHE_DAYS . ' days')]);
    $hit = $cached->fetchColumn();
    if ($hit !== false) {
        json_out(200, ['photos' => json_decode((string) $hit, true) ?: [], 'cached' => true]);
        return;
    }

    $key = imagine_key();
    [$status, $data] = imagine_unsplash('https://api.unsplash.com/search/photos?' . http_build_query([
        'query' => $q,
        'per_page' => 12,
        'orientation' => 'landscape',
        'content_filter' => 'high',
    ]), $key);
    if ($status === 403 || $status === 429) {
        fail(429, 'imagine_rate_limited');
    }
    if ($status !== 200 || !is_array($data)) {
        fail(502, 'imagine_unavailable');
    }
    $photos = [];
    foreach (($data['results'] ?? []) as $r) {
        if (!is_array($r) || empty($r['id']) || empty($r['urls']['raw'])) {
            continue;
        }
        $photos[] = [
            'id' => (string) $r['id'],
            'url' => (string) $r['urls']['raw'],
            'color' => $r['color'] ?? null,
            'alt' => $r['alt_description'] ?? ($r['description'] ?? null),
            'author' => $r['user']['name'] ?? 'Unsplash',
            'authorUrl' => imagine_utm($r['user']['links']['html'] ?? null),
            'photoUrl' => imagine_utm($r['links']['html'] ?? null),
            'download' => $r['links']['download_location'] ?? null,
        ];
    }
    db()->prepare('REPLACE INTO imagine_cache (qhash, query, json, created_at) VALUES (?, ?, ?, ?)')
        ->execute([$hash, mb_substr($q, 0, 160), json_encode($photos, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), now_sql()]);
    json_out(200, ['photos' => $photos, 'cached' => false]);
}

// POST /v1/imagine/used — corpo: {download: <links.download_location da foto>}. Avisa o Unsplash que a foto
// foi usada (exigência da API quando uma foto é escolhida para uso).
function imagine_used(): void
{
    require_user();
    $download = (string) (body()['download'] ?? '');
    $parts = parse_url($download);
    if (($parts['scheme'] ?? '') !== 'https' || ($parts['host'] ?? '') !== 'api.unsplash.com'
        || !preg_match('#^/photos/[A-Za-z0-9_-]+/download$#', $parts['path'] ?? '')) {
        fail(422, 'invalid_download');
    }
    [$status] = imagine_unsplash($download, imagine_key());
    json_out(200, ['ok' => $status === 200]);
}

const IMAGINE_ART_BASE = 'https://waxclub.com.br/imagined/art/';

// GET /v1/imagine/art?q=<busca em inglês> — obras do acervo CC0 (no nosso servidor; sem limite do Unsplash)
function imagine_art(): void
{
    require_user();
    $q = trim(preg_replace('/\s+/', ' ', (string) ($_GET['q'] ?? '')));
    if ($q === '' || mb_strlen($q) > 160) {
        fail(422, 'invalid_query');
    }
    // Busca por relevância nas palavras (título, artista, assuntos); um pouco de sorte entre as melhores
    $sql = db()->prepare('SELECT id, museum, title, artist, date_text, file, width, height, color,
                                 MATCH(title, artist, tags, kind) AGAINST (? IN NATURAL LANGUAGE MODE) AS score
                          FROM imagine_art
                          WHERE MATCH(title, artist, tags, kind) AGAINST (? IN NATURAL LANGUAGE MODE)
                          ORDER BY score DESC LIMIT 24');
    $sql->execute([$q, $q]);
    $rows = $sql->fetchAll();
    // Variedade: embaralha as obras quase tão relevantes quanto a melhor (≥ 80% da nota), mantendo o resto atrás
    $best = $rows ? (float) $rows[0]['score'] : 0.0;
    $top = array_values(array_filter($rows, fn($r) => (float) $r['score'] >= $best * 0.8));
    $rest = array_values(array_filter($rows, fn($r) => (float) $r['score'] < $best * 0.8));
    shuffle($top);
    $rows = array_merge($top, $rest);
    $art = array_map(fn(array $r): array => [
        'id' => $r['id'],
        'url' => IMAGINE_ART_BASE . rawurlencode($r['file']),
        'title' => $r['title'],
        'artist' => $r['artist'],
        'date' => $r['date_text'],
        'museum' => $r['museum'],
        'color' => $r['color'],
    ], array_slice($rows, 0, 12));
    json_out(200, ['art' => $art]);
}

const IMAGINE_EMOTIONS = ['love', 'desire', 'longing', 'loneliness', 'sadness', 'anger', 'fear', 'hope', 'joy',
                          'euphoria', 'freedom', 'nostalgia', 'peace', 'melancholy', 'faith', 'rebellion'];

// GET /v1/imagine/emotion?e=<sentimento> — as obras escolhidas para aquele sentimento (umas 20), embaralhadas
function imagine_emotion(): void
{
    require_user();
    $e = (string) ($_GET['e'] ?? '');
    if (!in_array($e, IMAGINE_EMOTIONS, true)) {
        fail(422, 'invalid_emotion');
    }
    $sql = db()->prepare('SELECT id, museum, title, artist, date_text, file, color FROM imagine_art
                          WHERE emotion = ? ORDER BY RAND() LIMIT 40');
    $sql->execute([$e]);
    $art = array_map(fn(array $r): array => [
        'id' => $r['id'],
        'url' => IMAGINE_ART_BASE . rawurlencode($r['file']),
        'title' => $r['title'],
        'artist' => $r['artist'],
        'date' => $r['date_text'],
        'museum' => $r['museum'],
        'color' => $r['color'],
        'emotion' => $e,
    ], $sql->fetchAll());
    json_out(200, ['art' => $art]);
}
