import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track_entry.dart';
import 'tracklist_matcher.dart';

/// Resultado da verificação no catálogo de reconhecimento.
class CatalogCheckResult {
  /// O disco está no catálogo (o modo automático deve reconhecer as faixas).
  final bool found;
  final int matchedTracks;
  final int totalTracks;
  const CatalogCheckResult({required this.found, this.matchedTracks = 0, this.totalTracks = 0});
}

/// Verifica se um disco está no catálogo de reconhecimento usado pelo app. Esse catálogo é, na prática,
/// o da Apple Music; a consulta usa a API pública e gratuita do iTunes (pelo código de barras ou por
/// artista + álbum) e confere faixa a faixa. Não é uma garantia: prensagens antigas podem ter versões
/// diferentes das digitais.
class RecognitionCatalogService {
  final http.Client _client;
  RecognitionCatalogService({http.Client? client}) : _client = client ?? http.Client();

  /// Nulo quando não foi possível consultar (sem rede): nesse caso o app segue no automático.
  Future<CatalogCheckResult?> check({
    String? barcode,
    required String artist,
    required String album,
    required List<TrackEntry> tracklist,
  }) async {
    try {
      List<String>? songs;
      final code = barcode?.replaceAll(RegExp(r'\D'), '');
      if (code != null && code.isNotEmpty) {
        songs = await _songs(Uri.https('itunes.apple.com', '/lookup', {'upc': code, 'entity': 'song'}));
      }
      if (songs == null || songs.isEmpty) {
        final id = await _findAlbumId(artist, album);
        if (id != null) {
          songs = await _songs(Uri.https('itunes.apple.com', '/lookup', {'id': '$id', 'entity': 'song'}));
        }
      }
      return evaluate(songs ?? const [], tracklist);
    } catch (e) {
      debugPrint('[RecognitionCatalog] Verificação indisponível: $e');
      return null;
    }
  }

  /// Compara as faixas do disco com as do catálogo: encontrado se pelo menos metade bater
  /// (ou, sem lista de faixas, se o álbum existir no catálogo).
  static CatalogCheckResult evaluate(List<String> catalogSongs, List<TrackEntry> tracklist) {
    if (catalogSongs.isEmpty) return CatalogCheckResult(found: false, totalTracks: tracklist.length);
    if (tracklist.isEmpty) return const CatalogCheckResult(found: true);
    final catalog = [for (var i = 0; i < catalogSongs.length; i++) TrackEntry(position: i + 1, title: catalogSongs[i])];
    var matched = 0;
    for (final t in tracklist) {
      if (TracklistMatcher.findIndex(catalog, t.title) != -1) matched++;
    }
    return CatalogCheckResult(found: matched * 2 >= tracklist.length, matchedTracks: matched, totalTracks: tracklist.length);
  }

  /// Álbum no catálogo: pela busca de texto e, se ela não achar (a busca do iTunes falha com alguns
  /// títulos, ex.: "Favourite Worst Nightmare"), pela discografia completa do artista.
  Future<int?> _findAlbumId(String artist, String album) async {
    final bySearch = await _results(Uri.https('itunes.apple.com', '/search', {'term': '$artist $album', 'entity': 'album', 'limit': '15'}));
    final found = _matchAlbum(bySearch, artist, album);
    if (found != null) return found;

    final artists = await _results(Uri.https('itunes.apple.com', '/search', {'term': artist, 'entity': 'musicArtist', 'limit': '5'}));
    for (final a in artists) {
      if (a is! Map || !TracklistMatcher.isSameArtist('${a['artistName'] ?? ''}', artist)) continue;
      final id = (a['artistId'] as num?)?.toInt();
      if (id == null) continue;
      final albums = await _results(Uri.https('itunes.apple.com', '/lookup', {'id': '$id', 'entity': 'album', 'limit': '200'}));
      final match = _matchAlbum(albums, artist, album);
      if (match != null) return match;
    }
    return null;
  }

  Future<List<dynamic>> _results(Uri uri) async {
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return const [];
    return (jsonDecode(utf8.decode(res.bodyBytes))['results'] as List<dynamic>?) ?? const [];
  }

  /// Mesmo artista e mesmo disco (aceita edições: "AM (Deluxe)", "Rumours (Remastered)").
  static int? _matchAlbum(List<dynamic> results, String artist, String album) {
    final target = TracklistMatcher.normalize(album);
    if (target.isEmpty) return null;
    for (final r in results) {
      if (r is! Map || r['wrapperType'] == 'artist') continue;
      final name = TracklistMatcher.normalize('${r['collectionName'] ?? ''}');
      if (name.isEmpty) continue;
      final artistOk = TracklistMatcher.isSameArtist('${r['artistName'] ?? ''}', artist);
      if (artistOk && (name == target || name.startsWith(target) || target.startsWith(name))) {
        return (r['collectionId'] as num?)?.toInt();
      }
    }
    return null;
  }

  Future<List<String>?> _songs(Uri uri) async {
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final results = (jsonDecode(utf8.decode(res.bodyBytes))['results'] as List<dynamic>?) ?? const [];
    return [
      for (final r in results)
        if (r is Map && r['wrapperType'] == 'track' && r['trackName'] is String) r['trackName'] as String,
    ];
  }

  void dispose() => _client.close();
}
