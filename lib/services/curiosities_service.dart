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

/// Busca curiosidades curtas sobre o disco e as faixas (sempre em inglês) na Wikipedia e nas notas do
/// Discogs, escolhendo frases do próprio texto da fonte (nada é inventado; o resumo por IA virá como
/// plugin). Guarda no aparelho para funcionar sem internet; depois irá para a tabela compartilhada.
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

  CuriositiesService({http.Client? client, Directory? directory, NewsService? news})
      : _client = client ?? http.Client(),
        _directory = directory,
        _news = news ?? NewsService(client: client);

  static String _albumKey(String artist, String album) => 'album|${TracklistMatcher.key(artist, album)}';
  static String _trackKey(String artist, String track) => 'track|${TracklistMatcher.key(artist, track)}';

  /// Curiosidades do disco [album] e da faixa [track]. [discogsNotes]: notas da prensagem, se houver.
  Future<RecordCuriosities> forTrack({
    required String artist,
    required String album,
    required String track,
    String? discogsNotes,
  }) async {
    await _load();
    final a = await _albumFacts(artist, album, discogsNotes);
    final t = await _trackFacts(artist, track);
    final n = await _news.forArtist(artist);
    return RecordCuriosities(
      album: a,
      track: t,
      news: [for (final x in n) Curiosity(x.title, x.publisher, url: x.link, date: x.date)],
    );
  }

  Future<List<Curiosity>> _albumFacts(String artist, String album, String? notes) async {
    final key = _albumKey(artist, album);
    final cached = _cache[key];
    if (cached != null) return cached;
    final facts = <Curiosity>[];
    try {
      final title = await _findArticle('$album $artist album', album, artist);
      if (title != null) {
        final text = await _plainText(title);
        if (text != null) {
          facts.addAll(pickFacts(text, max: maxAlbum).map((s) => Curiosity(s, 'Wikipedia', url: _url(title))));
        }
      }
    } catch (e) {
      debugPrint('[Curiosities] Wikipedia indisponível para o disco: $e');
    }
    if (notes != null && notes.trim().isNotEmpty && facts.length < maxAlbum) {
      facts.addAll(pickFacts(_stripDiscogsMarkup(notes), max: maxAlbum - facts.length).map((s) => Curiosity(s, 'Discogs')));
    }
    _cache[key] = facts;
    await _save();
    return facts;
  }

  Future<List<Curiosity>> _trackFacts(String artist, String track) async {
    final key = _trackKey(artist, track);
    final cached = _cache[key];
    if (cached != null) return cached;
    var facts = <Curiosity>[];
    try {
      final title = await _findArticle('$track $artist song', track, artist);
      if (title != null) {
        final text = await _plainText(title, introOnly: true);
        if (text != null) facts = pickFacts(text, max: maxTrack).map((s) => Curiosity(s, 'Wikipedia', url: _url(title))).toList();
      }
    } catch (e) {
      debugPrint('[Curiosities] Wikipedia indisponível para a faixa: $e');
    }
    _cache[key] = facts;
    await _save();
    return facts;
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
        .split(RegExp(r'(?<=[.!?])\s+(?=[A-Z"“])'))
        .map((s) => s.trim())
        .where((s) => s.length >= 40 && s.length <= 220 && !s.contains('may refer to'))
        .toList();
    if (sentences.isEmpty) return const [];
    const keywords = [
      'recorded', 'released', 'produced', 'producer', 'written', 'wrote', 'studio', 'chart', 'number one',
      'number', 'million', 'sold', 'certified', 'award', 'grammy', 'single', 'debut', 'cover', 'inspired',
      'tour', 'lyrics', 'session', 'engineer', 'billboard', 'gold', 'platinum', 'rolling stone', 'ranked',
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

  static String _url(String title) => 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}';

  Future<String?> _findArticle(String query, String name, String artist) async {
    final uri = Uri.https('en.wikipedia.org', '/w/api.php',
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

  Future<String?> _plainText(String title, {bool introOnly = false}) async {
    final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
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
