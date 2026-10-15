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
