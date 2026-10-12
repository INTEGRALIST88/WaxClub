// Varre as trilhas sonoras de novelas do Teledramaturgia (Observatório da TV) e gera discs.json.
// Uso: node crawl.js <pastaSaida>
const fs = require('fs');
const path = require('path');

const OUT = process.argv[2] || __dirname;
const CACHE = path.join(OUT, 'html');
fs.mkdirSync(CACHE, { recursive: true });

const BASE = 'https://observatoriodatv.com.br/teledramaturgia/';
const INDEXES = [
  ['trilhas-sonoras-globo-1970-a-1974', 'Globo'],
  ['trilhas-sonoras-globo-1975-a-1979', 'Globo'],
  ['trilhas-sonoras-globo-1980-a-1984', 'Globo'],
  ['trilhas-sonoras-globo-1985-a-1989', 'Globo'],
  ['trilhas-sonoras-globo-1990-a-1994-b', 'Globo'],
  ['trilhas-sonoras-globo-1995-a-1999', 'Globo'],
  ['trilhas-sonoras-globo-2000-a-2004', 'Globo'],
  ['trilhas-sonoras-globo-2005-a-2009', 'Globo'],
  ['trilhas-sonoras', 'Globo'],
  ['trilhas-sonoras-globo-2015-a-2019', 'Globo'],
  ['trilhas-sonoras-malhacao', 'Globo'],
  ['trilhas-sonoras-series-e-minisseries', 'Globo'],
  ['trilhas-sonoras-record', 'Record'],
  ['trilhas-sonoras-sbt', 'SBT'],
  ['trilhas-sonoras-band', 'Band'],
  ['trilhas-sonoras-manchete', 'Manchete'],
  ['trilhas-sonoras-excelsior', 'Excelsior'],
  ['trilhas-sonoras-tupi-1', 'Tupi'],
  ['trilhas-sonoras-tupi-2', 'Tupi'],
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function get(url) {
  const key = url.replace(/^https?:\/\//, '').replace(/[^a-z0-9]+/gi, '_').slice(0, 180) + '.html';
  const file = path.join(CACHE, key);
  if (fs.existsSync(file)) return fs.readFileSync(file, 'utf8');
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0 (WaxClub catalog builder)' }, redirect: 'follow' });
      if (res.status === 404) return null;
      if (!res.ok) throw new Error('HTTP ' + res.status);
      const html = await res.text();
      fs.writeFileSync(file, html);
      await sleep(700); // educado com o servidor
      return html;
    } catch (e) {
      await sleep(2000 * (attempt + 1));
    }
  }
  return null;
}

const ENT = { '&amp;': '&', '&quot;': '"', '&#039;': "'", '&#39;': "'", '&nbsp;': ' ', '&lt;': '<', '&gt;': '>',
  '&#8211;': '–', '&#8212;': '—', '&#8217;': '’', '&#8216;': '‘', '&#8220;': '“', '&#8221;': '”', '&#8230;': '…', '&#038;': '&' };
const decode = (s) => s.replace(/&#?\w+;/g, (m) => ENT[m] ?? (m.startsWith('&#') ? String.fromCharCode(parseInt(m.slice(2, -1), 10)) : m));

function postContent(html) {
  const start = html.indexOf('class="post-content"');
  if (start < 0) return null;
  let end = html.indexOf('Veja também', start);
  if (end < 0) end = html.indexOf('fusion-sep-clear', start);
  if (end < 0) end = start + 40000;
  return html.slice(start, end);
}

function discLinks(html) {
  const block = html;
  const links = [];
  const re = /<h4 class="entry-title"><a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/g;
  let m;
  while ((m = re.exec(block))) {
    const href = m[1];
    const text = decode(m[2].replace(/<[^>]+>/g, '')).trim();
    if (!text || href.includes('#')) continue;
    if (!/teledramaturgia/.test(href)) continue;
    if (/trilhas-sonoras|trilhas-mais-vendidas/.test(href)) continue; // navegação entre índices
    links.push({ href: href.replace(/^http:\/\/(www\.)?teledramaturgia\.com\.br\//, BASE), text });
  }
  return links;
}

function toLines(block) {
  return decode(
    block
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/(p|div|h\d|li)>/gi, '\n')
      .replace(/<[^>]+>/g, '')
  )
    .split('\n')
    .map((l) => l.replace(/\s+/g, ' ').trim())
    .filter(Boolean);
}

const TRACK = /^(?:([A-D])\s*[-.]?\s*)?(\d{1,2})\s*[.)\-–]\s*(.+?)\s+[–—-]\s+(.+)$/;

function parseDisc(html, url, network, linkText) {
  const block = postContent(html);
  if (!block) return null;
  const h1 = (html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/) || [])[1];
  const title = decode((h1 || linkText).replace(/<[^>]+>/g, '')).trim();
  const imgMatch = block.match(/<img[^>]+src="([^"]+)"/);
  let cover = imgMatch ? imgMatch[1] : null;
  if (cover) cover = cover.replace(/^http:\/\/(www\.)?teledramaturgia\.com\.br\//, BASE);

  const lines = toLines(block);
  const tracks = [];
  let side = null;
  let year = null;
  for (const line of lines) {
    const sideHead = line.match(/^lado\s*([A-D1-4])\b/i);
    if (sideHead) {
      const s = sideHead[1].toUpperCase();
      side = /\d/.test(s) ? 'ABCD'[parseInt(s, 10) - 1] : s;
      continue;
    }
    if (/^(19[5-9]\d|20[0-2]\d)$/.test(line)) {
      year = parseInt(line, 10);
      continue;
    }
    const m = line.match(TRACK);
    if (m) {
      let trackTitle = m[3].trim();
      let artist = m[4].replace(/\((tema|abertura)[^)]*\)\s*$/i, '').trim();
      tracks.push({
        n: tracks.length + 1,
        number: (m[1] || side || '') + m[2],
        side: m[1] || side || null,
        title: trackTitle,
        artist,
        note: (m[4].match(/\(([^)]*(tema|abertura)[^)]*)\)/i) || [])[1] || undefined,
      });
    }
  }
  if (tracks.length < 3) {
    // Trilha instrumental: "01. TÍTULO" sem artista; o compositor/intérprete vem no fim da página
    const credit = lines
      .map((l) => (l.match(/m[úu]sicas?\s+(?:original|originais|de|composta[s]?\s+por)\s*:?\s*(.+)$/i) ||
        l.match(/interpretad[ao]s?\s+por\s+(.+?)\.?$/i) || l.match(/^int[ée]rpretes?\s*:\s*(.+)$/i) || [])[1])
      .find(Boolean);
    const artist = credit ? credit.replace(/\s*\(.*\)\s*$/, '').trim() : null;
    if (artist) {
      tracks.length = 0;
      for (const line of lines) {
        const m = line.match(/^(\d{1,2})\s*[.)\-–]\s*(.+)$/);
        if (m && !/^(19|20)\d\d$/.test(line)) {
          tracks.push({ n: tracks.length + 1, number: m[1], side: null, title: m[2].replace(/\((tema|abertura)[^)]*\)/i, '').trim(), artist });
        }
      }
    }
  }
  if (tracks.length < 2) return null; // compactos têm 2 faixas
  return { title, network, year, cover, url, tracks };
}

(async () => {
  const seen = new Set();
  const discs = [];
  for (const [slug, network] of INDEXES) {
    const html = await get(BASE + slug + '/');
    if (!html) {
      console.log('índice indisponível:', slug);
      continue;
    }
    const links = discLinks(html);
    console.log(slug, '→', links.length, 'links');
    for (const l of links) {
      if (seen.has(l.href)) continue;
      seen.add(l.href);
      const page = await get(l.href);
      if (!page) continue;
      const disc = parseDisc(page, l.href, network, l.text);
      if (disc) discs.push(disc);
    }
    fs.writeFileSync(path.join(OUT, 'discs.json'), JSON.stringify(discs, null, 1));
  }
  console.log('discos:', discs.length, 'faixas:', discs.reduce((a, d) => a + d.tracks.length, 0));
})();
