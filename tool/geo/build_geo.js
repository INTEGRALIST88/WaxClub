// Gera a base de locais da API (server/api/data) a partir dos arquivos do GeoNames (CC BY 4.0):
//   countryInfo.txt, admin1CodesASCII.txt e cities1000.txt (de cities1000.zip), em https://download.geonames.org/export/dump/
// Uso: node build_geo.js <pastaComOsArquivos> <pastaDeSaida>
// Saída: countries.tsv (code, name), states.tsv (country, code, name),
//        cities.tsv.gz (id, country, state, name, search_name, population).
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const readline = require('readline');

const [SRC, OUT] = process.argv.slice(2);
if (!SRC || !OUT) throw new Error('uso: node build_geo.js <pastaGeoNames> <pastaSaida>');
fs.mkdirSync(OUT, { recursive: true });

const clean = (s) => s.replace(/[\t\r\n]/g, ' ').trim();
// igual ao geo_search_text() do PHP: minúsculo, sem acentos, só letras, números, espaço, apóstrofo e hífen
const searchText = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9 '\-]/g, '');

// países
const countries = [];
for (const line of fs.readFileSync(path.join(SRC, 'countryInfo.txt'), 'utf8').split('\n')) {
  if (!line || line.startsWith('#')) continue;
  const f = line.split('\t');
  if (f[0] && f[4]) countries.push([f[0], clean(f[4])]);
}

// estados/províncias (admin1)
const states = new Map(); // "BR.27" -> nome
for (const line of fs.readFileSync(path.join(SRC, 'admin1CodesASCII.txt'), 'utf8').split('\n')) {
  const f = line.split('\t');
  if (f.length >= 2 && f[0].includes('.')) states.set(f[0], clean(f[1]));
}

// cidades: lugares habitados, sem bairros (PPLX), históricos, abandonados ou destruídos
const skip = new Set(['PPLX', 'PPLH', 'PPLQ', 'PPLW', 'PPLCH']);
const usedStates = new Set();
const rows = [];
(async () => {
  const rl = readline.createInterface({ input: fs.createReadStream(path.join(SRC, 'cities1000.txt'), 'utf8'), crlfDelay: Infinity });
  for await (const line of rl) {
    const f = line.split('\t');
    if (f.length < 15 || f[6] !== 'P' || skip.has(f[7])) continue;
    const cc = f[8];
    const stateKey = `${cc}.${f[10]}`;
    const state = states.has(stateKey) ? f[10] : '';
    if (state) usedStates.add(stateKey);
    const name = clean(f[1]);
    const search = searchText(f[2] || f[1]);
    if (!name || !search) continue;
    rows.push([f[0], cc, state, name, search, parseInt(f[14], 10) || 0].join('\t'));
  }

  const statesOut = [...usedStates].sort().map((k) => {
    const [cc, code] = k.split('.');
    return [cc, code, states.get(k)].join('\t');
  });
  fs.writeFileSync(path.join(OUT, 'countries.tsv'), countries.map((c) => c.join('\t')).join('\n') + '\n');
  fs.writeFileSync(path.join(OUT, 'states.tsv'), statesOut.join('\n') + '\n');
  fs.writeFileSync(path.join(OUT, 'cities.tsv.gz'), zlib.gzipSync(rows.join('\n') + '\n', { level: 9 }));
  const size = fs.statSync(path.join(OUT, 'cities.tsv.gz')).size;
  console.log(`países: ${countries.length}, estados: ${statesOut.length}, cidades: ${rows.length} (${(size / 1048576).toFixed(1)} MB)`);
})();
