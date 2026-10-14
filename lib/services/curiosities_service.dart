import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'news_service.dart';
import 'tracklist_matcher.dart';

/// Uma curiosidade curta, sempre com a fonte.
class Curiosity {
  final String text;
  final String source; // "Wikipedia", ou o veículo da notícia
  final String? url;

  /// Data (notícias).
  final DateTime? date;
  const Curiosity(this.text, this.source, {this.url, this.date});

  Map<String, dynamic> toJson() => {'text': text, 'source': source, if (url != null) 'url': url};
  factory Curiosity.fromJson(Map<String, dynamic> j) =>
      Curiosity(j['text'] as String, j['source'] as String? ?? 'Wikipedia', url: j['url'] as String?);
}

/// Curiosidades do disco e de uma faixa, para exibir quando não há letra.
class RecordCuriosities {
  final List<Curiosity> album;
  final List<Curiosity> track;

  /// Notícias recentes sobre o artista (em inglês), com veículo e data.
  final List<Curiosity> news;
  const RecordCuriosities({this.album = const [], this.track = const [], this.news = const []});
  bool get isEmpty => album.isEmpty && track.isEmpty && news.isEmpty;
}

/// Banco compartilhado das curiosidades (API do WaxClub na Hostinger): procurado antes da web, e
/// recebe o que for achado na web. [record] = disco (artista|disco normalizado); [track] = faixa.
abstract class CuriositiesRemote {
  Future<List<Curiosity>?> fetch(String record, String lang, {String? track});
  Future<void> save(String record, String lang, List<Curiosity> items, {String? track, String? discogsReleaseId});
}

/// Busca curiosidades curtas sobre o disco e as faixas **no idioma em que o artista canta ou fala**
/// ([lang]): primeiro no banco compartilhado ([CuriositiesRemote]), depois na Wikipedia daquele idioma
/// (e na inglesa, se não houver nada) e nas notas do Discogs, escolhendo frases do próprio texto da fonte
/// (nada é inventado). O que vier da web vai para o banco; tudo fica também no aparelho (sem internet).
class CuriositiesService {
  static const String _userAgent = 'WaxClub/1.0 (vinyl lyrics app; contact@waxclub.app)';
  static const String _fileName = 'waxclub_curiosities.json';
  static const int maxAlbum = 5;
  static const int maxTrack = 2;

  final http.Client _client;
  final Directory? _directory;
  final NewsService _news;
  final Map<String, List<Curiosity>> _cache = {};
  bool _loaded = false;

  /// Banco compartilhado (nulo sem conta: só web e aparelho).
  CuriositiesRemote? remote;

  CuriositiesService({http.Client? client, Directory? directory, NewsService? news, this.remote})
      : _client = client ?? http.Client(),
        _directory = directory,
        _news = news ?? NewsService(client: client);

  /// Chave do disco no banco compartilhado.
  static String recordKey(String artist, String album) => TracklistMatcher.key(artist, album);

  static String _albumKey(String artist, String album, String lang) => 'album|$lang|${TracklistMatcher.key(artist, album)}';
  static String _trackKey(String artist, String track, String lang) => 'track|$lang|${TracklistMatcher.key(artist, track)}';

  /// Idiomas a tentar: o do artista e, como reserva, o inglês.
  static List<String> _langs(String lang) => lang == 'en' ? const ['en'] : [lang, 'en'];

  /// Curiosidades só do disco (popup de My Collection), no idioma [lang].
  Future<List<Curiosity>> albumFacts({
    required String artist,
    required String album,
    String lang = 'en',
    String? discogsNotes,
    String? discogsReleaseId,
  }) async {
    await _load();
    return _albumFacts(artist, album, discogsNotes, lang, discogsReleaseId);
  }

  /// Curiosidades do disco [album] e da faixa [track]. [discogsNotes]: notas da prensagem, se houver.
  Future<RecordCuriosities> forTrack({
    required String artist,
    required String album,
    required String track,
    String? discogsNotes,
    String lang = 'en',
  }) async {
    await _load();
    final a = await _albumFacts(artist, album, discogsNotes, lang, null);
    final t = await _trackFacts(artist, album, track, lang);
    final n = await _news.forArtist(artist);
    return RecordCuriosities(
      album: a,
      track: t,
      news: [for (final x in n) Curiosity(x.title, x.publisher, url: x.link, date: x.date)],
    );
  }

  Future<List<Curiosity>> _albumFacts(String artist, String album, String? notes, String lang, String? releaseId) async {
    final key = _albumKey(artist, album, lang);
    final cached = _cache[key];
    if (cached != null) return cached;
    final record = recordKey(artist, album);
    var facts = <Curiosity>[];
    for (final l in _langs(lang)) {
      // 1) banco compartilhado
      final shared = await _fetchRemote(record, l);
      if (shared != null && shared.isNotEmpty) {
        facts = shared;
        break;
      }
      // 2) Wikipedia daquele idioma
      try {
        final query = l == 'en' ? '$album $artist album' : '$album $artist';
        final title = await _findArticle(l, query, album, artist);
        if (title != null) {
          final text = await _plainText(l, title);
          if (text != null) {
            facts = pickFacts(text, max: maxAlbum).map((x) => Curiosity(x, 'Wikipedia', url: _url(l, title))).toList();
          }
        }
      } catch (e) {
        debugPrint('[Curiosities] Wikipedia ($l) indisponível para o disco: $e');
      }
      if (notes != null && notes.trim().isNotEmpty && facts.length < maxAlbum && facts.isNotEmpty) {
        facts.addAll(pickFacts(_stripDiscogsMarkup(notes), max: maxAlbum - facts.length).map((x) => Curiosity(x, 'Discogs')));
      }
      if (facts.isNotEmpty) {
        unawaited(_saveRemote(record, l, facts, releaseId: releaseId));
        break;
      }
    }
    // Sem nada na Wikipedia: só as notas da prensagem
    if (facts.isEmpty && notes != null && notes.trim().isNotEmpty) {
      facts = pickFacts(_stripDiscogsMarkup(notes), max: maxAlbum).map((x) => Curiosity(x, 'Discogs')).toList();
    }
    _cache[key] = facts;
    await _save();
    return facts;
  }

  Future<List<Curiosity>> _trackFacts(String artist, String album, String track, String lang) async {
    final key = _trackKey(artist, track, lang);
    final cached = _cache[key];
    if (cached != null) return cached;
    final record = recordKey(artist, album);
    final trackKey = TracklistMatcher.normalize(track);
    var facts = <Curiosity>[];
    for (final l in _langs(lang)) {
      final shared = await _fetchRemote(record, l, track: trackKey);
      if (shared != null && shared.isNotEmpty) {
        facts = shared;
        break;
      }
      try {
        final query = l == 'en' ? '$track $artist song' : '$track $artist';
        final title = await _findArticle(l, query, track, artist);
        if (title != null) {
          final text = await _plainText(l, title, introOnly: true);
          if (text != null) {
            facts = pickFacts(text, max: maxTrack).map((x) => Curiosity(x, 'Wikipedia', url: _url(l, title))).toList();
          }
        }
      } catch (e) {
        debugPrint('[Curiosities] Wikipedia ($l) indisponível para a faixa: $e');
      }
      if (facts.isNotEmpty) {
        unawaited(_saveRemote(record, l, facts, track: trackKey));
        break;
      }
    }
    _cache[key] = facts;
    await _save();
    return facts;
  }

  Future<List<Curiosity>?> _fetchRemote(String record, String lang, {String? track}) async {
    final r = remote;
    if (r == null) return null;
    try {
      return await r.fetch(record, lang, track: track).timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[Curiosities] Banco compartilhado indisponível: $e');
      return null;
    }
  }

  Future<void> _saveRemote(String record, String lang, List<Curiosity> items, {String? track, String? releaseId}) async {
    final r = remote;
    if (r == null) return;
    try {
      await r.save(record, lang, items, track: track, discogsReleaseId: releaseId);
    } catch (e) {
      debugPrint('[Curiosities] Falha ao gravar no banco compartilhado: $e');
    }
  }

  /// Escolhe frases curtas e informativas do texto, na ordem em que aparecem. A primeira frase
  /// (a definição: "X is the fifth studio album by Y, released in 1977") entra quase sempre.
  static List<String> pickFacts(String text, {int max = 5}) {
    final clean = text
        .replaceAll(RegExp(r'\n=+[^=\n]+=+\n?'), '\n') // títulos de seção
        .replaceAll(RegExp(r'\[\d+\]'), '') // marcas de referência
        .replaceAll(RegExp(r'\s*\([^()]*(?:pronounced|listen|born)[^()]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final sentences = clean
        .split(RegExp(r'(?<=[.!?。])\s*(?=[\p{Lu}"“«¿¡\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}])', unicode: true))
        .map((s) => s.trim())
        .where((s) => s.length >= 25 && s.length <= 240 && !s.contains('may refer to'))
        .toList();
    if (sentences.isEmpty) return const [];
    const keywords = [
      'recorded', 'released', 'produced', 'producer', 'written', 'wrote', 'studio', 'chart', 'number one',
      'number', 'million', 'sold', 'certified', 'award', 'grammy', 'single', 'debut', 'cover', 'inspired',
      'tour', 'lyrics', 'session', 'engineer', 'billboard', 'gold', 'platinum', 'rolling stone', 'ranked',
      // pt / es / it
      'gravad', 'lançad', 'lanzad', 'grabad', 'produzid', 'producid', 'compost', 'escrit', 'vendeu', 'vendió',
      'prêmio', 'premio', 'disco de ouro', 'disco de oro', 'sucesso', 'éxito', 'paradas', 'registrat', 'pubblicat',
      // fr / de
      'enregistr', 'sorti', 'publié', 'succès', 'aufgenommen', 'veröffentlicht', 'erschien', 'erfolg', 'platz',
    ];
    int score(int i, String s) {
      final l = s.toLowerCase();
      var sc = i == 0 ? 6 : 0;
      for (final k in keywords) {
        if (l.contains(k)) sc += 2;
      }
      if (RegExp(r'\b(1[89]\d\d|20\d\d)\b').hasMatch(s)) sc += 2;
      if (RegExp(r'\d').hasMatch(s)) sc += 1;
      if (RegExp(r'^(It|This|These|They|He|She)\b').hasMatch(s) && i != 0) sc -= 1;
      return sc;
    }

    final ranked = [for (var i = 0; i < sentences.length && i < 40; i++) (i, score(i, sentences[i]))]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final chosen = ranked.where((r) => r.$2 > 0).take(max).map((r) => r.$1).toList()..sort();
    return [for (final i in chosen) sentences[i]];
  }

  static String _stripDiscogsMarkup(String s) => s
      .replaceAll(RegExp(r'\[(?:a|l|r|m|url)=?[^\]]*\]'), '')
      .replaceAll(RegExp(r'\[/?[a-z]+\]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String _url(String lang, String title) =>
      'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}';

  Future<String?> _findArticle(String lang, String query, String name, String artist) async {
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php',
        {'action': 'query', 'list': 'search', 'srsearch': query, 'srlimit': '5', 'format': 'json'});
    final res = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final hits = (jsonDecode(utf8.decode(res.bodyBytes))['query']?['search'] as List<dynamic>?) ?? const [];
    final target = TracklistMatcher.normalize(name);
    final a = TracklistMatcher.normalize(artist);
    for (final h in hits) {
      final t = (h is Map ? h['title'] : null) as String?;
      if (t == null) continue;
      final base = TracklistMatcher.normalize(t.replaceAll(RegExp(r'\s*\(.*\)\s*$'), ''));
      final snippet = TracklistMatcher.normalize('${h['snippet'] ?? ''}'.replaceAll(RegExp(r'<[^>]+>'), ''));
      // título igual e o artista citado no título "(X song)" ou no trecho do artigo
      if (base == target && (a.isEmpty || TracklistMatcher.normalize(t).contains(a) || snippet.contains(a))) {
        return t;
      }
    }
    return null;
  }

  Future<String?> _plainText(String lang, String title, {bool introOnly = false}) async {
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'prop': 'extracts',
      'explaintext': '1',
      if (introOnly) 'exintro': '1',
      'redirects': '1',
      'titles': title,
      'format': 'json',
      'formatversion': '2',
    });
    final res = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final pages = (jsonDecode(utf8.decode(res.bodyBytes))['query']?['pages'] as List<dynamic>?) ?? const [];
    if (pages.isEmpty) return null;
    final extract = pages.first['extract'] as String?;
    if (extract == null || extract.isEmpty) return null;
    return extract.length > 9000 ? extract.substring(0, 9000) : extract;
  }

  Future<File?> _file() async {
    try {
      final dir = _directory ?? await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}$_fileName');
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      j.forEach((k, v) => _cache[k] = [for (final c in v as List<dynamic>) Curiosity.fromJson(c as Map<String, dynamic>)]);
    } catch (e) {
      debugPrint('[Curiosities] Cache ilegível: $e');
    }
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      if (f == null) return;
      await f.writeAsString(jsonEncode(_cache.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList()))));
    } catch (e) {
      debugPrint('[Curiosities] Falha ao salvar: $e');
    }
  }

  void dispose() {
    _client.close();
    _news.dispose();
  }
}
