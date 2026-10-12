// Limpa os nomes dos discos do catálogo de trilhas:
//   "7. O Outro internacional: 1.164.299 cópias" → "O Outro Internacional"
//   "Babilônia trilha sonora volume 1"           → "Babilônia Volume 1"
//   "Véu de Noiva trilha sonora"                  → "Véu de Noiva"
// O ano entre parênteses só fica quando dois discos teriam o mesmo nome (remakes).
// Uso: node clean_titles.js <catalogo.json>
const fs = require('fs');

const FILE = process.argv[2];
const cat = JSON.parse(fs.readFileSync(FILE, 'utf8'));

const CAP = ['nacional', 'internacional', 'instrumental', 'complementar', 'volume', 'sonora', 'especial', 'infantil'];

function clean(raw) {
  let s = raw
    .replace(/^\s*\d+\s*[.)º°-]\s*/, '') // posição no ranking
    .replace(/\s*:\s*[\d.]+\s*c[óo]pias\.?\s*$/i, '') // vendagem
    .replace(/\btrilha\s+sonora\b/gi, ' ')
    .replace(/\btrilhas?\b/gi, ' ')
    .replace(/[´']/g, '’')
    .replace(/\s+/g, ' ')
    .replace(/\s+([:,])/g, '$1')
    .trim();
  for (const w of CAP) s = s.replace(new RegExp(`\\b${w}\\b`, 'gi'), w[0].toUpperCase() + w.slice(1));
  // "Vol. 2" / "volume 2" padronizados
  s = s.replace(/\bVol\.?\s*(\d)/gi, 'Volume $1');
  return s.replace(/[\s:–-]+$/, '').trim();
}

const withYear = cat.discs.map((d) => clean(d.album));
const withoutYear = withYear.map((t) => t.replace(/\s*\((19|20)\d{2}\)\s*/g, ' ').replace(/\s+/g, ' ').trim());
const count = {};
for (const t of withoutYear) count[t.toLowerCase()] = (count[t.toLowerCase()] || 0) + 1;

let changed = 0;
cat.discs.forEach((d, i) => {
  let name = withoutYear[i];
  if (count[name.toLowerCase()] > 1) {
    // Remake com o mesmo nome: mantém o ano (do título ou do disco) para diferenciar
    const year = (withYear[i].match(/\(((19|20)\d{2})\)/) || [])[1] || d.year;
    name = year ? `${name} (${year})` : withYear[i];
  }
  if (name !== d.album) changed++;
  d.album = name;
});

const seen = {};
const dups = cat.discs.filter((d) => (seen[d.album.toLowerCase()] = (seen[d.album.toLowerCase()] || 0) + 1) > 1);
fs.writeFileSync(FILE, JSON.stringify(cat));
console.log(`nomes alterados: ${changed}; nomes ainda repetidos: ${dups.length}`);
for (const d of dups) console.log('  repetido:', d.album, d.year, d.url);
