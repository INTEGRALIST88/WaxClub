import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/services/ai_translator.dart' show MemoryTranslatorStore;
import 'package:waxclub/services/mic_busy_service.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/track_timing_service.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';

class _Mic extends MicBusyService {
  final bool playing;
  const _Mic(this.playing);
  @override
  Future<MicStatus?> check() async => MicStatus(silenced: false, recordings: 1, phonePlaying: playing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('waxclub_timing_src_'));
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  const lp = [
    TrackEntry(position: 1, title: 'One', number: 'A1', side: 'A', lengthMs: 200000),
    TrackEntry(position: 2, title: 'Two', number: 'A2', side: 'A', lengthMs: 200000),
  ];

  Future<(WaxClubEngine, TrackTimingService)> make(bool phonePlaying) async {
    final cache = VinylCacheService(storageDirectory: dir);
    await cache.init();
    final timing = TrackTimingService(store: MemoryTranslatorStore());
    final engine = WaxClubEngine(
      cacheService: cache,
      logService: SessionLogService(storageDirectory: dir),
      micBusyService: _Mic(phonePlaying),
    )..trackTiming = timing;
    await engine.prepareScannedRecord(albumTitle: 'Rec', artist: 'Band', tracklist: lp, source: 'discogs');
    return (engine, timing);
  }

  final t0 = DateTime(2026, 1, 1, 20);
  final t1 = t0.add(const Duration(seconds: 203));

  test('disco: o intervalo entre duas faixas seguidas vai para o banco', () async {
    final (engine, timing) = await make(false);
    await engine.recordIntervalForTest('One', t0, 'Two', t1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(timing.intervalMs('Band', 'Rec', 'One'), closeTo(203000, 2500));
    engine.dispose();
  });

  test('o próprio celular tocando música (Spotify, YouTube Music): não grava', () async {
    final (engine, timing) = await make(true);
    await engine.recordIntervalForTest('One', t0, 'Two', t1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(timing.intervalMs('Band', 'Rec', 'One'), isNull);
    engine.dispose();
  });

  test('rotação perfeita demais em 4 faixas seguidas (cara de digital): não grava', () async {
    final (engine, timing) = await make(false);
    for (final s in [1.0001, 0.9999, 1.0000, 1.0001]) {
      engine.addTrackSpeedForTest(s);
    }
    expect(engine.looksDigital, isTrue);
    await engine.recordIntervalForTest('One', t0, 'Two', t1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(timing.intervalMs('Band', 'Rec', 'One'), isNull);
    engine.dispose();
  });

  test('toca-discos de verdade oscila: não é confundido com digital', () async {
    final (engine, _) = await make(false);
    for (final s in [1.0021, 1.0008, 1.0034, 1.0015]) {
      engine.addTrackSpeedForTest(s);
    }
    expect(engine.looksDigital, isFalse);
    engine.dispose();
  });
}
