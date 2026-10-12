// Traduz para inglês os textos visíveis da página da TV (web_receiver/index.html).
// Uso: node tool/translate_tv_en.js   (depois: tool/sync_tv_receiver.ps1)
const fs = require('fs');
const path = require('path');
const FILE = path.resolve(__dirname, '..', 'web_receiver', 'index.html');

const PAIRS = [
  ['<html lang="pt-BR">', '<html lang="en">'],
  ['<div id="album" class="album">Pronto para tocar</div>', '<div id="album" class="album">Ready to play</div>'],
  ['<div class="caption">A seguir</div>', '<div class="caption">Up next</div>'],
  ['<span id="pillText">Ouvindo</span>', '<span id="pillText">Listening</span>'],
  ['<div class="big">Coloque a agulha no disco</div>', '<div class="big">Drop the needle on the record</div>'],
  ['<div class="small">Toque no microfone do celular para sincronizar a letra</div>', '<div class="small">Tap the microphone on your phone to sync the lyrics</div>'],
  ['<div class="caption">Rotação medida</div>', '<div class="caption">Measured speed</div>'],
  ["track.title || 'Música identificada'", "track.title || 'Song identified'"],
  ["'Letra não encontrada para esta faixa'", "'No lyrics found for this track'"],
  ["el('pillText').textContent = 'Ouvindo o disco';", "el('pillText').textContent = 'Listening to the record';"],
  ["(data.statusMessage || 'Vire o disco')", "(data.statusMessage || 'Flip the record')"],
  ["data.awaitingNeedle ? 'Aguardando a agulha'", "data.awaitingNeedle ? 'Waiting for the needle'"],
  ["(paused ? 'Pausado' : '')", "(paused ? 'Paused' : '')"],
  ["el('album').textContent = 'Pronto para tocar';", "el('album').textContent = 'Ready to play';"],
  ["placeholder.querySelector('.big').textContent = 'Coloque a agulha no disco';", "placeholder.querySelector('.big').textContent = 'Drop the needle on the record';"],
  ["placeholder.querySelector('.small').textContent = 'Toque no microfone do celular para sincronizar a letra';", "placeholder.querySelector('.small').textContent = 'Tap the microphone on your phone to sync the lyrics';"],
  ["'Esta é uma letra de demonstração', 'para conferir o layout da TV', '',", "'These are demo lyrics', 'to preview the TV layout', '',"],
  ["'Três linhas ficam em destaque', 'a anterior, a atual e a próxima',", "'Three lines are highlighted', 'the previous, current and next',"],
  ["'todas com o mesmo tamanho', 'assim um pequeno atraso no tempo', 'quase não se percebe', '',", "'all the same size', 'so a small timing offset', 'is hardly noticeable', '',"],
  ["'As outras linhas diminuem', 'e escurecem conforme se afastam',", "'The other lines shrink', 'and fade as they move away',"],
  ["'O texto fica sempre centralizado', 'e a agulha sobe pelo disco', 'da borda até o selo girando', '',", "'The text is always centered', 'and the needle moves across the record', 'from the edge to the spinning label', '',"],
  ["'Fim da demonstração'", "'End of demo'"],
  ["{ title: 'Faixa de Demonstração', artist: 'WaxClub', album: 'Layout da TV',", "{ title: 'Demo Track', artist: 'WaxClub', album: 'TV Layout',"],
  ["nextTitle: 'Próxima Faixa da Demonstração'", "nextTitle: 'Next Demo Track'"],
];

let text = fs.readFileSync(FILE, 'utf8');
let missing = 0;
for (const [from, to] of PAIRS) {
  if (!text.includes(from)) {
    console.log('não encontrado:', from.slice(0, 80));
    missing++;
  }
  text = text.split(from).join(to);
}
fs.writeFileSync(FILE, text);
console.log(`aplicados: ${PAIRS.length - missing}, não encontrados: ${missing}`);
