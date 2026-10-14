<?php
// Fotos dos discos da coleção (tiradas pelo usuário no app): guardadas no banco, ligadas ao disco
// (item_key da coleção) e ao usuário. Só o dono vê, envia e apaga as dele.
declare(strict_types=1);

const PHOTO_MAX_BYTES = 1572864;   // 1,5 MB (o app envia ~1600 px, JPEG ~80%)
const PHOTO_MAX_SIDE = 2048;       // lado maior aceito
const PHOTOS_PER_RECORD = 40;
const PHOTOS_PER_USER = 2000;

function photo_json(array $r): array
{
    return [
        'id' => (int) $r['id'],
        'item' => $r['item_key'],
        'width' => (int) $r['width'],
        'height' => (int) $r['height'],
        'size' => (int) $r['size'],
        'createdAt' => sql_to_iso($r['created_at']),
    ];
}

// GET /v1/photos?item={key} — fotos de um disco (sem os bytes)
function photos_list(): void
{
    $user = require_user();
    $key = valid_key($_GET['item'] ?? null);
    $q = db()->prepare('SELECT id, item_key, width, height, size, created_at FROM record_photos
                        WHERE user_id = ? AND item_key = ? ORDER BY created_at, id');
    $q->execute([(int) $user['id'], $key]);
    json_out(200, ['photos' => array_map('photo_json', $q->fetchAll())]);
}

// POST /v1/photos?item={key} — corpo: a imagem (bytes JPEG, PNG ou WebP, já reduzida no app)
function photos_add(): void
{
    $user = require_user();
    $userId = (int) $user['id'];
    $key = valid_key($_GET['item'] ?? null);

    $raw = file_get_contents('php://input', false, null, 0, PHOTO_MAX_BYTES + 1);
    if ($raw === false || $raw === '') {
        fail(422, 'empty_photo');
    }
    if (strlen($raw) > PHOTO_MAX_BYTES) {
        fail(413, 'photo_too_large', ['max' => PHOTO_MAX_BYTES]);
    }
    $info = @getimagesizefromstring($raw);
    $types = [IMAGETYPE_JPEG => 'image/jpeg', IMAGETYPE_PNG => 'image/png', IMAGETYPE_WEBP => 'image/webp'];
    if ($info === false || !isset($types[$info[2] ?? 0])) {
        fail(415, 'unsupported_image');
    }
    $mime = $types[$info[2]];
    [$w, $h] = $info;
    if ($w < 1 || $h < 1 || max($w, $h) > PHOTO_MAX_SIDE) {
        fail(422, 'photo_dimensions', ['maxSide' => PHOTO_MAX_SIDE]);
    }

    $count = db()->prepare('SELECT
            SUM(item_key = ?) AS on_record,
            COUNT(*) AS total
        FROM record_photos WHERE user_id = ?');
    $count->execute([$key, $userId]);
    $c = $count->fetch();
    if ((int) ($c['on_record'] ?? 0) >= PHOTOS_PER_RECORD) {
        fail(409, 'too_many_photos', ['max' => PHOTOS_PER_RECORD]);
    }
    if ((int) ($c['total'] ?? 0) >= PHOTOS_PER_USER) {
        fail(409, 'photo_quota', ['max' => PHOTOS_PER_USER]);
    }

    $ins = db()->prepare('INSERT INTO record_photos (user_id, item_key, mime, width, height, size, data, created_at)
                          VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
    $ins->bindValue(1, $userId, PDO::PARAM_INT);
    $ins->bindValue(2, $key);
    $ins->bindValue(3, $mime);
    $ins->bindValue(4, $w, PDO::PARAM_INT);
    $ins->bindValue(5, $h, PDO::PARAM_INT);
    $ins->bindValue(6, strlen($raw), PDO::PARAM_INT);
    $ins->bindValue(7, $raw, PDO::PARAM_LOB);
    $ins->bindValue(8, now_sql());
    $ins->execute();
    $id = (int) db()->lastInsertId();

    $q = db()->prepare('SELECT id, item_key, width, height, size, created_at FROM record_photos WHERE id = ?');
    $q->execute([$id]);
    json_out(201, ['photo' => photo_json($q->fetch())]);
}

// GET /v1/photos/{id} — a imagem (só do dono)
function photos_get(string $id): void
{
    $user = require_user();
    $q = db()->prepare('SELECT mime, data FROM record_photos WHERE id = ? AND user_id = ?');
    $q->execute([(int) $id, (int) $user['id']]);
    $r = $q->fetch();
    if (!$r) {
        fail(404, 'not_found');
    }
    http_response_code(200);
    header('Content-Type: ' . $r['mime']);
    header('Cache-Control: private, max-age=31536000, immutable');
    header('Content-Length: ' . strlen($r['data']));
    echo $r['data'];
}

// DELETE /v1/photos/{id}
function photos_delete(string $id): void
{
    $user = require_user();
    $q = db()->prepare('DELETE FROM record_photos WHERE id = ? AND user_id = ?');
    $q->execute([(int) $id, (int) $user['id']]);
    if ($q->rowCount() === 0) {
        fail(404, 'not_found');
    }
    json_out(200, ['deleted' => (int) $id]);
}
