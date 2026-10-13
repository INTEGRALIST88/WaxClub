import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track_entry.dart';
import 'tracklist_matcher.dart';

/// Minutagem das faixas pelo artigo do álbum na Wikipedia (lista de faixas, que costuma trazer
/// os tempos do LP original). Usada para completar as durações que o Discogs/MusicBrainz não têm
/// e, quando o disco encontrado não é vinil, para substituí-las pelas do LP.
class WikipediaTracklistService {
  static const String _userAgent = 'WaxClub/1.0 (vinyl lyrics app; contact@waxclub.app)';
  static const List<String> _languages = ['en', 'pt'];

  final http.Client _client;
  final Map<String, List<TrackEntry>> _memo = {};

  WikipediaTracklistService({http.Client? client}) : _client = client ?? http.Client();

  /// Completa (ou, com [override], substitui) a duração das faixas pela Wikipedia.
  /// Nunca lança exceção: sem artigo ou sem rede, devolve [entries] como estão.
  Future<List<TrackEntry>> fillDurations(
    List<TrackEntry> entries, {
    required String artist,
    required String album,
    bool override = false,
  }) async {
    if (entries.isEmpty) return entries;
    final missing = entries.any((e) => e.lengthMs == null || e.lengthMs! <= 0);
    if (!missing && !override) return entries;

    final wiki = await fetchTracklist(artist: artist, album: album);
    return mergeDurations(entries, wiki, override: override);
  }

  /// Aplica as durações de [wiki] às faixas correspondentes de [entries].
  /// Para substituir durações já existentes, o artigo precisa casar com pelo menos metade das faixas
  /// (evita usar o artigo de outro disco com o mesmo nome).
  static List<TrackEntry> mergeDurations(List<TrackEntry> entries, List<TrackEntry> wiki, {bool override = false}) {
    if (wiki.isEmpty) return entries;
    final matches = <int, int>{};
    for (var i = 0; i < entries.length; i++) {
      final idx = TracklistMatcher.findIndex(wiki, entries[i].title);
      if (idx != -1 && (wiki[idx].lengthMs ?? 0) > 0) matches[i] = wiki[idx].lengthMs!;
    }
    final canOverride = override && matches.length * 2 >= entries.length;
    var changed = 0;
    final out = <TrackEntry>[
      for (var i = 0; i < entries.length; i++)
        if (matches.containsKey(i) && (canOverride || (entries[i].lengthMs ?? 0) <= 0))
          () {
            changed++;
            return entries[i].copyWith(lengthMs: matches[i]);
          }()
        else
          entries[i],
    ];
    if (changed > 0) debugPrint('[Wikipedia] ⏱️ Minutagem do LP aplicada em $changed de ${entries.length} faixas.');
    return out;
  }

  /// Lista de faixas (título + duração) do artigo do álbum; vazia se não achar.
  Future<List<TrackEntry>> fetchTracklist({required String artist, required String album}) async {
    final cleanArtist = cleanArtistName(artist);
    final key = TracklistMatcher.key(cleanArtist, album);
    final memo = _memo[key];
    if (memo != null) return memo;

    var result = const <TrackEntry>[];
    for (final lang in _languages) {
      try {
        final title = await _findArticle(lang, cleanArtist, album);
        if (title == null) continue;
        final wikitext = await _wikitext(lang, title);
        if (wikitext == null || !_mentionsArtist(wikitext, cleanArtist)) continue;
        final parsed = parseWikitext(wikitext);
        if (parsed.any((e) => (e.lengthMs ?? 0) > 0)) {
          debugPrint('[Wikipedia] 📖 "$title" ($lang): ${parsed.length} faixas.');
          result = parsed;
          break;
        }
      } catch (e) {
        debugPrint('[Wikipedia] Falha ao consultar ($lang): $e');
      }
    }
    _memo[key] = result;
    return result;
  }

  Future<String?> _findArticle(String lang, String artist, String album) async {
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': '$album $artist album',
      'srlimit': '5',
      'format': 'json',
    });
    final res = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final hits = (data['query']?['search'] as List<dynamic>?) ?? const [];
    final target = TracklistMatcher.normalize(album);
    for (final h in hits) {
      final t = (h is Map ? h['title'] : null) as String?;
      if (t == null) continue;
      // "Thriller (album)", "Abbey Road", "Rumours (álbum)"...
      final base = TracklistMatcher.normalize(t.replaceAll(RegExp(r'\s*\(.*\)\s*$'), ''));
      if (base == target) return t;
    }
    return null;
  }

  Future<String?> _wikitext(String lang, String title) async {
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'parse',
      'page': title,
      'prop': 'wikitext',
      'redirects': '1',
      'formatversion': '2',
      'format': 'json',
    });
    final res = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return data['parse']?['wikitext'] as String?;
  }

  static bool _mentionsArtist(String wikitext, String artist) {
    // Sem os colchetes dos links: o normalize descarta o que estiver entre colchetes
    final raw = (wikitext.length > 4000 ? wikitext.substring(0, 4000) : wikitext).replaceAll(RegExp(r'[\[\]]'), '');
    final head = TracklistMatcher.normalize(raw);
    final a = TracklistMatcher.normalize(artist);
    return a.isEmpty || head.contains(a);
  }

  /// Nome do artista sem os sufixos do Discogs ("Banda (2)", "Artista*").
  static String cleanArtistName(String artist) =>
      artist.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '').replaceAll('*', '').trim();

  /// Lê as faixas de um artigo: modelos {{Track listing}} / {{Lista de faixas}} e, sem eles,
  /// listas numeradas no formato `# "Título" – 3:45`.
  static List<TrackEntry> parseWikitext(String wikitext) {
    final out = <TrackEntry>[];
    final seen = <String>{};
    void add(String rawTitle, String? rawLength) {
      final title = cleanTitle(rawTitle);
      if (title.isEmpty) return;
      final norm = TracklistMatcher.normalize(title);
      if (!seen.add(norm)) return;
      out.add(TrackEntry(position: out.length + 1, title: title, lengthMs: parseLength(rawLength)));
    }

    final templates = RegExp(r'\{\{\s*(track listing|tracklist|lista de faixas)\s*\|', caseSensitive: false);
    for (final m in templates.allMatches(wikitext)) {
      final body = _templateBody(wikitext, m.start);
      if (body == null) continue;
      final params = <String, String>{};
      for (final part in _splitTopLevel(body)) {
        final eq = part.indexOf('=');
        if (eq <= 0) continue;
        params[part.substring(0, eq).trim().toLowerCase()] = part.substring(eq + 1).trim();
      }
      for (var n = 1; n <= 60; n++) {
        final title = params['title$n'] ?? params['título$n'] ?? params['titulo$n'];
        if (title == null) continue;
        add(title, params['length$n'] ?? params['duração$n'] ?? params['duracao$n'] ?? params['tempo$n']);
      }
    }

    if (out.isEmpty) {
      final line = RegExp(r'^#\s*(.+?)\s*[–—-]\s*(\d{1,2}:\d{2}(?::\d{2})?)\s*$', multiLine: true);
      for (final m in line.allMatches(wikitext)) {
        add(m.group(1)!, m.group(2));
      }
    }
    return out;
  }

  /// Duração "3:45" ou "1:02:30" em milissegundos.
  static int? parseLength(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(raw);
    if (m == null) return null;
    final a = int.parse(m.group(1)!), b = int.parse(m.group(2)!);
    final c = m.group(3) != null ? int.parse(m.group(3)!) : null;
    final seconds = c == null ? a * 60 + b : a * 3600 + b * 60 + c;
    return seconds > 0 ? seconds * 1000 : null;
  }

  /// Tira links, modelos, referências, aspas e formatação do wikitexto.
  static String cleanTitle(String raw) {
    var s = raw;
    s = s.replaceAll(RegExp(r'<ref[^>]*/>'), '');
    s = s.replaceAll(RegExp(r'<ref[^>]*>.*?</ref>', dotAll: true), '');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s.replaceAllMapped(RegExp(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]'), (m) => m.group(1)!);
    s = s.replaceAll(RegExp(r'\{\{[^{}]*\}\}'), '');
    s = s.replaceAll("'''", '').replaceAll("''", '');
    s = s.replaceAll(RegExp('^["“”]+|["“”]+\$'), '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _templateBody(String text, int start) {
    var depth = 0;
    for (var i = start; i < text.length - 1; i++) {
      if (text[i] == '{' && text[i + 1] == '{') {
        depth++;
        i++;
      } else if (text[i] == '}' && text[i + 1] == '}') {
        depth--;
        i++;
        if (depth == 0) return text.substring(start + 2, i - 1);
      }
    }
    return null;
  }

  static List<String> _splitTopLevel(String body) {
    final parts = <String>[];
    var depthT = 0, depthL = 0, last = 0;
    for (var i = 0; i < body.length; i++) {
      final two = i + 1 < body.length ? body.substring(i, i + 2) : '';
      if (two == '{{') {
        depthT++;
        i++;
      } else if (two == '}}') {
        depthT--;
        i++;
      } else if (two == '[[') {
        depthL++;
        i++;
      } else if (two == ']]') {
        depthL--;
        i++;
      } else if (body[i] == '|' && depthT == 0 && depthL == 0) {
        parts.add(body.substring(last, i));
        last = i + 1;
      }
    }
    parts.add(body.substring(last));
    return parts;
  }

  void dispose() => _client.close();
}
