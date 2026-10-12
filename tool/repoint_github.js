// Aponta os endereços do GitHub para o repositório INTEGRALIST88/WaxClub (código + página da TV no GitHub Pages).
// Uso: node tool/repoint_github.js
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SKIP = new Set(['build', '.dart_tool', '.git', '.gradle', 'covers', 'backups', 'node_modules', '.idea']);
const EXT = /\.(dart|yaml|xml|kts|kt|html|md|ps1|js|json|txt)$/i;
const RULES = [
  [/https:\/\/integralist88\.github\.io\/waxclub-tv\//gi, 'https://integralist88.github.io/WaxClub/'],
  [/https:\/\/github\.com\/integralist88\/waxclub-tv/gi, 'https://github.com/INTEGRALIST88/WaxClub'],
  [/integralist88\/waxclub-tv/gi, 'INTEGRALIST88/WaxClub'],
  [/waxclub-tv/g, 'WaxClub'],
];

function walk(dir, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) {
      if (!SKIP.has(e.name)) walk(path.join(dir, e.name), out);
    } else if (EXT.test(e.name) && e.name !== 'repoint_github.js') out.push(path.join(dir, e.name));
  }
  return out;
}

let total = 0;
for (const file of walk(ROOT, [])) {
  const buf = fs.readFileSync(file);
  const bom = buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf;
  let text = buf.toString('utf8', bom ? 3 : 0);
  let n = 0;
  for (const [re, rep] of RULES) text = text.replace(re, () => (n++, rep));
  if (n) {
    total += n;
    console.log(`${String(n).padStart(4)}  ${path.relative(ROOT, file)}`);
    fs.writeFileSync(file, Buffer.concat([bom ? Buffer.from([0xef, 0xbb, 0xbf]) : Buffer.alloc(0), Buffer.from(text, 'utf8')]));
  }
}
console.log(`${total} trocas`);
