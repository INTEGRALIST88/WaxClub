// Minutagens e lados do SELO dos LPs de trilhas (Som Livre) a partir da API pública do Discogs.
// Uso: node discogs_labels.js <catalogo.json> <pastaTrabalho>
// Gera <pastaTrabalho>/discogs_durations.json: { "nome do disco": { releaseId, tracks: [[lado, ms], ...] } }
const fs = require('fs');
const path = require('path');

const [CATALOG, WORK] = process.argv.slice(2);
const OUT = path.join(WORK, 'discogs_durations.json');
const LIST_CACHE = path.join(WORK, 'discogs_somlivre_releases.json');
const REL_CACHE_DIR = path.join(WORK, 'discogs_releases');
fs.mkdirSync(REL_CACHE_DIR, { recursive: true });

const LABELS = [13768]; // Som Livre
const UA = { 'User-Agent': 'WaxClub/1.3 +https://github.com/INTEGRALIST88/WaxClub' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let last = 0;
async function api(url) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const wait = 2600 - (Date.now() - last); // ~23 por minuto (limite sem login: 25)
    if (wait > 0) await sleep(wait);
    last = Date.now();
    try {
      const res = await fetch(url, { headers: UA });
      if (res.status === 429) {
        await sleep(30000);
        continue;
      }
      if (res.status === 404) return null;
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return await res.json();
    } catch (e) {
      await sleep(5000 * (attempt + 1));
    }
  }
  return null;
}

const norm = (s) =>
  (s || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\btrilha sonora( original)?( da novela)?\b|\bda novela\b|\btrilha\b|\bnovela\b|\bsonora\b|\boriginal\b/g, ' ')
    .replace(/\bvol(ume)?\.?\s*/g, 'volume ')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

function sim(a, b) {
  a = norm(a);
  b = norm(b);
  if (!a || !b) return 0;
  if (a === b) return 1;
  const ta = new Set(a.split(' '));
  const tb = new Set(b.split(' '));
  const inter = [...ta].filter((t) => tb.has(t)).length;
  return inter / Math.max(ta.size, tb.size);
}

/**
 * Nome da novela + tipo do disco, para comparar "Pecado Capital Nacional (1975)" com
 * "Pecado Capital (Trilha Sonora Original Da Novela)" e "O Outro Internacional" com "O Outro (Internacional)".
 */
function keyOf(title) {
  let t = (title || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  t = t.replace(/\((19|20)\d\d\)/g, ' ');
  let type = 'nacional';
  if (/internacional|international/.test(t)) type = 'internacional';
  else if (/instrumental/.test(t)) type = 'instrumental';
  else if (/complementar/.test(t)) type = 'complementar';
  const vol = t.match(/\bvol(?:ume)?\.?\s*(\d)/);
  if (vol) type += ' ' + vol[1];
  const name = t
    .replace(/\(.*?\)/g, ' ')
    .replace(/\b(trilha sonora|trilha|sonora|original|da novela|novela|nacional|internacional|international|instrumental|complementar|vol(ume)?\.?\s*\d)\b/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
  return { name, type };
}

function parseDuration(s) {
  if (!s) return null;
  const p = s.trim().split(':').map(Number);
  if (p.some(isNaN)) return null;
  const sec = p.reduce((a, b) => a * 60 + b, 0);
  return sec > 20 ? sec * 1000 : null;
}

async function labelReleases() {
  if (fs.existsSync(LIST_CACHE)) return JSON.parse(fs.readFileSync(LIST_CACHE, 'utf8'));
  const all = [];
  for (const label of LABELS) {
    let page = 1;
    let pages = 1;
    do {
      const j = await api(`https://api.discogs.com/labels/${label}/releases?per_page=100&page=${page}`);
      if (!j) break;
      pages = j.pagination?.pages || 1;
      for (const r of j.releases || []) {
        all.push({ id: r.id, title: r.title, year: r.year, format: r.format || '', artist: r.artist });
      }
      if (page % 10 === 0) console.log(`lista Som Livre: página ${page}/${pages}`);
      page++;
    } while (page <= pages);
  }
  fs.writeFileSync(LIST_CACHE, JSON.stringify(all));
  return all;
}

async function release(id) {
  const file = path.join(REL_CACHE_DIR, `${id}.json`);
  if (fs.existsSync(file)) return JSON.parse(fs.readFileSync(file, 'utf8'));
  const j = await api(`https://api.discogs.com/releases/${id}`);
  if (j) fs.writeFileSync(file, JSON.stringify({ id: j.id, title: j.title, year: j.year, tracklist: j.tracklist }));
  return j;
}

/** Alinha as faixas do Discogs às do catálogo (pela ordem, conferindo títulos). */
function align(catTracks, dTracks) {
  const tracks = dTracks.filter((t) => (t.type_ || 'track') === 'track' && t.title);
  const out = [];
  let matched = 0;
  for (let i = 0; i < catTracks.length; i++) {
    // procura a faixa de mesmo título perto da mesma posição
    let best = null;
    let bestScore = 0;
    for (let j = Math.max(0, i - 3); j < Math.min(tracks.length, i + 4); j++) {
      const s = sim(catTracks[i].title, tracks[j].title);
      if (s > bestScore) {
        bestScore = s;
        best = tracks[j];
      }
    }
    if (best && bestScore >= 0.5) {
      matched++;
      const side = ((best.position || '').match(/^([A-Za-z])/) || [])[1];
      out.push([side ? side.toUpperCase() : null, parseDuration(best.duration)]);
    } else {
      out.push([null, null]);
    }
  }
  return { tracks: out, matched, withDuration: out.filter((t) => t[1]).length };
}

(async () => {
  const cat = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));
  const result = fs.existsSync(OUT) ? JSON.parse(fs.readFileSync(OUT, 'utf8')) : {};
  const releases = (await labelReleases()).filter((r) => /lp|vinyl/i.test(r.format) && (!r.year || r.year <= 1996));
  console.log('LPs da Som Livre no Discogs:', releases.length);

  const lps = cat.discs.filter((d) => !d.year || d.year <= 1993);
  let found = 0;
  let n = 0;
  for (const disc of lps) {
    n++;
    if (result[disc.album]) {
      found++;
      continue;
    }
    // candidatos: título parecido e ano compatível (lançamentos da mesma trilha, várias prensagens)
    const target = keyOf(disc.album);
    const candidates = releases
      .map((r) => {
        const k = keyOf(r.title);
        return { r, s: k.type === target.type ? sim(k.name, target.name) : 0 };
      })
      .filter(({ r, s }) => s >= 0.8 && (!disc.year || !r.year || Math.abs(r.year - disc.year) <= 1))
      .sort((a, b) => b.s - a.s)
      .slice(0, 4);
    let best = null;
    for (const { r } of candidates) {
      const rel = await release(r.id);
      if (!rel || !rel.tracklist) continue;
      const a = align(disc.tracks, rel.tracklist);
      if (a.matched < disc.tracks.length * 0.6) continue; // outra trilha com nome parecido
      if (!best || a.withDuration > best.withDuration) best = { ...a, releaseId: r.id };
      if (a.withDuration >= disc.tracks.length * 0.8) break; // prensagem com minutagem no selo
    }
    if (best && (best.withDuration > 0 || best.tracks.some((t) => t[0]))) {
      result[disc.album] = { releaseId: best.releaseId, tracks: best.tracks };
      found++;
    }
    if (n % 20 === 0) {
      fs.writeFileSync(OUT, JSON.stringify(result, null, 1));
      console.log(`${n}/${lps.length} LPs, ${found} encontrados no Discogs`);
    }
  }
  fs.writeFileSync(OUT, JSON.stringify(result, null, 1));
  const withDur = Object.values(result).filter((r) => r.tracks.some((t) => t[1])).length;
  console.log(`concluído: ${found}/${lps.length} LPs encontrados, ${withDur} com minutagem do selo`);
})();
