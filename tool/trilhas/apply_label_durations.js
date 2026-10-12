// Aplica no catálogo as minutagens e os lados do selo dos LPs (Discogs + correções manuais).
// As correções manuais (label_overrides.json, lidas da foto do selo) têm prioridade sobre o Discogs.
// Uso: node apply_label_durations.js <catalogo.json> <discogs_durations.json> <label_overrides.json>
const fs = require('fs');

const [CATALOG, DISCOGS, OVERRIDES] = process.argv.slice(2);
const cat = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));
const discogs = DISCOGS && fs.existsSync(DISCOGS) ? JSON.parse(fs.readFileSync(DISCOGS, 'utf8')) : {};
const overrides = OVERRIDES && fs.existsSync(OVERRIDES) ? JSON.parse(fs.readFileSync(OVERRIDES, 'utf8')) : {};

const toMs = (v) => {
  if (typeof v === 'number') return v;
  if (typeof v !== 'string') return null;
  const p = v.split(':').map(Number);
  return p.some(isNaN) ? null : p.reduce((a, b) => a * 60 + b, 0) * 1000;
};

let discs = 0;
let durations = 0;
let sides = 0;
for (const disc of cat.discs) {
  const manual = overrides[disc.album];
  const auto = discogs[disc.album];
  const source = manual || auto;
  if (!source) continue;
  const list = source.tracks.map((t) => [t[0] || null, toMs(t[1])]);
  if (list.length !== disc.tracks.length && manual) {
    console.log(`aviso: "${disc.album}" tem ${disc.tracks.length} faixas no catálogo e ${list.length} na correção manual`);
  }
  let touched = false;
  disc.tracks.forEach((t, i) => {
    const [side, ms] = list[i] || [];
    if (ms) {
      t.lengthMs = ms;
      durations++;
      touched = true;
    }
    if (side) {
      t.side = side;
      sides++;
      touched = true;
    }
  });
  if (touched) {
    disc.labelSource = manual ? manual.source || 'selo' : `discogs:${auto.releaseId}`;
    discs++;
  }
}
fs.writeFileSync(CATALOG, JSON.stringify(cat));
console.log(`discos corrigidos pelo selo: ${discs}, durações: ${durations}, lados: ${sides}`);
