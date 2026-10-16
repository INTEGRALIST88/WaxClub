import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/ai_translator.dart' show MemoryTranslatorStore;
import 'package:waxclub/services/track_timing_service.dart';

class _FakeRemote implements TrackTimingRemote {
  final Map<String, Map<String, int>> data = {};
  final List<TimingSample> sent = [];
  bool offline = false;
  int fetches = 0;

  @override
  Future<Map<String, int>> fetch(String albumKey) async {
    fetches++;
    if (offline) throw Exception('offline');
    return data[albumKey] ?? const {};
  }

  @override
  Future<void> submit(List<TimingSample> samples) async {
    if (offline) throw Exception('offline');
    sent.addAll(samples);
  }
}

void main() {
  test('chaves: só números e letras normalizados (sem o texto da letra), iguais para grafias parecidas', () {
    expect(TrackTimingService.albumKey('The Beatles', 'Beatles For Sale'), hasLength(24));
    expect(TrackTimingService.trackKey('No Reply'), TrackTimingService.trackKey('no reply'));
  });

  test('aprende neste aparelho: mediana das medições, descarta absurdas (faixa pulada)', () async {
    final t = TrackTimingService(store: MemoryTranslatorStore());
    expect(t.intervalMs('Band', 'Record', 'Song'), isNull);
    expect(await t.record(artist: 'Band', album: 'Record', title: 'Song', intervalMs: 183000, listedMs: 180000), isTrue);
    expect(await t.record(artist: 'Band', album: 'Record', title: 'Song', intervalMs: 184000, listedMs: 180000), isTrue);
    expect(await t.record(artist: 'Band', album: 'Record', title: 'Song', intervalMs: 360000, listedMs: 180000), isFalse,
        reason: 'pulou uma faixa: longe demais da duração');
    expect(await t.record(artist: 'Band', album: 'Record', title: 'Other', intervalMs: 215000, listedMs: 180000), isTrue,
        reason: 'minutagem do catálogo errada (outra edição): a medição do áudio vale');
    expect(await t.record(artist: 'Band', album: 'Record', title: 'Song', intervalMs: 182500, listedMs: 180000), isTrue);
    expect(t.intervalMs('Band', 'Record', 'Song'), 183000);
  });

  test('faixas emendadas: intervalo menor que a duração vale (sem sulco)', () async {
    final t = TrackTimingService(store: MemoryTranslatorStore());
    expect(await t.record(artist: 'B', album: 'Sgt', title: 'Intro', intervalMs: 118000, listedMs: 122000), isTrue);
    expect(t.intervalMs('B', 'Sgt', 'Intro'), 118000);
  });

  test('banco coletivo: baixa o disco uma vez, soma às medições daqui e envia as novas', () async {
    final remote = _FakeRemote();
    final t = TrackTimingService(store: MemoryTranslatorStore(), remote: remote);
    final a = TrackTimingService.albumKey('Lush', 'Spooky');
    remote.data[a] = {TrackTimingService.trackKey('Stray'): 221000};
    await t.prepareAlbum('Lush', 'Spooky');
    await t.prepareAlbum('Lush', 'Spooky');
    expect(remote.fetches, 1);
    expect(t.intervalMs('Lush', 'Spooky', 'Stray'), 221000, reason: 'sem medição local, vale a coletiva');
    await t.record(artist: 'Lush', album: 'Spooky', title: 'Stray', intervalMs: 222000, listedMs: 219000);
    await Future<void>.delayed(Duration.zero);
    expect(remote.sent.single.intervalMs, 222000);
    expect(remote.sent.single.toJson().keys, isNot(contains('lyrics')), reason: 'só números, título e disco');
  });

  test('sem internet: as medições ficam guardadas e vão depois', () async {
    final remote = _FakeRemote()..offline = true;
    final store = MemoryTranslatorStore();
    final t = TrackTimingService(store: store, remote: remote);
    await t.record(artist: 'B', album: 'R', title: 'S', intervalMs: 200000);
    await Future<void>.delayed(Duration.zero);
    expect(remote.sent, isEmpty);
    final again = TrackTimingService(store: store, remote: remote..offline = false);
    await again.load();
    await again.flush();
    expect(remote.sent.single.title, 'S');
    expect(again.intervalMs('B', 'R', 'S'), 200000, reason: 'a medição local também fica guardada');
  });
}
