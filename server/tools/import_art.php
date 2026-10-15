<?php
// Importa o acervo de arte em domínio público (CC0) do plugin A3 "Imagined Music" para a tabela imagine_art.
// Uso (no servidor, por SSH): php import_art.php <arquivo.jsonl>   — uma obra por linha (gerado no PC).
// Pode rodar de novo: obras já importadas são atualizadas (mesmo id). Linhas com "emotion" (sentimentos
// aprovados na prancha) marcam a obra para aquele sentimento.
declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}
require __DIR__ . '/../api/lib/bootstrap.php';

$file = $argv[1] ?? '';
if ($file === '' || !is_readable($file)) {
    fwrite(STDERR, "uso: php import_art.php <arquivo.jsonl>\n");
    exit(1);
}
$museums = ['met' => 'The Met', 'aic' => 'Art Institute of Chicago'];
$emotions = ['love', 'desire', 'longing', 'loneliness', 'sadness', 'anger', 'fear', 'hope', 'joy', 'euphoria',
             'freedom', 'nostalgia', 'peace', 'melancholy', 'faith', 'rebellion'];
$sql = db()->prepare('REPLACE INTO imagine_art (id, source, museum, title, artist, date_text, kind, tags, file, width, height, color, emotion)
                      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
$n = 0;
$skipped = 0;
foreach (new SplFileObject($file) as $line) {
    $line = trim((string) $line);
    if ($line === '') {
        continue;
    }
    $r = json_decode($line, true);
    if (!is_array($r) || empty($r['file']) || empty($r['source']) || !isset($museums[$r['source']])) {
        $skipped++;
        continue;
    }
    $id = $r['source'] . '_' . $r['id'];
    $sql->execute([
        mb_substr($id, 0, 40),
        $r['source'],
        $museums[$r['source']],
        mb_substr((string) ($r['title'] ?? ''), 0, 255),
        mb_substr((string) ($r['artist'] ?? ''), 0, 160),
        mb_substr((string) ($r['date'] ?? ''), 0, 60),
        mb_substr((string) ($r['kind'] ?? ''), 0, 60),
        mb_substr(implode(' ', (array) ($r['tags'] ?? [])) . ' ' . (string) ($r['medium'] ?? ''), 0, 2000),
        basename((string) $r['file']),
        (int) ($r['width'] ?? 0),
        (int) ($r['height'] ?? 0),
        preg_match('/^#[0-9a-f]{6}$/i', (string) ($r['color'] ?? '')) ? $r['color'] : null,
        in_array($r['emotion'] ?? null, $emotions, true) ? $r['emotion'] : null,
    ]);
    $n++;
}
echo "importadas: $n, ignoradas: $skipped\n";
