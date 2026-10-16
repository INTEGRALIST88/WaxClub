<?php
// Banco coletivo de intervalos entre faixas (sem letras: só números). Cada aparelho mede o tempo de início a
// início de uma faixa até a seguinte do mesmo lado (silêncio do sulco incluído) e envia; o servidor guarda as
// últimas medições de cada faixa e entrega a mediana, para a letra da próxima faixa entrar na hora certa.
declare(strict_types=1);

const TIMING_KEEP = 15;          // últimas medições guardadas por faixa
const TIMING_MAX_PER_POST = 50;

// GET /v1/timings?album=<chave do disco> — {tracks: {chave da faixa: ms}}
function timing_get(): void
{
    require_user();
    $album = (string) ($_GET['album'] ?? '');
    if (!preg_match('/^[0-9a-f]{24}$/', $album)) {
        fail(422, 'invalid_album');
    }
    $q = db()->prepare('SELECT track_key, median_ms FROM track_timing WHERE album_key = ?');
    $q->execute([$album]);
    $tracks = [];
    foreach ($q->fetchAll() as $r) {
        $tracks[$r['track_key']] = (int) $r['median_ms'];
    }
    json_out(200, ['tracks' => (object) $tracks]);
}

// POST /v1/timings — {samples: [{album, track, artist, albumName, title, intervalMs}]}. Uma medição por
// usuário, faixa e dia (repetir o disco no mesmo dia não pesa mais).
function timing_post(): void
{
    $user = require_user();
    $samples = body()['samples'] ?? null;
    if (!is_array($samples) || count($samples) > TIMING_MAX_PER_POST) {
        fail(422, 'invalid_samples', ['max' => TIMING_MAX_PER_POST]);
    }
    $pdo = db();
    $log = $pdo->prepare('INSERT IGNORE INTO track_timing_log (user_id, album_key, track_key, day) VALUES (?, ?, ?, ?)');
    $read = $pdo->prepare('SELECT samples FROM track_timing WHERE album_key = ? AND track_key = ? FOR UPDATE');
    $write = $pdo->prepare('REPLACE INTO track_timing (album_key, track_key, artist, album, title, samples, median_ms, sample_count, updated_at)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)');
    $accepted = 0;
    $today = substr(now_sql(), 0, 10);
    foreach ($samples as $s) {
        if (!is_array($s)) {
            continue;
        }
        $album = (string) ($s['album'] ?? '');
        $track = (string) ($s['track'] ?? '');
        $ms = $s['intervalMs'] ?? null;
        if (!preg_match('/^[0-9a-f]{24}$/', $album) || !preg_match('/^[0-9a-f]{16}$/', $track)
            || !is_int($ms) || $ms < 20000 || $ms > 1800000) {
            continue;
        }
        $pdo->beginTransaction();
        try {
            $log->execute([$user['id'], $album, $track, $today]);
            if ($log->rowCount() === 0) { // já mediu esta faixa hoje
                $pdo->commit();
                continue;
            }
            $read->execute([$album, $track]);
            $prev = $read->fetchColumn();
            $list = $prev === false ? [] : (json_decode((string) $prev, true) ?: []);
            $list[] = $ms;
            $list = array_slice(array_values(array_filter($list, 'is_int')), -TIMING_KEEP);
            $sorted = $list;
            sort($sorted);
            $median = $sorted[intdiv(count($sorted), 2)];
            $write->execute([
                $album, $track,
                mb_substr((string) ($s['artist'] ?? ''), 0, 160),
                mb_substr((string) ($s['albumName'] ?? ''), 0, 255),
                mb_substr((string) ($s['title'] ?? ''), 0, 255),
                json_encode($list), $median, count($list), now_sql(),
            ]);
            $pdo->commit();
            $accepted++;
        } catch (Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
    }
    json_out(200, ['accepted' => $accepted]);
}
