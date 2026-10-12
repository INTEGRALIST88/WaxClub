// Lista os textos (literais de string) visíveis ao usuário em lib/, ignorando comentários, logs e imports.
// Uso: node tool/list_ui_strings.js [--pt]   (--pt: só os que parecem português)
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', 'lib');
const ONLY_PT = process.argv.includes('--pt');
const PT = /[áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ]|\b(de|da|do|para|não|com|sem|uma|um|ou|no|na|os|as|seu|sua|toque|ouvir|disco|faixa|letra|música|lado|vire|conectar|desconectar|buscar|rotação|aguardando|carregando|erro|falha|sincronia|próxima|tocando|ajuste|zerar|travar|capa|cancelar|salvar|sair|tentar|novamente|pausado|ouvindo|nenhum|nenhuma|aqui|agora|tela|celular)\b/i;

function walk(dir, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.dart') && e.name !== 'tv_web_receiver_html.dart') out.push(p);
  }
  return out;
}

const SKIP_LINE = /^\s*(\/\/|\*|import |export |part )|debugPrint\(|_logService\.log\(|logService\.log\(|print\(|throw StateError|RegExp\(|@visibleForTesting/;
let total = 0;
for (const file of walk(ROOT, [])) {
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  const found = [];
  lines.forEach((line, i) => {
    if (SKIP_LINE.test(line)) return;
    const re = /'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)"/g;
    let m;
    while ((m = re.exec(line))) {
      const s = m[1] ?? m[2];
      if (!/[A-Za-zÀ-ú]{3,}/.test(s)) continue;
      if (/^(https?:|package:|assets\/|urn:|[a-z_]+\.[a-z]+$|[a-z]+_[a-z_]+$)/.test(s)) continue;
      if (ONLY_PT && !PT.test(s)) continue;
      found.push(`${String(i + 1).padStart(5)}: ${s.slice(0, 110)}`);
    }
  });
  if (found.length) {
    total += found.length;
    console.log(`\n## ${path.relative(ROOT, file)} (${found.length})`);
    console.log(found.join('\n'));
  }
}
console.log(`\nTotal: ${total}`);
