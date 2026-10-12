// Troca o nome antigo do app (VyniLyric / VinyLyric / VinylSync) por WaxClub em todo o projeto.
// Uso: node tool/rename_to_waxclub.js [--dry]
// O RELEASE_LOG.md fica de fora: o histórico registra os nomes usados em cada versão.
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const DRY = process.argv.includes('--dry');
const SKIP_DIRS = new Set(['build', '.dart_tool', '.gradle', '.git', '.idea', 'node_modules', '.kotlin', 'covers', 'backups', '.claude']);
const SKIP_FILES = new Set(['RELEASE_LOG.md', 'rename_to_waxclub.js']);
const EXT = /\.(dart|yaml|xml|kts|gradle|kt|java|html|md|ps1|js|json|plist|txt|properties|iml|cs|cpp|h|rc|cmake|manifest)$/i;

// Da regra mais específica para a mais geral
const RULES = [
  [/urn:x-cast:com\.vinylyric\.sync/g, 'urn:x-cast:com.waxclub.sync'],
  [/com\.vinylyric\.vinylyric/g, 'com.waxclub.app'],
  [/com\/vinylyric\/vinylyric/g, 'com/waxclub/app'],
  [/com\.vinylyric\./g, 'com.waxclub.'],
  [/vinylyric-tv/g, 'WaxClub'],
  [/(vynilyric|vinylyric)\.app/gi, 'waxclub.app'],
  [/package:vinylyric\//g, 'package:waxclub/'],
  [/VinylSyncEngine/g, 'WaxClubEngine'],
  [/vinyl_sync_engine/g, 'waxclub_engine'],
  [/VinylSyncApp/g, 'WaxClubApp'],
  [/VinylLyricsScreen/g, 'HomeScreen'],
  [/vinyl_lyrics_screen/g, 'home_screen'],
  [/vinylsync_lyrics/g, 'waxclub'],
  [/MANUAL_FUNCIONAL_VINYLYRIC/g, 'MANUAL_FUNCIONAL_WAXCLUB'],
  [/VinylSync Lyrics/g, 'WaxClub'],
  [/VyniLyric|VinyLyric|VinylSync/g, 'WaxClub'],
  [/VYNILYRIC|VINYLYRIC/g, 'WAXCLUB'],
  [/vinylyric|vynilyric|vinylsync/g, 'waxclub'],
];

function walk(dir, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) {
      if (!SKIP_DIRS.has(e.name)) walk(path.join(dir, e.name), out);
    } else if (EXT.test(e.name) && !SKIP_FILES.has(e.name)) {
      out.push(path.join(dir, e.name));
    }
  }
  return out;
}

let changedFiles = 0;
let total = 0;
for (const file of walk(ROOT, [])) {
  const buf = fs.readFileSync(file);
  const bom = buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf;
  const text = buf.toString('utf8', bom ? 3 : 0);
  let out = text;
  let count = 0;
  for (const [re, rep] of RULES) {
    out = out.replace(re, () => {
      count++;
      return rep;
    });
  }
  if (count > 0) {
    changedFiles++;
    total += count;
    console.log(`${String(count).padStart(4)}  ${path.relative(ROOT, file)}`);
    if (!DRY) fs.writeFileSync(file, Buffer.concat([bom ? Buffer.from([0xef, 0xbb, 0xbf]) : Buffer.alloc(0), Buffer.from(out, 'utf8')]));
  }
}
console.log(`${DRY ? '[simulação] ' : ''}${total} trocas em ${changedFiles} arquivos`);
