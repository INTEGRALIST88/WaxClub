// Aponta as capas dos LPs para o GitHub Pages do WaxClub e remove os links do site de origem.
// Uso: node relink_covers.js <catalogo.json> <covers_map.json> <pastaCapasRecomprimidas>
const fs = require('fs');
const path = require('path');

const [CATALOG, MAP, COVERS] = process.argv.slice(2);
const BASE = 'https://integralist88.github.io/WaxClub/covers/';
const cat = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));
const map = JSON.parse(fs.readFileSync(MAP, 'utf8'));
let linked = 0;
let removed = 0;
for (const d of cat.discs) {
  const file = d.cover && map[d.cover] ? map[d.cover].replace(/\.\w+$/, '.jpg') : null;
  if (file && fs.existsSync(path.join(COVERS, file))) {
    d.cover = BASE + file;
    linked++;
  } else if (d.cover) {
    delete d.cover; // só capas hospedadas pelo WaxClub
    removed++;
  }
}
cat.coversBase = BASE;
fs.writeFileSync(CATALOG, JSON.stringify(cat));
const leftover = cat.discs.filter((d) => d.cover && !d.cover.startsWith(BASE)).length;
console.log(`capas no GitHub: ${linked}, sem capa: ${removed}, links externos restantes: ${leftover}`);
