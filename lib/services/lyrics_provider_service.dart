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
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async {
    // ════════ Letras do próprio usuário (plugin S5): sempre primeiro ════════
    final mine = fromMyLyrics(trackName, artistName, albumName: albumName);
    if (mine != null) return mine;

    // ════════ 0. Fonte Preferida (se especificada) ════════
    // 'lyrics.ovh' (texto plano, sem timestamps) nunca passa na validação de LRC sincronizado:
    // não é tentada antecipadamente nem excluída da cascata, ficando como último recurso.
    // Texto simples do LRCLIB (casado por artista/título): último recurso, antes do Lyrics.ovh
    LrcResponse? lrclibPlain;

    final triedSource = (preferredSource != null &&
            preferredSource.isNotEmpty &&
            preferredSource.toLowerCase() != 'lyrics.ovh' &&
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
      if (pref != null && (pref.syncedLyrics != null && _hasValidTimestamps(pref.syncedLyrics!))) {
        debugPrint('[LyricsCascade] ✅ Sucesso na fonte preferida "$preferredSource".');
        return pref;
      }
      if (triedSource == 'lrclib') lrclibPlain = pref;
    }

    // ════════ 1. LRCLIB (Primário) ════════
    if (triedSource != 'lrclib' && sourceEnabled('lrclib')) {
      try {
        debugPrint('[LyricsCascade] 🔍 [1/4] Consultando LRCLIB para "$trackName" - "$artistName"...');
        final lrclibResponse = await _lrcLibService.fetchLyricsDetails(
          trackName: trackName,
          artistName: artistName,
          albumName: albumName,
          durationSeconds: durationSeconds,
        );

        if (lrclibResponse?.syncedLyrics != null &&
            _hasValidTimestamps(lrclibResponse!.syncedLyrics!)) {
          debugPrint('[LyricsCascade] ✅ [1/4] Sucesso na LRCLIB (LRC sincronizado encontrado).');
          return lrclibResponse;
        }
        lrclibPlain ??= lrclibResponse;
      } catch (e) {
        debugPrint('[LyricsCascade] ⚠️ [1/4] Falha no LRCLIB: $e');
      }
    }

    // ════════ 2. NetEase Cloud Music (Secundário) ════════
    if (triedSource != 'netease' && sourceEnabled('netease')) {
      try {
        debugPrint('[LyricsCascade] 🔍 [2/4] Consultando NetEase Cloud Music...');
        final netEaseResponse = await _fetchFromNetEase(
          trackName: trackName,
          artistName: artistName,
        );

        if (netEaseResponse?.syncedLyrics != null &&
            _hasValidTimestamps(netEaseResponse!.syncedLyrics!)) {
          debugPrint('[LyricsCascade] ✅ [2/4] Sucesso no NetEase (LRC sincronizado encontrado).');
          return netEaseResponse;
        }
      } catch (e) {
        debugPrint('[LyricsCascade] ⚠️ [2/4] Falha no NetEase: $e');
      }
    }

    // ════════ 3. Megalobiz (Terciário) ════════
    if (triedSource != 'megalobiz' && sourceEnabled('megalobiz')) {
      try {
        debugPrint('[LyricsCascade] 🔍 [3/4] Consultando Megalobiz...');
        final megalobizResponse = await _fetchFromMegalobiz(
          trackName: trackName,
          artistName: artistName,
        );

        if (megalobizResponse?.syncedLyrics != null &&
            _hasValidTimestamps(megalobizResponse!.syncedLyrics!)) {
          debugPrint('[LyricsCascade] ✅ [3/4] Sucesso no Megalobiz (LRC sincronizado encontrado).');
          return megalobizResponse;
        }
      } catch (e) {
        debugPrint('[LyricsCascade] ⚠️ [3/4] Falha no Megalobiz: $e');
      }
    }

    // ════════ 4a. Texto simples do LRCLIB (ritmo estimado) ════════
    final plainFromLrclib = lrclibPlain?.plainLyrics;
    if (plainFromLrclib != null && plainFromLrclib.trim().isNotEmpty) {
      debugPrint('[LyricsCascade] ℹ️ Sem LRC sincronizado em nenhuma fonte. Usando texto simples da LRCLIB com ritmo estimado.');
      return LrcResponse(
        syncedLyrics: plainFromLrclib.trim(),
        durationSeconds: lrclibPlain!.durationSeconds ?? durationSeconds?.toDouble(),
        albumName: lrclibPlain.albumName ?? albumName,
        source: 'lrclib',
      );
    }

    // ════════ 4b. Fallback de Letra em Texto Plano (Lyrics.ovh) ════════
    if (sourceEnabled('lyrics.ovh')) {
      try {
        debugPrint('[LyricsCascade] 🔍 [4/4] Consultando fallback de texto simples (Lyrics.ovh)...');
        final plainLyrics = await _fetchFromLyricsOvh(
          trackName: trackName,
          artistName: artistName,
        );

        if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
          debugPrint('[LyricsCascade] ℹ️ [4/4] Letra em texto encontrada no Lyrics.ovh. Convertendo para ritmo estimado.');
          return LrcResponse(
            syncedLyrics: plainLyrics,
            durationSeconds: durationSeconds?.toDouble(),
            albumName: albumName,
            source: 'lyrics.ovh',
          );
        }
      } catch (e) {
        debugPrint('[LyricsCascade] ⚠️ [4/4] Falha no Lyrics.ovh: $e');
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
