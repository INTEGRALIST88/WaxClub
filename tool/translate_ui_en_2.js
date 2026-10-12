// Segunda rodada da tradução para inglês (textos dentro de condições e mensagens de status).
// Uso: node tool/translate_ui_en_2.js
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '..');

const T = {
  'lib/engine/waxclub_engine.dart': [["'Microfone desligado. Escuta parada.'", "'Microphone off. Listening stopped.'"]],
  'lib/models/sync_state.dart': [["this.statusMessage = 'Microfone desligado'", "this.statusMessage = 'Microphone off'"]],
  'lib/services/audio_record_service.dart': [["'Microfone interno'", "'Built-in microphone'"]],
  'lib/services/cast_v2_client.dart': [
    ["_statusStep = 'Desconectado';", "_statusStep = 'Disconnected';"],
    ["'Conectando ao Chromecast via TLS ($host:$port)...'", "'Connecting to Chromecast over TLS ($host:$port)...'"],
  ],
  'lib/ui/screens/home_screen.dart': [["'A seguir: ${_engine.telemetry.predictedNextTrackTitle!}", "'Up next: ${_engine.telemetry.predictedNextTrackTitle!}"]],
  'lib/ui/widgets/cast_thinking_wheel_dialog.dart': [
    ["'Verificando dispositivo em $ip:8009...'", "'Checking device at $ip:8009...'"],
    ["'Procurando... ${devices.length} encontrado(s)'", "'Searching... ${devices.length} found'"],
    ["'Em espera • '", "'Idle • '"],
    ["_showManualIp ? 'Ocultar IP' : 'Adicionar por IP'", "_showManualIp ? 'Hide IP' : 'Add by IP'"],
    ["const Text('Adicionar',", "const Text('Add',"],
    ["const Text('Trocar TV')", "const Text('Change TV')"],
  ],
  'lib/ui/widgets/vinyl_control_cockpit.dart': [
    ["_coverBadge('faixas ▸')", "_coverBadge('tracks ▸')"],
    ["'medida em $samples escutas' : (engine.isHardwareSpeedCalibrated ? 'rotação conhecida' : 'calibrando...')", "'measured over $samples listens' : (engine.isHardwareSpeedCalibrated ? 'known speed' : 'calibrating...')"],
  ],
  'lib/ui/widgets/vinyl_status_footer.dart': [
    ["'⟳ confirmando...'", "'⟳ confirming...'"],
    ["'Calibrando em ${telemetry.countdownSeconds}s'", "'Calibrating in ${telemetry.countdownSeconds}s'"],
    ["tooltip: 'Parar escuta e encerrar'", "tooltip: 'Stop listening'"],
    ["'Ajustar tempo:'", "'Adjust timing:'"],
    ["'MICROFONE DESLIGADO'", "'MICROPHONE OFF'"],
  ],
};

let missing = 0;
let applied = 0;
for (const [rel, pairs] of Object.entries(T)) {
  const file = path.join(ROOT, rel);
  const buf = fs.readFileSync(file);
  const bom = buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf;
  let text = buf.toString('utf8', bom ? 3 : 0);
  for (const [from, to] of pairs) {
    if (!text.includes(from)) {
      console.log(`não encontrado em ${rel}: ${from.slice(0, 90)}`);
      missing++;
      continue;
    }
    text = text.split(from).join(to);
    applied++;
  }
  fs.writeFileSync(file, Buffer.concat([bom ? Buffer.from([0xef, 0xbb, 0xbf]) : Buffer.alloc(0), Buffer.from(text, 'utf8')]));
}
console.log(`aplicados: ${applied}, não encontrados: ${missing}`);
