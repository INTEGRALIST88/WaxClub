import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/shazam_service.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';

class _FakeRecord extends AudioRecordService {
  @override
  Future<Uint8List?> recordSample({
    Duration duration = const Duration(milliseconds: 5000),
    int sampleRate = 16000,
    RecordPriority priority = RecordPriority.user,
  }) async =>
      Uint8List.fromList(List.filled(100, 1));

  @override
  Future<void> cancelRecording() async {}
}

/// Reconhece [answer] (ou nada, com nulo) e conta as consultas.
class _SwitchShazam extends ShazamService {
  TrackInfo? answer;
  int calls = 0;
  _SwitchShazam(this.answer);

  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async {
    calls++;
    return answer;
  }
}

class _FakeLyrics extends LyricsProviderService {
  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async =>
      const LrcResponse(
        syncedLyrics: '[00:10.00] dez\n[00:20.00] vinte\n[00:30.00] trinta\n[00:40.00] quarenta\n[00:50.00] cinquenta',
        durationSeconds: 240,
        source: 'lrclib',
      );
}

const _dois = TrackInfo(title: 'Faixa Dois', artist: 'Banda', album: 'Disco Teste', offsetSeconds: 30);

final _lp = [
  const TrackEntry(position: 1, title: 'Faixa Um', number: 'A1', side: 'A', lengthMs: 200000),
  const TrackEntry(position: 2, title: 'Faixa Dois', number: 'A2', side: 'A', lengthMs: 240000),
  const TrackEntry(position: 3, title: 'Faixa Três', number: 'B1', side: 'B', lengthMs: 180000),
];

Future<void> _waitFor(bool Function() cond, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('condição não alcançada em $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('waxclub_switch_test_'));
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  Future<WaxClubEngine> engineWith(_SwitchShazam shazam) async {
    final cache = VinylCacheService(storageDirectory: dir);
    await cache.init();
    final e = WaxClubEngine(
      recordService: _FakeRecord(),
      shazamService: shazam,
      lyricsService: _FakeLyrics(),
      cacheService: cache,
      logService: SessionLogService(storageDirectory: dir),
    );
    await e.prepareScannedRecord(albumTitle: 'Disco Teste', artist: 'Banda', tracklist: _lp, source: 'discogs');
    return e;
  }

  test('automático → Manual no meio da música: mesma sessão, a faixa continua de onde está', () async {
    final shazam = _SwitchShazam(_dois);
    final engine = await engineWith(shazam);
    await engine.startListening();
    expect(engine.currentTrack?.title, 'Faixa Dois');
    final calls = shazam.calls;

    engine.setManualMode(true);
    expect(engine.isManualPlaying, isTrue, reason: 'não pede ▶ de novo');
    expect(engine.manualTrackIndex, 1);
    expect(engine.currentTrack?.title, 'Faixa Dois');
    await Future<void>.delayed(const Duration(milliseconds: 600)); // a telemetria da posição é atualizada 2x/s
    expect(engine.telemetry.currentPositionSeconds, closeTo(30, 1.5));
    expect(engine.telemetry.trackDurationSeconds, closeTo(240, 0.01), reason: 'minutagem do LP');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(shazam.calls, calls, reason: 'o Manual não consulta o Shazam');
    engine.stopManual();
    engine.dispose();
  });

  test('Manual → automático no meio da música: escuta já e sincroniza pelo reconhecimento', () async {
    final shazam = _SwitchShazam(_dois);
    final engine = await engineWith(shazam);
    engine.setManualMode(true);
    expect(await engine.startManualPlayback(trackIndex: 1, useMic: false), isTrue);

    engine.setManualMode(false);
    await _waitFor(() => !engine.isManualPlaying && engine.lyrics.isNotEmpty && engine.telemetry.currentPositionSeconds > 25);
    expect(engine.isManualMode, isFalse);
    expect(engine.currentTrack?.title, 'Faixa Dois');
    expect(engine.isAlbumLocked, isTrue, reason: 'mesma sessão: o disco continua travado');
    engine.stop();
    engine.dispose();
  });

  test('Manual → automático sem reconhecer: o Manual segue sem parar nada', () async {
    final shazam = _SwitchShazam(null);
    final engine = await engineWith(shazam);
    engine.setManualMode(true);
    expect(await engine.startManualPlayback(trackIndex: 0, useMic: false), isTrue);

    engine.setManualMode(false);
    await _waitFor(() => shazam.calls > 0 && engine.isManualMode);
    expect(engine.isManualPlaying, isTrue);
    expect(engine.currentTrack?.title, 'Faixa Um');
    expect(engine.telemetry.statusMessage, contains('Manual mode keeps going'));
    engine.stopManual();
    engine.dispose();
  });

  test('automático: tocar na linha cantada só desloca a letra (posição, rotação e minutagem intactas)', () async {
    final engine = await engineWith(_SwitchShazam(_dois));
    await engine.startListening();
    final speed = engine.telemetry.speedFactor;
    final duration = engine.telemetry.trackDurationSeconds;
    await Future<void>.delayed(const Duration(milliseconds: 600)); // a telemetria da posição é atualizada 2x/s
    final before = engine.telemetry.currentPositionSeconds;
    expect(before, closeTo(30, 1.5));

    // A música está nos ~30 s, mas a letra baixada diz que "quarenta" é o que se canta agora
    engine.syncToLine(40.0);
    expect(engine.lyricBiasSeconds, closeTo(40 - before, 1.0));
    expect(engine.lyrics[engine.activeLineIndex].text, 'quarenta');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(engine.telemetry.currentPositionSeconds, closeTo(before + 0.6, 0.5), reason: 'a posição da música não muda');
    expect(engine.telemetry.speedFactor, speed);
    expect(engine.telemetry.trackDurationSeconds, duration);
    engine.stop();
    engine.dispose();
  });
}
