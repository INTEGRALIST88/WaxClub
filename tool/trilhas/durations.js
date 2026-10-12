// Completa discs.json com a duração de cada faixa (Deezer; reserva: iTunes) e gera o catálogo final.
// Uso: node durations.js <pasta> <saida.json>
const fs = require('fs');
const path = require('path');

const DIR = process.argv[2] || __dirname;
const OUT = process.argv[3] || path.join(DIR, 'trilhas_novelas.json');
const discs = JSON.parse(fs.readFileSync(path.join(DIR, 'discs.json'), 'utf8'));
const CACHE_FILE = path.join(DIR, 'durations_cache.json');
const cache = fs.existsSync(CACHE_FILE) ? JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8')) : {};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const norm = (s) =>
  (s || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\([^)]*\)|\[[^\]]*\]/g, ' ')
    .replace(/\b(feat|featuring|part|participacao|com)\b.*$/, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

function similarity(a, b) {
  a = norm(a);
  b = norm(b);
  if (!a || !b) return 0;
  if (a === b) return 1;
  if (a.includes(b) || b.includes(a)) return 0.9;
  const ta = new Set(a.split(' '));
  const tb = new Set(b.split(' '));
  const inter = [...ta].filter((t) => tb.has(t)).length;
  return inter / Math.max(ta.size, tb.size);
}

function primaryArtist(a) {
  return (a || '').split(/\s+(?:e|&|feat\.?|featuring|com|part\.?|x)\s+|,|\//i)[0].trim();
}

let nextDeezerSlot = 0;
async function deezer(q) {
  // Fila global: ~8 consultas por segundo (limite da Deezer: 50 a cada 5s), com várias em paralelo
  const now = Date.now();
  nextDeezerSlot = Math.max(now, nextDeezerSlot) + 125;
  const wait = nextDeezerSlot - 125 - now;
  if (wait > 0) await sleep(wait);
  for (let i = 0; i < 3; i++) {
    try {
      const res = await fetch('https://api.deezer.com/search?limit=10&q=' + encodeURIComponent(q));
      const j = await res.json();
      if (j.error) {
        await sleep(2000 * (i + 1));
        continue;
      }
      return j.data || [];
    } catch {
      await sleep(1500 * (i + 1));
    }
  }
  return [];
}

let lastItunes = 0;
async function itunes(term) {
  const wait = 3100 - (Date.now() - lastItunes); // ~20 por minuto
  if (wait > 0) await sleep(wait);
  lastItunes = Date.now();
  try {
    const res = await fetch(
      'https://itunes.apple.com/search?entity=song&limit=10&country=BR&term=' + encodeURIComponent(term)
    );
    if (!res.ok) return [];
    const j = await res.json();
    return j.results || [];
  } catch {
    return [];
  }
}

function pick(results, title, artist, getTitle, getArtist, getMs) {
  let best = null;
  let bestScore = 0;
  for (const r of results) {
    const ts = similarity(getTitle(r), title);
    const as = similarity(getArtist(r), artist);
    const score = ts * 0.65 + as * 0.35;
    if (ts >= 0.6 && as >= 0.34 && score > bestScore && getMs(r) > 30000) {
      best = r;
      bestScore = score;
    }
  }
  return best ? getMs(best) : null;
}

async function lookup(title, artist) {
  const key = norm(artist) + '|' + norm(title);
  if (key in cache) return cache[key];
  const a = primaryArtist(artist);
  const t = title.replace(/\([^)]*\)/g, '').trim();
  let ms = null;
  let res = await deezer(`${a} ${t}`);
  ms = pick(res, t, a, (r) => r.title, (r) => r.artist?.name, (r) => (r.duration || 0) * 1000);
  if (ms == null) {
    res = await deezer(t);
    ms = pick(res, t, a, (r) => r.title, (r) => r.artist?.name, (r) => (r.duration || 0) * 1000);
  }
  if (ms == null && useItunes) {
    const it = await itunes(`${a} ${t}`);
    ms = pick(it, t, a, (r) => r.trackName, (r) => r.artistName, (r) => r.trackTimeMillis || 0);
  }
  cache[key] = ms;
  return ms;
}

const useItunes = process.argv.includes('--itunes');

// "PONTE DOS SUSPIROS" → "Ponte dos Suspiros"
const SMALL = new Set(['a', 'o', 'as', 'os', 'e', 'de', 'da', 'do', 'das', 'dos', 'em', 'no', 'na', 'nos', 'nas', 'um', 'uma',
  'por', 'pra', 'pro', 'com', 'que', 'se', 'the', 'of', 'and', 'in', 'on', 'to', 'for', 'at', 'by', 'y', 'el', 'la', 'los', 'del']);
function titleCase(s) {
  if (s !== s.toUpperCase()) return s; // já está em caixa mista
  return s
    .toLowerCase()
    .split(/(\s+|-|\()/)
    .map((w, i) => (i > 0 && SMALL.has(w) ? w : w.charAt(0).toUpperCase() + w.slice(1)))
    .join('')
    .replace(/\b(i{1,3}|iv|v|vi{0,3})\b/gi, (m) => m.toUpperCase());
}

(async () => {
  let done = 0;
  let found = 0;
  const total = discs.reduce((a, d) => a + d.tracks.length, 0);
  const queue = discs.flatMap((d) => d.tracks);
  async function worker() {
    while (queue.length) {
      const t = queue.shift();
      const ms = await lookup(t.title, t.artist);
      t.lengthMs = ms ?? undefined;
      if (ms) found++;
      if (++done % 500 === 0) {
        console.log(`${done}/${total} faixas, ${found} com duração`);
        fs.writeFileSync(CACHE_FILE, JSON.stringify(cache));
      }
    }
  }
  await Promise.all(Array.from({ length: 6 }, worker));
  fs.writeFileSync(CACHE_FILE, JSON.stringify(cache));

  // Catálogo final, enxuto, para o app
  const catalog = {
    source: 'Teledramaturgia / Observatório da TV (observatoriodatv.com.br/teledramaturgia)',
    generatedAt: new Date().toISOString().slice(0, 10),
    discs: discs.map((d) => ({
      album: d.title,
      network: d.network,
      year: d.year ?? undefined,
      cover: d.cover ?? undefined,
      url: d.url,
      tracks: d.tracks.map((t) => ({
        title: titleCase(t.title),
        artist: t.artist,
        ...(t.side ? { side: t.side } : {}),
        ...(t.lengthMs ? { lengthMs: t.lengthMs } : {}),
      })),
    })),
  };
  fs.writeFileSync(OUT, JSON.stringify(catalog));
  console.log(`concluído: ${discs.length} discos, ${total} faixas, ${found} com duração → ${OUT}`);
})();
