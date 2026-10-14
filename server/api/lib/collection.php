<?php
// Coleção (espelho do CollectionItem do app) e audições, com sincronização incremental (?since=).
declare(strict_types=1);

const BATCH_MAX = 500;

/** Campos do app (camelCase) -> colunas, com o tamanho máximo de cada uma. */
function item_fields(): array
{
    return [
        'coverUrl' => ['cover_url', 500],
        'year' => ['year', 10],
        'format' => ['format', 100],
        'discogsReleaseId' => ['discogs_release_id', 20],
        'musicBrainzReleaseId' => ['musicbrainz_release_id', 40],
        'label' => ['label', 255],
        'catalogNumber' => ['catalog_number', 100],
        'barcode' => ['barcode', 64],
        'mediaCondition' => ['media_condition', 60],
        'sleeveCondition' => ['sleeve_condition', 60],
        'notes' => ['notes', 5000],
    ];
}

function item_json(array $r): array
{
    $out = [
        'key' => $r['item_key'],
        'album' => $r['album'],
        'artist' => $r['artist'],
        'addedAt' => sql_to_iso($r['added_at']),
        'updatedAt' => sql_to_iso($r['updated_at']),
        'deleted' => (bool) $r['deleted'],
    ];
    foreach (item_fields() as $json => [$col]) {
        if ($r[$col] !== null) {
            $out[$json] = $r[$col];
        }
    }
    if ($r['rating'] !== null) {
        $out['rating'] = (int) $r['rating'];
    }
    return $out;
}

function since_param(): ?string
{
    $since = $_GET['since'] ?? null;
    if ($since === null || $since === '') {
        return null;
    }
    $sql = iso_to_sql((string) $since);
    if ($sql === null) {
        fail(422, 'invalid_since');
    }
    return $sql;
}

// GET /v1/collection?since=ISO — sem since, só os itens ativos; com since, também os apagados
function collection_list(): void
{
    $user = require_user();
    $serverTime = now_sql();
    $since = since_param();
    if ($since === null) {
        $q = db()->prepare('SELECT * FROM collection_items WHERE user_id = ? AND deleted = 0 ORDER BY added_at');
        $q->execute([$user['id']]);
    } else {
        $q = db()->prepare('SELECT * FROM collection_items WHERE user_id = ? AND synced_at > ? ORDER BY synced_at');
        $q->execute([$user['id'], $since]);
    }
    json_out(200, ['items' => array_map('item_json', $q->fetchAll()), 'serverTime' => sql_to_iso($serverTime)]);
}

/**
 * Grava um item (último a mudar vence: se o servidor tem uma versão mais nova, ela fica).
 * Devolve o item como ficou no servidor.
 */
function upsert_item(int $userId, string $key, array $src, bool $deleted = false): array
{
    $album = str_field($src, 'album', 255);
    $artist = str_field($src, 'artist', 255);
    if (!$deleted && ($album === null || $artist === null)) {
        fail(422, 'album_and_artist_required', ['key' => $key]);
    }
    $clientUpdated = iso_to_sql($src['updatedAt'] ?? null) ?? now_sql();
    if ($clientUpdated > now_sql('+5 minutes')) {
        $clientUpdated = now_sql(); // relógio do celular adiantado
    }

    $q = db()->prepare('SELECT * FROM collection_items WHERE user_id = ? AND item_key = ?');
    $q->execute([$userId, $key]);
    $existing = $q->fetch();
    if ($existing && $existing['updated_at'] >= $clientUpdated) {
        return item_json($existing);
    }
    if (!$existing && $deleted) {
        return ['key' => $key, 'deleted' => true];
    }

    if ($deleted) {
        db()->prepare('UPDATE collection_items SET deleted = 1, updated_at = ?, synced_at = ? WHERE id = ?')
            ->execute([$clientUpdated, now_sql(), $existing['id']]);
    } else {
        $cols = ['album' => $album, 'artist' => $artist];
        foreach (item_fields() as $json => [$col, $max]) {
            $cols[$col] = str_field($src, $json, $max);
        }
        $rating = isset($src['rating']) && is_numeric($src['rating']) ? (int) $src['rating'] : null;
        $cols['rating'] = $rating !== null && $rating >= 1 && $rating <= 5 ? $rating : null;
        $cols['updated_at'] = $clientUpdated;
        $cols['synced_at'] = now_sql();
        $cols['deleted'] = 0;
        if ($existing) {
            $set = implode(', ', array_map(fn($c) => "$c = ?", array_keys($cols)));
            db()->prepare("UPDATE collection_items SET $set WHERE id = ?")
                ->execute([...array_values($cols), $existing['id']]);
        } else {
            $cols['user_id'] = $userId;
            $cols['item_key'] = $key;
            $cols['added_at'] = iso_to_sql($src['addedAt'] ?? null) ?? now_sql();
            $names = implode(', ', array_keys($cols));
            $marks = implode(', ', array_fill(0, count($cols), '?'));
            db()->prepare("INSERT INTO collection_items ($names) VALUES ($marks)")->execute(array_values($cols));
        }
    }
    $q->execute([$userId, $key]);
    return item_json($q->fetch());
}

function valid_key($key): string
{
    $key = is_string($key) ? trim($key) : '';
    if ($key === '' || mb_strlen($key) > 255) {
        fail(422, 'invalid_key');
    }
    return $key;
}

// PUT /v1/collection/{key}
function collection_put(string $key): void
{
    $user = require_user();
    json_out(200, ['item' => upsert_item((int) $user['id'], valid_key($key), body())]);
}

// DELETE /v1/collection/{key}
function collection_delete(string $key): void
{
    $user = require_user();
    json_out(200, ['item' => upsert_item((int) $user['id'], valid_key($key), ['updatedAt' => $_GET['updatedAt'] ?? null], true)]);
}

// POST /v1/collection/sync {items:[{key, ..., deleted?}]} — envio em lote (ex.: primeira sincronização)
function collection_sync(): void
{
    $user = require_user();
    $items = body()['items'] ?? null;
    if (!is_array($items) || count($items) > BATCH_MAX) {
        fail(422, 'invalid_items', ['max' => BATCH_MAX]);
    }
    $out = [];
    db()->beginTransaction();
    foreach ($items as $it) {
        if (!is_array($it)) {
            continue;
        }
        $out[] = upsert_item((int) $user['id'], valid_key($it['key'] ?? null), $it, !empty($it['deleted']));
    }
    db()->commit();
    json_out(200, ['items' => $out, 'serverTime' => sql_to_iso(now_sql())]);
}

// POST /v1/plays {plays:[{album, artist, track, trackArtist?, at}]} — repetidos são ignorados
function plays_add(): void
{
    $user = require_user();
    $plays = body()['plays'] ?? null;
    if (!is_array($plays) || count($plays) > BATCH_MAX) {
        fail(422, 'invalid_plays', ['max' => BATCH_MAX]);
    }
    $ins = db()->prepare('INSERT IGNORE INTO plays (user_id, album, artist, track, track_artist, played_at, received_at, dedup)
                          VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
    $added = 0;
    $now = now_sql();
    db()->beginTransaction();
    foreach ($plays as $p) {
        if (!is_array($p)) {
            continue;
        }
        $album = str_field($p, 'album', 255);
        $artist = str_field($p, 'artist', 255);
        $track = str_field($p, 'track', 255);
        $at = iso_to_sql($p['at'] ?? null);
        if ($album === null || $artist === null || $track === null || $at === null) {
            continue;
        }
        $dedup = sha1(mb_strtolower("$album|$artist|$track|$at"));
        $ins->execute([$user['id'], $album, $artist, $track, str_field($p, 'trackArtist', 255), $at, $now, $dedup]);
        $added += $ins->rowCount();
    }
    db()->commit();
    json_out(200, ['added' => $added]);
}

// GET /v1/plays?since=ISO (até 5000 por vez, pela ordem de chegada no servidor)
function plays_list(): void
{
    $user = require_user();
    $since = since_param() ?? '1970-01-01 00:00:00.000';
    $q = db()->prepare('SELECT * FROM plays WHERE user_id = ? AND received_at > ? ORDER BY received_at, id LIMIT 5000');
    $q->execute([$user['id'], $since]);
    $rows = $q->fetchAll();
    $plays = array_map(fn($r) => array_filter([
        'album' => $r['album'],
        'artist' => $r['artist'],
        'track' => $r['track'],
        'trackArtist' => $r['track_artist'],
        'at' => sql_to_iso($r['played_at']),
    ], fn($v) => $v !== null), $rows);
    $last = $rows ? sql_to_iso(end($rows)['received_at']) : null;
    json_out(200, ['plays' => $plays, 'next' => count($rows) === 5000 ? $last : null, 'serverTime' => sql_to_iso(now_sql())]);
}
