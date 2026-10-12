// Baixa as capas dos LPs (trilhas até 1993) do catálogo, para hospedagem própria no GitHub Pages.
// Uso: node covers.js <catalogo.json> <pastaDownload>
// Gera <pastaDownload>/covers_map.json: { url original da capa → nome do arquivo }.
const fs = require('fs');
const path = require('path');

const CATALOG = process.argv[2];
const OUT = process.argv[3];
fs.mkdirSync(OUT, { recursive: true });
const cat = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const isVinyl = (d) => !d.year || d.year <= 1993;

// Nome estável a partir do endereço da página do disco: .../teledramaturgia/babilonia-volume-1/ → babilonia-volume-1
function slugFor(disc) {
  const m = (disc.url || '').match(/teledramaturgia\/([^/]+)\/?$/);
  const base = m ? m[1] : disc.album;
  return base
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 90);
}

async function download(url, file) {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0 (WaxClub catalog builder)' } });
      if (res.status === 404) return false;
      if (!res.ok) throw new Error('HTTP ' + res.status);
      const type = res.headers.get('content-type') || '';
      if (!type.startsWith('image/')) return false;
      fs.writeFileSync(file, Buffer.from(await res.arrayBuffer()));
      return true;
    } catch {
      await sleep(1500 * (attempt + 1));
    }
  }
  return false;
}

(async () => {
  const map = {};
  const vinyl = cat.discs.filter((d) => isVinyl(d) && d.cover);
  const used = new Set();
  let ok = 0;
  for (const disc of vinyl) {
    let slug = slugFor(disc);
    while (used.has(slug)) slug += '-2';
    used.add(slug);
    const ext = (disc.cover.match(/\.(jpe?g|png|gif|webp)(?:\?|$)/i) || [, 'jpg'])[1].toLowerCase();
    const file = path.join(OUT, `${slug}.${ext}`);
    if (!fs.existsSync(file)) {
      // Imagem original (sem o sufixo de miniatura "-300x300"), com a miniatura como reserva
      const original = disc.cover.replace(/-\d+x\d+(\.\w+)$/, '$1');
      const got = (original !== disc.cover && (await download(original, file))) || (await download(disc.cover, file));
      await sleep(400);
      if (!got) {
        console.log('sem capa:', disc.album);
        continue;
      }
    }
    map[disc.cover] = `${slug}.${ext}`;
    ok++;
  }
  fs.writeFileSync(path.join(OUT, 'covers_map.json'), JSON.stringify(map, null, 1));
  console.log(`capas de LP: ${ok}/${vinyl.length}`);
})();
