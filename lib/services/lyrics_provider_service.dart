import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'artist_names.dart';
import 'local_lyrics_library.dart';
import 'lrclib_service.dart';

/// Provedor orquestrador em cascata de letras para o WaxClub.
///
/// Ordem de prioridade:
/// 1. LRCLIB (fonte primária, metadados limpos e estáveis)
/// 2. NetEase Cloud Music (enorme catálogo com letras LRC sincronizadas, excelente para faixas nacionais/internacionais)
/// 3. Megalobiz (arquivo colaborativo de letras sincronizadas)
/// 4. Kugou e QQ Music (Tencent Music, China): LRC sincronizado, instalados pelo site
///
/// Só vale letra **com tempo** (LRC sincronizado): texto simples conta como não encontrado (luz vermelha).
class LyricsProviderService {
  final http.Client _client;
  final LrcLibService _lrcLibService;

  LyricsProviderService({LrcLibService? lrcLibService, http.Client? client})
      : _client = client ?? http.Client(),
        _lrcLibService = lrcLibService ?? LrcLibService(client: client);

  LrcLibService get lrcLibService => _lrcLibService;

  /// Fontes de letras ligadas: cada site é um plugin da categoria Lyrics sources ('lrclib', 'netease',
  /// 'megalobiz', 'kugou', 'qqmusic'). O app consulta os plugins instalados e ligados; sem o app configurar,
  /// todas valem (testes).
  static bool Function(String source) sourceEnabled = _allSources;
  static bool _allSources(String _) => true;

  /// Ordem das fontes de letras (a do painel de plugins, da esquerda para a direita); sem o app
  /// configurar, as letras do usuário primeiro e depois LRCLIB, NetEase, Megalobiz, Kugou e QQ Music.
  static List<String> Function() sourceOrder = _defaultOrder;
  static List<String> _defaultOrder() => const ['local', 'lrclib', 'netease', 'megalobiz', 'kugou', 'qqmusic'];

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
    LrcResponse? judge(String engine, LrcResponse? r) {
      final text = r?.syncedLyrics;
      if (text == null || text.trim().isEmpty) {
        lastAttempts[engine] = LyricsAttempt.notFound;
        return null;
      }
      if (!LyricsQuality.hasTimestamps(text)) {
        debugPrint('[LyricsCascade] 🚫 "$engine" só tem texto sem tempo: conta como não encontrada.');
        lastAttempts[engine] = LyricsAttempt.notFound;
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

    // A busca segue estritamente a ordem do painel (da esquerda para a direita): cada fonte é avaliada na
    // posição dela — com letra sincronizada exibível, ela é a escolhida; sem letra, só com texto sem tempo
    // (não serve: nada de ritmo estimado) ou com letra quebrada, fica vermelha e a próxima é consultada.
    final order = [for (final e in sourceOrder()) if (sourceEnabled(e)) e];

    // A fonte que achou a letra da última vez só pula a fila se for também a primeira do painel
    final preferred = preferredSource?.toLowerCase();
    if (preferred != null && order.isNotEmpty && order.first == preferred) {
      debugPrint('[LyricsCascade] 🎯 Fonte preferida "$preferred" é a primeira do painel.');
    }

    for (final engine in order) {
      if (engine == 'local') {
        final mine = judge('local', fromMyLyrics(trackName, artistName, albumName: albumName));
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
          debugPrint('[LyricsCascade] ✅ Letra de "$engine".');
          return ok;
        }
      } catch (e) {
        lastAttempts[engine] = LyricsAttempt.notFound;
        debugPrint('[LyricsCascade] ⚠️ Falha em "$engine": $e');
      }
    }

    // Nada com o nome reconhecido: tenta os outros nomes do artista ("The London Suede" → "Suede",
    // "Bob Marley & The Wailers" → "Bob Marley"...), nas mesmas fontes e na mesma ordem
    for (final alt in ArtistNames.variants(artistName)) {
      for (final engine in order) {
        if (engine == 'local') continue;
        try {
          debugPrint('[LyricsCascade] 🔁 Outro nome do artista: "$engine" para "$trackName" - "$alt"...');
          final r = await _trySource(
            engine,
            trackName: trackName,
            artistName: alt,
            albumName: albumName,
            durationSeconds: durationSeconds,
          );
          final ok = judge(engine, r);
          if (ok != null) {
            debugPrint('[LyricsCascade] ✅ Letra de "$engine" com o nome "$alt".');
            return ok;
          }
        } catch (e) {
          debugPrint('[LyricsCascade] ⚠️ Falha em "$engine" ("$alt"): $e');
        }
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
        case 'kugou':
          return await _fetchFromKugou(trackName: trackName, artistName: artistName, durationSeconds: durationSeconds);
        case 'qqmusic':
          return await _fetchFromQqMusic(trackName: trackName, artistName: artistName, durationSeconds: durationSeconds);
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

  /// Kugou (酷狗音乐, Guangzhou, China — Tencent Music): busca a letra pelo "Artista - Música" e baixa o
  /// LRC sincronizado (vem em base64). Só aceita o candidato do mesmo artista e da mesma música.
  Future<LrcResponse?> _fetchFromKugou({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async {
    try {
      final cleanTrack = _cleanSearchTerm(trackName);
      final cleanArtist = _cleanSearchTerm(artistName);
      final searchUri = Uri.https('krcs.kugou.com', '/search', {
        'ver': '1',
        'man': 'yes',
        'client': 'mobi',
        'keyword': '$cleanArtist - $cleanTrack',
        'duration': durationSeconds == null ? '' : '${durationSeconds * 1000}',
        'hash': '',
      });
      final searchRes = await _client.get(searchUri).timeout(const Duration(seconds: 6));
      if (searchRes.statusCode != 200) return null;
      final candidates = (jsonDecode(searchRes.body) as Map<String, dynamic>)['candidates'] as List<dynamic>? ?? const [];
      for (final c in candidates.take(5)) {
        final m = c as Map<String, dynamic>;
        if (!_sameArtist(m['singer'] as String?, cleanArtist) || !_sameSong(m['song'] as String?, cleanTrack)) continue;
        final id = m['id']?.toString();
        final key = m['accesskey'] as String?;
        if (id == null || key == null) continue;
        final dlUri = Uri.https('krcs.kugou.com', '/download', {
          'ver': '1',
          'client': 'pc',
          'id': id,
          'accesskey': key,
          'fmt': 'lrc',
          'charset': 'utf8',
        });
        final dlRes = await _client.get(dlUri).timeout(const Duration(seconds: 6));
        if (dlRes.statusCode != 200) continue;
        final content = (jsonDecode(dlRes.body) as Map<String, dynamic>)['content'] as String?;
        if (content == null || content.isEmpty) continue;
        final lrc = utf8.decode(base64Decode(content), allowMalformed: true);
        if (!_hasValidTimestamps(lrc)) continue;
        // A duração vem em segundos ou em milissegundos, conforme o candidato
        final raw = (m['duration'] as num?)?.toDouble();
        final duration = raw == null ? null : (raw > 10000 ? raw / 1000.0 : raw);
        return LrcResponse(syncedLyrics: lrc, durationSeconds: duration, source: 'kugou');
      }
      return null;
    } catch (e) {
      debugPrint('[LyricsCascade:Kugou] Erro: $e');
      return null;
    }
  }

  /// QQ Music (QQ音乐, Shenzhen, China — Tencent Music): procura a música e baixa o LRC sincronizado. Entre
  /// os resultados do mesmo artista e da mesma música, prefere a versão de estúdio com a duração mais perto.
  Future<LrcResponse?> _fetchFromQqMusic({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async {
    try {
      final cleanTrack = _cleanSearchTerm(trackName);
      final cleanArtist = _cleanSearchTerm(artistName);
      final searchUri = Uri.https('c.y.qq.com', '/soso/fcgi-bin/client_search_cp', {
        'w': '$cleanArtist $cleanTrack',
        'format': 'json',
        'n': '8',
      });
      final searchRes = await _client.get(searchUri).timeout(const Duration(seconds: 6));
      if (searchRes.statusCode != 200) return null;
      final data = (jsonDecode(searchRes.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
      final list = (data?['song'] as Map<String, dynamic>?)?['list'] as List<dynamic>? ?? const [];
      final variant = RegExp(r'\b(live|remix|ao vivo)\b', caseSensitive: false);
      final wantsVariant = variant.hasMatch(trackName);
      final matches = <Map<String, dynamic>>[];
      for (final s in list) {
        final m = s as Map<String, dynamic>;
        final singers = (m['singer'] as List<dynamic>? ?? const []).map((x) => (x as Map<String, dynamic>)['name'] as String?);
        if (!singers.any((n) => _sameArtist(n, cleanArtist))) continue;
        final name = m['songname'] as String?;
        if (!_sameSong(name, cleanTrack)) continue;
        if (!wantsVariant && variant.hasMatch(name ?? '')) continue;
        matches.add(m);
      }
      final d = durationSeconds;
      if (d != null) {
        num gap(Map<String, dynamic> m) => ((m['interval'] as num? ?? 0) - d).abs();
        matches.sort((a, b) => gap(a).compareTo(gap(b)));
      }
      for (final m in matches.take(3)) {
        final mid = m['songmid'] as String?;
        if (mid == null) continue;
        final lyricUri = Uri.https('c.y.qq.com', '/lyric/fcgi-bin/fcg_query_lyric_new.fcg', {'songmid': mid, 'format': 'json'});
        final lyricRes = await _client.get(lyricUri, headers: {'Referer': 'https://y.qq.com/'}).timeout(const Duration(seconds: 6));
        if (lyricRes.statusCode != 200) continue;
        final b64 = (jsonDecode(lyricRes.body) as Map<String, dynamic>)['lyric'] as String?;
        if (b64 == null || b64.isEmpty) continue;
        final lrc = utf8.decode(base64Decode(b64), allowMalformed: true);
        if (!_hasValidTimestamps(lrc)) continue;
        return LrcResponse(
          syncedLyrics: lrc,
          durationSeconds: (m['interval'] as num?)?.toDouble(),
          albumName: m['albumname'] as String?,
          source: 'qqmusic',
        );
      }
      return null;
    } catch (e) {
      debugPrint('[LyricsCascade:QQMusic] Erro: $e');
      return null;
    }
  }

  /// Só letras e números, sem acento e em minúsculas, para comparar nomes vindos de fontes diferentes.
  static String _key(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString().replaceAll(RegExp(r'^the\s+'), '').replaceAll(RegExp(r'[^a-z0-9぀-鿿]'), '');
  }

  static bool _sameArtist(String? found, String wanted) {
    if (found == null) return false;
    final a = _key(found), b = _key(wanted);
    return a.isNotEmpty && b.isNotEmpty && (a.contains(b) || b.contains(a));
  }

  static bool _sameSong(String? found, String wanted) {
    if (found == null) return false;
    final a = _key(_cleanSearchTerm(found).replaceAll(RegExp(r'\(.*?\)|（.*?）'), ''));
    final b = _key(wanted.replaceAll(RegExp(r'\(.*?\)'), ''));
    return a.isNotEmpty && b.isNotEmpty && (a == b || a.startsWith(b) || b.startsWith(a));
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

  static bool hasTimestamps(String text) => RegExp(r'\[\d{1,3}:\d{2}').hasMatch(text);

  /// Letra que dá para mostrar:
  /// sincronizada, com pelo menos 3 linhas com texto e o tempo compatível com a música (a última linha não
  /// passa muito do fim nem acaba antes de um quarto da música). Texto simples (sem tempo) não serve.
  static bool usable(String text, {double? durationSeconds}) {
    final lines = text.split(RegExp(r'\r?\n'));
    final times = <double>[];
    var timedText = 0;
    for (final raw in lines) {
      final m = _timed.firstMatch(raw);
      if (m != null) {
        final t = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!) + (m.group(3) == null ? 0 : double.parse('0.${m.group(3)}'));
        times.add(t.toDouble());
        if (m.group(4)!.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim().isNotEmpty) timedText++;
        continue;
      }
    }
    if (times.isEmpty) return false;
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
