import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'ai_translator.dart' show TranslatorStore, FileTranslatorStore;
import 'tracklist_matcher.dart';

/// Medição de uma faixa para o banco de intervalos: o tempo de início a início até a faixa seguinte do mesmo
/// lado (inclui o silêncio do sulco, ou nada, nas faixas emendadas), na rotação nominal do disco.
class TimingSample {
  final String albumKey;
  final String trackKey;
  final String artist;
  final String album;
  final String title;
  final int intervalMs;
  const TimingSample({
    required this.albumKey,
    required this.trackKey,
    required this.artist,
    required this.album,
    required this.title,
    required this.intervalMs,
  });

  Map<String, dynamic> toJson() => {
        'album': albumKey,
        'track': trackKey,
        'artist': artist,
        'albumName': album,
        'title': title,
        'intervalMs': intervalMs,
      };

  factory TimingSample.fromJson(Map<String, dynamic> j) => TimingSample(
        albumKey: '${j['album']}',
        trackKey: '${j['track']}',
        artist: '${j['artist'] ?? ''}',
        album: '${j['albumName'] ?? ''}',
        title: '${j['title'] ?? ''}',
        intervalMs: (j['intervalMs'] as num).toInt(),
      );
}

/// Banco coletivo no servidor (conta WaxClub): intervalos já medidos por todos e envio das medições novas.
abstract class TrackTimingRemote {
  /// Intervalos do disco (trackKey → ms, mediana de todos), ou vazio.
  Future<Map<String, int>> fetch(String albumKey);
  Future<void> submit(List<TimingSample> samples);
}

/// Banco coletivo pela conta WaxClub (`/v1/timings`).
class AccountTrackTimingRemote implements TrackTimingRemote {
  final Future<Map<String, int>> Function(String albumKey) _fetch;
  final Future<void> Function(List<Map<String, dynamic>> samples) _submit;
  AccountTrackTimingRemote({
    required Future<Map<String, int>> Function(String albumKey) fetch,
    required Future<void> Function(List<Map<String, dynamic>> samples) submit,
  })  : _fetch = fetch,
        _submit = submit;

  @override
  Future<Map<String, int>> fetch(String albumKey) => _fetch(albumKey);

  @override
  Future<void> submit(List<TimingSample> samples) => _submit([for (final s in samples) s.toJson()]);
}

/// Banco de intervalos entre faixas (plugin de sincronia, sem letras: só números). Aprende com as faixas
/// reconhecidas em sequência neste aparelho e com o banco coletivo do servidor; diz quando a próxima faixa
/// começa, para a letra dela entrar na hora certa sem esperar o microfone ouvir.
class TrackTimingService {
  final TranslatorStore _store;
  TrackTimingRemote? remote;

  TrackTimingService({TranslatorStore? store, this.remote}) : _store = store ?? FileTranslatorStore();

  static const _file = 'waxclub_track_timing.json';
  static const int maxLocalSamples = 7;

  /// Medições deste aparelho (album|track → últimas medições em ms).
  final Map<String, List<int>> _local = {};

  /// Banco coletivo já baixado (album → track → ms).
  final Map<String, Map<String, int>> _shared = {};
  final Set<String> _fetched = {};
  final List<TimingSample> _outbox = [];
  Future<void>? _loading;

  static String _norm(String s) => TracklistMatcher.normalize(s).trim();

  /// Chave do disco (artista + álbum normalizados).
  static String albumKey(String artist, String album) =>
      sha1.convert(utf8.encode('${_norm(artist)}|${_norm(album)}')).toString().substring(0, 24);

  /// Chave da faixa (título normalizado).
  static String trackKey(String title) => sha1.convert(utf8.encode(_norm(title))).toString().substring(0, 16);

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await _store.read(_file);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      (j['local'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
        _local[k] = [for (final x in v as List<dynamic>) (x as num).toInt()];
      });
      for (final s in (j['outbox'] as List<dynamic>? ?? const [])) {
        _outbox.add(TimingSample.fromJson(s as Map<String, dynamic>));
      }
    } catch (e) {
      debugPrint('[TrackTiming] Arquivo ilegível, recomeçando: $e');
    }
  }

  Future<void> _save() => _store.write(
        _file,
        jsonEncode({
          'local': _local,
          'outbox': [for (final s in _outbox) s.toJson()],
        }),
      );

  /// Baixa o banco coletivo do disco (uma vez por sessão) e envia as medições pendentes.
  Future<void> prepareAlbum(String artist, String album) async {
    await load();
    final r = remote;
    if (r == null || artist.trim().isEmpty || album.trim().isEmpty) return;
    final key = albumKey(artist, album);
    if (_fetched.add(key)) {
      try {
        _shared[key] = await r.fetch(key);
      } catch (e) {
        _fetched.remove(key); // tenta de novo na próxima vez
        debugPrint('[TrackTiming] Banco coletivo indisponível: $e');
      }
    }
    unawaited(flush());
  }

  /// Envia as medições guardadas (sem internet ou sem conta, ficam para depois).
  Future<void> flush() async {
    final r = remote;
    if (r == null || _outbox.isEmpty) return;
    final batch = List.of(_outbox);
    try {
      await r.submit(batch);
      _outbox.removeWhere(batch.contains);
      await _save();
    } catch (e) {
      debugPrint('[TrackTiming] Envio adiado: $e');
    }
  }

  /// Intervalo de início a início da faixa [title] até a seguinte (ms, rotação nominal), ou nulo se não houver
  /// medição. Mediana das medições deste aparelho junto com o valor coletivo (que conta como uma medição).
  int? intervalMs(String artist, String album, String title) {
    final a = albumKey(artist, album);
    final t = trackKey(title);
    final values = [...?_local['$a|$t'], if (_shared[a]?[t] case final int shared) shared];
    if (values.isEmpty) return null;
    values.sort();
    return values[values.length ~/ 2];
  }

  /// Guarda uma medição. A medição vem do áudio (início real de duas faixas seguidas), não da minutagem do
  /// catálogo, que pode estar errada ou ser de outra edição; [listedMs] só descarta o grosseiro (faixa pulada,
  /// agulha levantada): menos da metade da duração listada ou mais de 60 s além dela.
  Future<bool> record({
    required String artist,
    required String album,
    required String title,
    required int intervalMs,
    int? listedMs,
  }) async {
    await load();
    if (artist.trim().isEmpty || album.trim().isEmpty || title.trim().isEmpty) return false;
    if (intervalMs < 20000 || intervalMs > 30 * 60000) return false;
    if (listedMs != null && listedMs > 0 && (intervalMs < listedMs ~/ 2 || intervalMs > listedMs + 60000)) {
      debugPrint('[TrackTiming] Medição descartada para "$title": ${intervalMs}ms (catálogo ${listedMs}ms)');
      return false;
    }
    final a = albumKey(artist, album);
    final t = trackKey(title);
    final list = _local.putIfAbsent('$a|$t', () => []);
    list.add(intervalMs);
    while (list.length > maxLocalSamples) {
      list.removeAt(0);
    }
    _outbox.add(TimingSample(albumKey: a, trackKey: t, artist: artist, album: album, title: title, intervalMs: intervalMs));
    while (_outbox.length > 200) {
      _outbox.removeAt(0);
    }
    debugPrint('[TrackTiming] "$title": ${(intervalMs / 1000).toStringAsFixed(1)} s até a próxima faixa');
    await _save();
    unawaited(flush());
    return true;
  }
}
