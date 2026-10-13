import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/models/lyric_line.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/cast_sync_service.dart';

/// Imita o ReceiverServer do app do Fire TV (WaxClubClient): WebSocket em /cast,
/// responde client_ready com server_ack e guarda os pacotes recebidos.
class _FakeTvApp {
  late HttpServer server;
  final List<Map<String, dynamic>> packets = [];
  final _acked = Completer<void>();
  Future<void> get acked => _acked.future;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path != '/cast' || !WebSocketTransformer.isUpgradeRequest(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(req);
      ws.listen((data) {
        final packet = jsonDecode(data as String) as Map<String, dynamic>;
        packets.add(packet);
        if (packet['type'] == 'client_ready') {
          ws.add(jsonEncode({'type': 'server_ack', 'status': 'confirmed'}));
          if (!_acked.isCompleted) _acked.complete();
        }
      });
    });
  }

  int get port => server.port;
  Future<void> stop() => server.close(force: true);
}

void main() {
  test('anúncio do app de TV vira aparelho WebSocket (não Chromecast) com nome e modelo', () {
    final dev = CastSyncService.tvAppDevice(ip: '192.168.1.50', port: 8088, txt: 'fn=Fire TV Sala\nmd=AFTKA\nv=1');
    expect(dev.name, 'Fire TV Sala');
    expect(dev.host, '192.168.1.50');
    expect(dev.port, 8088);
    expect(dev.isChromecast, isFalse);
    expect(dev.model, 'WaxClub TV app · AFTKA');

    final semTxt = CastSyncService.tvAppDevice(ip: '192.168.1.51', port: 8089);
    expect(semTxt.name, 'WaxClub TV (192.168.1.51)');
    expect(CastSyncService.tvAppServiceTypes, containsAll(['_waxclub-tv._tcp.local', '_vinylyric._tcp.local']));
  });

  test('"Add by IP" acha o app de TV pela porta do WebSocket, conecta, faz o handshake e envia a faixa', () async {
    final tv = _FakeTvApp();
    await tv.start();
    final service = CastSyncService();

    // 127.0.0.1 não tem Chromecast (8009 recusa): cai no servidor do app de TV
    final dev = await service.addManualIp('127.0.0.1', tvAppPort: tv.port);
    expect(dev, isNotNull);
    expect(dev!.isChromecast, isFalse);
    expect(service.discoveredDevices.any((d) => d.port == tv.port), isTrue);

    final ok = await service.connectTo(dev);
    expect(ok, isTrue);
    await tv.acked.timeout(const Duration(seconds: 3));
    expect(tv.packets.first['type'], 'client_ready');
    expect(service.isConnected, isTrue);

    service.sendTrack(
      const TrackInfo(title: 'Coming Around Again', artist: 'Carly Simon', album: 'O Outro Internacional', offsetSeconds: 0),
      [LyricLine(timestamp: const Duration(seconds: 1), text: 'Baby sneezes')],
      side: 'A',
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final loaded = tv.packets.firstWhere((p) => p['type'] == 'track_loaded');
    expect(loaded['track']['title'], 'Coming Around Again');
    expect(loaded['track']['side'], 'A');

    await service.disconnect(stopTvApp: true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(tv.packets.last['type'], 'stop');
    service.dispose();
    await tv.stop();
  });

  test('"Add by IP" sem Chromecast nem app de TV no endereço não adiciona nada', () async {
    final service = CastSyncService();
    // porta livre qualquer, sem servidor
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final freePort = probe.port;
    await probe.close();
    expect(await service.addManualIp('127.0.0.1', tvAppPort: freePort), isNull);
    service.dispose();
  });
}
