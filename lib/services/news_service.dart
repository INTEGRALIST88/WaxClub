import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'tracklist_matcher.dart';

/// Uma notícia sobre o artista (manchete, veículo e data), sempre em inglês.
class NewsItem {
  final String title;
  final String publisher;
  final DateTime? date;
  final String? link;
  const NewsItem({required this.title, required this.publisher, this.date, this.link});
}

/// Notícias recentes (últimos 30 dias) sobre o artista, em inglês, pelo RSS público do Google News
/// (grátis, sem chave). A tradução virá por um plugin de IA do site oficial.
class NewsService {
  static const String _userAgent = 'WaxClub/1.0 (vinyl lyrics app; contact@waxclub.app)';
  static const Duration cacheFor = Duration(hours: 12);

  final http.Client _client;
  final Map<String, (DateTime, List<NewsItem>)> _cache = {};

  NewsService({http.Client? client}) : _client = client ?? http.Client();

  /// Até [max] manchetes que citam o artista; vazio sem rede.
  Future<List<NewsItem>> forArtist(String artist, {int max = 2}) async {
    final a = artist.trim();
    if (a.isEmpty) return const [];
    final key = TracklistMatcher.normalize(a);
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < cacheFor) return cached.$2.take(max).toList();
    try {
      final uri = Uri.https('news.google.com', '/rss/search', {
        'q': '"$a" when:30d',
        'hl': 'en-US',
        'gl': 'US',
        'ceid': 'US:en',
      });
      final res = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      final items = parseRss(res.body, artist: a);
      _cache[key] = (DateTime.now(), items);
      return items.take(max).toList();
    } catch (e) {
      debugPrint('[News] Notícias indisponíveis: $e');
      return const [];
    }
  }

  /// Lê o RSS do Google News: só manchetes que citam o artista, sem o " - Veículo" do fim do título.
  static List<NewsItem> parseRss(String xml, {required String artist}) {
    final out = <NewsItem>[];
    final a = TracklistMatcher.normalize(artist);
    for (final m in RegExp(r'<item>([\s\S]*?)</item>').allMatches(xml)) {
      final item = m.group(1)!;
      String? tag(String name) {
        final t = RegExp('<$name[^>]*>([\\s\\S]*?)</$name>').firstMatch(item)?.group(1);
        return t == null ? null : _decode(t.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '').trim());
      }

      var title = tag('title') ?? '';
      final publisher = tag('source') ?? '';
      if (publisher.isNotEmpty && title.endsWith(' - $publisher')) {
        title = title.substring(0, title.length - publisher.length - 3).trim();
      }
      if (title.isEmpty || (a.isNotEmpty && !TracklistMatcher.normalize(title).contains(a))) continue;
      out.add(NewsItem(title: title, publisher: publisher, date: _parseDate(tag('pubDate')), link: tag('link')));
    }
    return out;
  }

  static String _decode(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  static const _months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };

  /// "Mon, 21 Sep 2026 07:00:00 GMT" → DateTime (UTC).
  static DateTime? _parseDate(String? s) {
    if (s == null) return null;
    final m = RegExp(r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2})').firstMatch(s);
    if (m == null) return null;
    final month = _months[m.group(2)];
    if (month == null) return null;
    return DateTime.utc(int.parse(m.group(3)!), month, int.parse(m.group(1)!), int.parse(m.group(4)!), int.parse(m.group(5)!));
  }

  void dispose() => _client.close();
}
