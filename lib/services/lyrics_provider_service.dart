import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'local_lyrics_library.dart';
import 'lrclib_service.dart';

/// Provedor orquestrador em cascata de letras para o WaxClub.
///
/// Ordem de prioridade:
/// 1. LRCLIB (fonte primária, metadados limpos e estáveis)
/// 2. NetEase Cloud Music (enorme catálogo com letras LRC sincronizadas, excelente para faixas nacionais/internacionais)
/// 3. Megalobiz (arquivo colaborativo de letras sincronizadas)
/// 4. Fallback de texto plano (Lyrics.ovh ou LRCLIB plain) formatado para exibição sincronizada estimada
class LyricsProviderService {
  final http.Client _client;
  final LrcLibService _lrcLibService;

  LyricsProviderService({LrcLibService? lrcLibService, http.Client? client})
      : _client = client ?? http.Client(),
        _lrcLibService = lrcLibService ?? LrcLibService(client: client);

  LrcLibService get lrcLibService => _lrcLibService;

  /// Fontes de letras ligadas: cada site é um plugin da categoria Lyrics sources ('lrclib', 'netease',
  /// 'megalobiz', 'lyrics.ovh'). O app consulta os plugins instalados e ligados; sem o app configurar,
  /// todas valem (testes).
  static bool Function(String source) sourceEnabled = _allSources;
  static bool _allSources(String _) => true;

  /// Ordem das fontes de letras (a do painel de plugins, da esquerda para a direita); sem o app
  /// configurar, as letras do usuário primeiro e depois LRCLIB, NetEase, Megalobiz e Lyrics.ovh.
  static List<String> Function() sourceOrder = _defaultOrder;
  static List<String> _defaultOrder() => const ['local', 'lrclib', 'netease', 'megalobiz', 'lyrics.ovh'];

  /// As letras do próprio usuário vêm antes das guardadas (cache) e da web: o S5 está ligado e é a
  /// primeira fonte ligada no painel.
  static bool myLyricsFirst() {
    for (final e in sourceOrder()) {
      if (!sourceEnabled(e)) continue;
      return e == 'local';
    }
    return false;
  }

  /// Plugin S5 "My lyrics files": letras do próprio usuário no celular (engine 'local').
  static LocalLyricsLibrary? myLyrics;

  /// Letra que o próprio usuário importou para esta música (com o plugin S5 ligado).
  static LrcResponse? fromMyLyrics(String trackName, String artistName, {String? albumName}) {
    final lib = myLyrics;
    if (lib == null || !sourceEnabled('local')) return null;
    final e = lib.find(trackName, artistName);
    if (e == null) return null;
    return LrcResponse(
      syncedLyrics: e.lyrics,
      durationSeconds: e.durationSeconds,
      albumName: e.album ?? albumName,
      source: 'local',
    );
  }

  /// Busca letras e metadados percorrendo a cascata de provedores.
  /// Se [preferredSource] for informado, tenta essa fonte primeiro.
  /// Retorna assim que encontrar uma letra com timestamps sincronizados.
  /// O que cada fonte achou na última busca ([fetchLyricsDetails]): o painel acende a luz vermelha das que
  /// não encontraram ou trouxeram letra quebrada. Fontes que nem foram consultadas não aparecem.
  final Map<String, LyricsAttempt> lastAttempts = {};

  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async {
    lastAttempts.clear();
    final duration = durationSeconds?.toDouble();

    /// Avalia a resposta de uma fonte: boa (usa), quebrada (vermelho) ou vazia (vermelho).
    LrcResponse? judge(String engine, LrcResponse? r, {bool allowPlain = false}) {
      final text = r?.syncedLyrics;
      if (text == null || text.trim().isEmpty) {
        lastAttempts[engine] = LyricsAttempt.notFound;
        return null;
      }
      final timed = LyricsQuality.hasTimestamps(text);
      if (!timed && !allowPlain) {
        lastAttempts[engine] = LyricsAttempt.notFound; // só texto simples: fica para o fim
        return null;
      }
      if (!LyricsQuality.usable(text, durationSeconds: r?.durationSeconds ?? duration)) {
        debugPrint('[LyricsCascade] 🚫 "$engine" trouxe letra quebrada ou fora do tempo da música: descartada.');
        lastAttempts[engine] = LyricsAttempt.broken;
        return null;
      }
      lastAttempts[engine] = LyricsAttempt.found;
      return r;
    }

    // ════════ 0. Fonte Preferida (se especificada) ════════
    // 'lyrics.ovh' (texto plano, sem timestamps) não é tentada antecipadamente: fica como último recurso.
    // Texto simples do LRCLIB (casado por artista/título): último recurso, antes do Lyrics.ovh
    LrcResponse? lrclibPlain;

    final triedSource = (preferredSource != null &&
            preferredSource.isNotEmpty &&
            preferredSource.toLowerCase() != 'lyrics.ovh' &&
            preferredSource.toLowerCase() != 'local' &&
            sourceEnabled(preferredSource.toLowerCase()))
        ? preferredSource.toLowerCase()
        : null;
    if (triedSource != null) {
      debugPrint('[LyricsCascade] 🎯 Tentando fonte preferida: "$preferredSource"...');
      final pref = await _trySource(
        triedSource,
        trackName: trackName,
        artistName: artistName,
        albumName: albumName,
        durationSeconds: durationSeconds,
      );
      final ok = judge(triedSource, pref);
      if (ok != null) {
        debugPrint('[LyricsCascade] ✅ Sucesso na fonte preferida "$preferredSource".');
        return ok;
      }
      if (triedSource == 'lrclib') lrclibPlain = pref;
    }

    // ════════ 1. Fontes ligadas, na ordem do painel (da esquerda para a direita) ════════
    // As letras do próprio usuário (S5) e as sincronizadas da web; o texto simples fica para o fim.
    for (final engine in sourceOrder()) {
      if (engine == triedSource || engine == 'lyrics.ovh' || !sourceEnabled(engine)) continue;
      if (engine == 'local') {
        final mine = judge('local', fromMyLyrics(trackName, artistName, albumName: albumName), allowPlain: true);
        if (mine != null) return mine;
        continue;
      }
      try {
        debugPrint('[LyricsCascade] 🔍 Consultando "$engine" para "$trackName" - "$artistName"...');
        final r = await _trySource(
          engine,
          trackName: trackName,
          artistName: artistName,
          albumName: albumName,
          durationSeconds: durationSeconds,
        );
        final ok = judge(engine, r);
        if (ok != null) {
          debugPrint('[LyricsCascade] ✅ Sucesso em "$engine" (LRC sincronizado encontrado).');
          return ok;
        }
        if (engine == 'lrclib') lrclibPlain ??= r;
      } catch (e) {
        lastAttempts[engine] = LyricsAttempt.notFound;
        debugPrint('[LyricsCascade] ⚠️ Falha em "$engine": $e');
      }
    }

    // ════════ 4a. Texto simples do LRCLIB (ritmo estimado) ════════
    final plainFromLrclib = lrclibPlain?.plainLyrics;
    if (plainFromLrclib != null && plainFromLrclib.trim().isNotEmpty) {
      final ok = judge(
        'lrclib',
        LrcResponse(
          syncedLyrics: plainFromLrclib.trim(),
          durationSeconds: lrclibPlain!.durationSeconds ?? duration,
          albumName: lrclibPlain.albumName ?? albumName,
          source: 'lrclib',
        ),
        allowPlain: true,
      );
      if (ok != null) {
        debugPrint('[LyricsCascade] ℹ️ Sem LRC sincronizado em nenhuma fonte. Usando texto simples da LRCLIB com ritmo estimado.');
        return ok;
      }
    }

    // ════════ 4b. Fallback de Letra em Texto Plano (Lyrics.ovh) ════════
    if (sourceEnabled('lyrics.ovh')) {
      try {
        debugPrint('[LyricsCascade] 🔍 Consultando fallback de texto simples (Lyrics.ovh)...');
        final plainLyrics = await _fetchFromLyricsOvh(
          trackName: trackName,
          artistName: artistName,
        );
        final ok = judge(
          'lyrics.ovh',
          plainLyrics == null
              ? null
              : LrcResponse(syncedLyrics: plainLyrics, durationSeconds: duration, albumName: albumName, source: 'lyrics.ovh'),
          allowPlain: true,
        );
        if (ok != null) {
          debugPrint('[LyricsCascade] ℹ️ Letra em texto encontrada no Lyrics.ovh. Convertendo para ritmo estimado.');
          return ok;
        }
      } catch (e) {
        lastAttempts['lyrics.ovh'] = LyricsAttempt.notFound;
        debugPrint('[LyricsCascade] ⚠️ Falha no Lyrics.ovh: $e');
      }
    }

    debugPrint('[LyricsCascade] ❌ Nenhuma letra encontrada em nenhuma das fontes.');
    return null;
  }

  /// Tenta uma fonte específica pelo seu identificador.
  Future<LrcResponse?> _trySource(
    String sourceName, {
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    try {
      switch (sourceName.toLowerCase()) {
        case 'lrclib':
          return await _lrcLibService.fetchLyricsDetails(
            trackName: trackName,
            artistName: artistName,
            albumName: albumName,
            durationSeconds: durationSeconds,
          );
        case 'netease':
          return await _fetchFromNetEase(trackName: trackName, artistName: artistName);
        case 'megalobiz':
          return await _fetchFromMegalobiz(trackName: trackName, artistName: artistName);
        case 'lyrics.ovh':
          final plain = await _fetchFromLyricsOvh(trackName: trackName, artistName: artistName);
          if (plain != null && plain.trim().isNotEmpty) {
            return LrcResponse(
              syncedLyrics: plain,
              durationSeconds: durationSeconds?.toDouble(),
              albumName: albumName,
              source: 'lyrics.ovh',
            );
          }
          return null;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Busca letras sincronizadas na cascata.
  Future<String?> fetchSyncedLyrics({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    final details = await fetchLyricsDetails(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      durationSeconds: durationSeconds,
    );
    return details?.syncedLyrics;
  }

  /// Verifica se a string contém pelo menos um timestamp padrão LRC ([mm:ss).
  static bool _hasValidTimestamps(String text) {
    return RegExp(r'\[\d{2}:\d{2}').hasMatch(text);
  }

  /// Busca no catálogo oficial da NetEase Cloud Music (163)
  Future<LrcResponse?> _fetchFromNetEase({
    required String trackName,
    required String artistName,
  }) async {
    try {
      final cleanTrack = _cleanSearchTerm(trackName);
      final cleanArtist = _cleanSearchTerm(artistName);
      final query = '$cleanArtist $cleanTrack'.trim();

      // Busca na API da NetEase
      // HTTPS obrigatório: o Android 9+ bloqueia tráfego em texto claro (cleartext) por padrão
      final searchUri = Uri.parse('https://music.163.com/api/search/get');
      final searchRes = await _client.post(
        searchUri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://music.163.com',
          'Cookie': 'appver=2.0.2',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        body: 's=${Uri.encodeQueryComponent(query)}&type=1&limit=3',
      ).timeout(const Duration(seconds: 6));

      if (searchRes.statusCode != 200) return null;

      final searchJson = jsonDecode(searchRes.body) as Map<String, dynamic>;
      final songs = searchJson['result']?['songs'] as List<dynamic>?;
      if (songs == null || songs.isEmpty) return null;

      final firstSong = songs[0] as Map<String, dynamic>;
      final songId = firstSong['id'];
      if (songId == null) return null;

      final double? duration = (firstSong['duration'] as num?) != null
          ? (firstSong['duration'] as num).toDouble() / 1000.0
          : null;
      final String? album = firstSong['album']?['name'] as String?;

      // Busca o arquivo LRC pelo ID da música
      final lyricUri = Uri.parse(
        'https://music.163.com/api/song/lyric?os=pc&id=$songId&lv=-1&kv=-1&tv=-1',
      );
      final lyricRes = await _client.get(
        lyricUri,
        headers: {
          'Referer': 'https://music.163.com',
          'Cookie': 'appver=2.0.2',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
      ).timeout(const Duration(seconds: 6));

      if (lyricRes.statusCode != 200) return null;

      final lyricJson = jsonDecode(lyricRes.body) as Map<String, dynamic>;
      final lrcString = lyricJson['lrc']?['lyric'] as String?;

      if (lrcString != null && _hasValidTimestamps(lrcString)) {
        return LrcResponse(
          syncedLyrics: lrcString,
          durationSeconds: duration,
          albumName: album,
          source: 'netease',
        );
      }
      return null;
    } catch (e) {
      debugPrint('[LyricsCascade:NetEase] Erro: $e');
      return null;
    }
  }

  /// Consulta o arquivo Megalobiz
  Future<LrcResponse?> _fetchFromMegalobiz({
    required String trackName,
    required String artistName,
  }) async {
    try {
      final cleanTrack = _cleanSearchTerm(trackName);
      final cleanArtist = _cleanSearchTerm(artistName);
      final query = Uri.encodeQueryComponent('$cleanArtist $cleanTrack'.trim());

      final searchUri = Uri.parse('https://www.megalobiz.com/search/all?qry=$query');
      final searchRes = await _client.get(
        searchUri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 4));

      if (searchRes.statusCode != 200) return null;

      // Extrai o primeiro link de lrc
      final match = RegExp(r'href="(/lrc/maker/[^"]+)"').firstMatch(searchRes.body);
      if (match == null) return null;

      final lrcPageUrl = 'https://www.megalobiz.com${match.group(1)}';
      final lrcRes = await _client.get(
        Uri.parse(lrcPageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 4));

      if (lrcRes.statusCode != 200) return null;

      final lrcTextMatch = RegExp(r'<span id="lrc_[\w]+_details">([\s\S]*?)</span>').firstMatch(lrcRes.body);
      if (lrcTextMatch != null) {
        final rawLrc = lrcTextMatch.group(1) ?? '';
        final decodedLrc = rawLrc
            .replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&#39;', "'");
        if (_hasValidTimestamps(decodedLrc)) {
          return LrcResponse(
            syncedLyrics: decodedLrc,
            source: 'megalobiz',
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('[LyricsCascade:Megalobiz] Erro: $e');
      return null;
    }
  }

  /// Consulta Lyrics.ovh para letras simples
  Future<String?> _fetchFromLyricsOvh({
    required String trackName,
    required String artistName,
  }) async {
    try {
      final cleanTrack = _cleanSearchTerm(trackName);
      final cleanArtist = _cleanSearchTerm(artistName);
      final uri = Uri.parse(
        'https://api.lyrics.ovh/v1/${Uri.encodeComponent(cleanArtist)}/${Uri.encodeComponent(cleanTrack)}',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final lyrics = data['lyrics'] as String?;
        if (lyrics != null && lyrics.trim().isNotEmpty) {
          return lyrics.trim();
        }
      }
      return null;
    } catch (e) {
      debugPrint('[LyricsCascade:LyricsOvh] Erro: $e');
      return null;
    }
  }

  static String _cleanSearchTerm(String text) {
    return text
        .replaceAll(RegExp(r'\(.*?(remaster|live|version|edit|mono|stereo|ao vivo).*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r' - .*?Remaster.*?', caseSensitive: false), '')
        .trim();
  }

  void dispose() {
    _client.close();
    _lrcLibService.dispose();
  }
}

/// Resultado de uma fonte de letras para a música atual (a luz da caixinha no painel).
enum LyricsAttempt {
  /// Trouxe a letra que está sendo usada (ou uma boa, se outra fonte veio antes).
  found,

  /// Não tinha a letra (luz vermelha).
  notFound,

  /// Tinha, mas quebrada: poucas linhas, sem tempo ou com o tempo incompatível com a música (luz vermelha).
  broken,
}

/// Regras para considerar uma letra exibível.
class LyricsQuality {
  static final RegExp _timed = RegExp(r'^\s*\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\](.*)$');
  static final RegExp _tag = RegExp(r'^\s*\[[a-zA-Z#]+:.*\]\s*$');

  static bool hasTimestamps(String text) => RegExp(r'\[\d{1,3}:\d{2}').hasMatch(text);

  /// Letra que dá para mostrar:
  /// * sincronizada: pelo menos 3 linhas com texto, e o tempo compatível com a música (a última linha não
  ///   passa muito do fim nem acaba antes de um quarto da música);
  /// * texto simples (sem tempo): pelo menos 4 linhas.
  static bool usable(String text, {double? durationSeconds}) {
    final lines = text.split(RegExp(r'\r?\n'));
    final times = <double>[];
    var timedText = 0;
    var plain = 0;
    for (final raw in lines) {
      final m = _timed.firstMatch(raw);
      if (m != null) {
        final t = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!) + (m.group(3) == null ? 0 : double.parse('0.${m.group(3)}'));
        times.add(t.toDouble());
        if (m.group(4)!.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim().isNotEmpty) timedText++;
        continue;
      }
      if (_tag.hasMatch(raw)) continue;
      if (raw.trim().isNotEmpty) plain++;
    }
    if (times.isEmpty) return plain >= 4;
    if (timedText < 3) return false;
    final d = durationSeconds;
    if (d != null && d > 30) {
      final last = times.reduce((a, b) => a > b ? a : b);
      if (last > d * 1.2 + 15) return false; // a letra continua muito depois do fim da música
      if (last < d * 0.25) return false; // acaba antes de um quarto da música
    }
    return true;
  }
}
