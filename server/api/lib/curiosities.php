<?php
// Curiosidades dos discos (compartilhadas entre usuários): o app procura aqui antes da web e grava o que
// achar. Uma linha por curiosidade, ligadas ao disco (artista|disco normalizado) e ao idioma.
declare(strict_types=1);

const CURIOSITY_KINDS = ['album', 'track'];
const CURIOSITY_MAX_ITEMS = 10;

function curiosity_key($v): ?string
{
    $v = is_string($v) ? trim($v) : '';
    return $v !== '' && mb_strlen($v) <= 255 ? $v : null;
}

function curiosity_lang($v): ?string
{
    $v = strtolower(trim((string) $v));
    return preg_match('/^[a-z]{2}$/', $v) ? $v : null;
}

// GET /v1/curiosities?record=<chave>&lang=<xx>[&track=<chave>]
function curiosities_get(): void
{
    require_user();
    $record = curiosity_key($_GET['record'] ?? null);
    $lang = curiosity_lang($_GET['lang'] ?? '');
    if ($record === null || $lang === null) {
        fail(422, 'invalid_request');
    }
    $track = curiosity_key($_GET['track'] ?? null) ?? '';
    $kind = $track === '' ? 'album' : 'track';
    $q = db()->prepare('SELECT text, source, url FROM record_curiosities
                        WHERE record_key = ? AND kind = ? AND track_key = ? AND lang = ? ORDER BY position, id');
    $q->execute([$record, $kind, $track, $lang]);
    $rows = $q->fetchAll();
    json_out(200, [
        'found' => (bool) $rows,
        'items' => array_map(fn($r) => array_filter([
            'text' => $r['text'],
            'source' => $r['source'],
            'url' => $r['url'],
        ], fn($v) => $v !== null), $rows),
    ]);
}

// POST /v1/curiosities {record, lang, track?, discogsReleaseId?, items:[{text, source, url?}]}
// Substitui as curiosidades daquele disco (ou faixa) naquele idioma.
function curiosities_put(): void
{
    $user = require_user();
    $b = body();
    $record = curiosity_key($b['record'] ?? null);
    $lang = curiosity_lang($b['lang'] ?? '');
    $items = $b['items'] ?? null;
    if ($record === null || $lang === null || !is_array($items) || count($items) > CURIOSITY_MAX_ITEMS) {
        fail(422, 'invalid_request');
    }
    $track = curiosity_key($b['track'] ?? null) ?? '';
    $kind = $track === '' ? 'album' : 'track';
    $release = str_field($b, 'discogsReleaseId', 20);
    $rows = [];
    foreach ($items as $it) {
        if (!is_array($it)) {
            continue;
        }
        $text = str_field($it, 'text', 600);
        $source = str_field($it, 'source', 60);
        $url = str_field($it, 'url', 500);
        if ($text === null || $source === null) {
            continue;
        }
        if ($url !== null && !preg_match('#^https?://#i', $url)) {
            $url = null;
        }
        $rows[] = [$text, $source, $url];
    }
    $pdo = db();
    $pdo->beginTransaction();
    $pdo->prepare('DELETE FROM record_curiosities WHERE record_key = ? AND kind = ? AND track_key = ? AND lang = ?')
        ->execute([$record, $kind, $track, $lang]);
    $ins = $pdo->prepare('INSERT INTO record_curiosities
        (record_key, track_key, kind, lang, position, text, source, url, discogs_release_id, created_by, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    foreach ($rows as $i => [$text, $source, $url]) {
        $ins->execute([$record, $track, $kind, $lang, $i, $text, $source, $url, $release, $user['id'], now_sql()]);
    }
    $pdo->commit();
    json_out(200, ['saved' => count($rows)]);
}
