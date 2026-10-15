import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../ai_translator.dart' show TranslatorStore, FileTranslatorStore;
import '../brain/brain_ai.dart';

/// Foto do Unsplash para uma cena (exibida pelo endereço do Unsplash, com crédito ao fotógrafo).
class ImaginePhoto {
  final String id;
  final String url; // urls.raw (o tamanho vai nos parâmetros)
  final String? color;
  final String author;
  final String? authorUrl;
  final String? photoUrl;
  final String? download; // links.download_location (avisar o uso)

  const ImaginePhoto({
    required this.id,
    required this.url,
    required this.author,
    this.color,
    this.authorUrl,
    this.photoUrl,
    this.download,
  });

  /// Endereço no tamanho usado pelo WaxClub (512 px de largura, WebP quando a TV aceita).
  String sized({int width = ImaginedMusic.imageWidth}) =>
      '$url${url.contains('?') ? '&' : '?'}w=$width&q=75&auto=format&fit=max';

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'author': author,
        if (color != null) 'color': color,
        if (authorUrl != null) 'authorUrl': authorUrl,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (download != null) 'download': download,
      };

  factory ImaginePhoto.fromJson(Map<String, dynamic> j) => ImaginePhoto(
        id: '${j['id']}',
        url: '${j['url']}',
        author: '${j['author'] ?? 'Unsplash'}',
        color: j['color'] as String?,
        authorUrl: j['authorUrl'] as String?,
        photoUrl: j['photoUrl'] as String?,
        download: j['download'] as String?,
      );
}

/// Uma cena do roteiro: começa na linha [line] da letra (ou em [atSeconds], música sem letra).
class ImagineScene {
  final int line;
  final double? atSeconds;
  final String query;
  final String mood;
  final List<String> palette; // cores #rrggbb
  final String motion; // zoom_in, zoom_out, pan_left, pan_right
  final String transition; // dissolve, cut
  final double intensity; // 0..1
  final ImaginePhoto? photo;

  const ImagineScene({
    required this.line,
    this.atSeconds,
    required this.query,
    this.mood = '',
    this.palette = const [],
    this.motion = 'zoom_in',
    this.transition = 'dissolve',
    this.intensity = 0.5,
    this.photo,
  });

  ImagineScene withPhoto(ImaginePhoto? p) => ImagineScene(
        line: line,
        atSeconds: atSeconds,
        query: query,
        mood: mood,
        palette: palette,
        motion: motion,
        transition: transition,
        intensity: intensity,
        photo: p,
      );

  Map<String, dynamic> toJson() => {
        'line': line,
        if (atSeconds != null) 'at': atSeconds,
        'query': query,
        'mood': mood,
        'palette': palette,
        'motion': motion,
        'transition': transition,
        'intensity': intensity,
        if (photo != null) 'photo': photo!.toJson(),
      };

  static const _motions = {'zoom_in', 'zoom_out', 'pan_left', 'pan_right'};
  static final _hex = RegExp(r'^#[0-9a-fA-F]{6}$');

  factory ImagineScene.fromJson(Map<String, dynamic> j) {
    final motion = '${j['motion'] ?? 'zoom_in'}';
    final intensity = (j['intensity'] is num) ? (j['intensity'] as num).toDouble() : 0.5;
    return ImagineScene(
      line: (j['line'] is num) ? (j['line'] as num).toInt() : 0,
      atSeconds: (j['at'] is num) ? (j['at'] as num).toDouble() : null,
      query: '${j['query'] ?? ''}'.trim(),
      mood: '${j['mood'] ?? ''}',
      palette: [
        for (final c in (j['palette'] as List<dynamic>? ?? const []))
          if (c is String && _hex.hasMatch(c)) c,
      ].take(4).toList(),
      motion: _motions.contains(motion) ? motion : 'zoom_in',
      transition: j['transition'] == 'cut' ? 'cut' : 'dissolve',
      intensity: intensity.clamp(0.0, 1.0),
      photo: j['photo'] is Map<String, dynamic> ? ImaginePhoto.fromJson(j['photo'] as Map<String, dynamic>) : null,
    );
  }
}

/// Frase de destaque da letra (modo imersivo): aparece e esmaece perto de quando é cantada.
class ImagineQuote {
  final int line;
  final String text;
  const ImagineQuote(this.line, this.text);
  Map<String, dynamic> toJson() => {'line': line, 'text': text};
}

/// Roteiro visual de uma música.
class Storyboard {
  final List<ImagineScene> scenes;
  final List<ImagineQuote> quotes;
  const Storyboard({required this.scenes, this.quotes = const []});

  bool get hasPhotos => scenes.any((s) => s.photo != null);

  Map<String, dynamic> toJson() => {
        'scenes': [for (final s in scenes) s.toJson()],
        'quotes': [for (final q in quotes) q.toJson()],
      };

  /// Lê a resposta do agente (aceita texto em volta); nulo se não houver cena válida. Cenas em ordem,
  /// a primeira começando na linha 0, linhas dentro da letra; frases curtas e só de linhas existentes.
  static Storyboard? parse(String reply, {required int lineCount}) {
    final start = reply.indexOf('{');
    final end = reply.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final j = jsonDecode(reply.substring(start, end + 1));
      if (j is! Map<String, dynamic>) return null;
      final scenes = <ImagineScene>[];
      for (final s in (j['scenes'] as List<dynamic>? ?? const [])) {
        if (s is! Map<String, dynamic>) continue;
        final scene = ImagineScene.fromJson(s);
        if (scene.query.isEmpty) continue;
        if (lineCount > 0 && (scene.line < 0 || scene.line >= lineCount)) continue;
        if (scenes.isNotEmpty && lineCount > 0 && scene.line <= scenes.last.line) continue;
        scenes.add(scene);
      }
      if (scenes.isEmpty) return null;
      if (lineCount > 0 && scenes.first.line != 0) {
        scenes[0] = ImagineScene.fromJson({...scenes.first.toJson(), 'line': 0});
      }
      final quotes = <ImagineQuote>[];
      for (final q in (j['quotes'] as List<dynamic>? ?? const [])) {
        if (q is! Map<String, dynamic>) continue;
        final line = (q['line'] is num) ? (q['line'] as num).toInt() : -1;
        final text = '${q['text'] ?? ''}'.trim();
        if (line < 0 || line >= lineCount || text.isEmpty || text.length > 90) continue;
        quotes.add(ImagineQuote(line, text));
      }
      return Storyboard(scenes: scenes, quotes: quotes);
    } catch (_) {
      return null;
    }
  }

  factory Storyboard.fromJson(Map<String, dynamic> j) => Storyboard(
        scenes: [
          for (final s in (j['scenes'] as List<dynamic>? ?? const []))
            if (s is Map<String, dynamic>) ImagineScene.fromJson(s),
        ],
        quotes: [
          for (final q in (j['quotes'] as List<dynamic>? ?? const []))
            if (q is Map<String, dynamic>) ImagineQuote((q['line'] as num).toInt(), '${q['text']}'),
        ],
      );
}

/// Busca de fotos no servidor do WaxClub (que consulta o Unsplash com a chave dele).
abstract class ImagineSearch {
  Future<List<ImaginePhoto>> search(String query);

  /// Avisa o Unsplash que a foto foi usada (exigência da API).
  Future<void> used(ImaginePhoto photo);
}

/// Modo de exibição na TV.
enum ImagineMode {
  /// Imagens atrás da letra corrida.
  lyrics,

  /// Só as imagens, com frases da letra de vez em quando (~30 s).
  immersive,
}

/// Plugin A3 "Imagined Music": um agente (chip do WaxBrain) lê a letra inteira e monta o roteiro visual da
/// música — cenas com uma busca de foto em inglês, paleta, movimento e transição, e frases de destaque para o
/// modo imersivo. As fotos vêm do Unsplash pela busca do servidor. O roteiro de cada música é feito uma vez e
/// guardado no celular (sem a letra: só as cenas e as frases escolhidas).
class ImaginedMusic extends ChangeNotifier {
  final BrainAi ai;
  final ImagineSearch? searcher;
  final TranslatorStore _store;

  ImaginedMusic({required this.ai, this.searcher, TranslatorStore? store}) : _store = store ?? FileTranslatorStore();

  /// Largura das imagens (decisão do usuário: 512 px).
  static const int imageWidth = 512;

  static const _settingsFile = 'waxclub_imagine.json';
  static const _cacheFile = 'waxclub_storyboards.json';
  static const int maxCached = 200;

  ImagineMode _mode = ImagineMode.lyrics;
  ImagineMode get mode => _mode;

  String? lastError;
  final Map<String, Storyboard> _cache = {};
  final List<String> _order = [];
  final Map<String, Future<Storyboard?>> _inFlight = {};
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final s = await _store.read(_settingsFile);
      if (s != null) {
        _mode = (jsonDecode(s) as Map<String, dynamic>)['mode'] == 'immersive' ? ImagineMode.immersive : ImagineMode.lyrics;
      }
      final c = await _store.read(_cacheFile);
      if (c != null) {
        for (final e in (jsonDecode(c) as Map<String, dynamic>).entries) {
          _cache[e.key] = Storyboard.fromJson(e.value as Map<String, dynamic>);
          _order.add(e.key);
        }
      }
    } catch (e) {
      debugPrint('[Imagine] Arquivo ilegível, recomeçando: $e');
    }
    notifyListeners();
  }

  Future<void> setMode(ImagineMode m) async {
    _mode = m;
    await _store.write(_settingsFile, jsonEncode({'mode': m.name}));
    notifyListeners();
  }

  Storyboard? cached(String title, String artist, List<String> lines) => _cache[keyFor(title, artist, lines)];

  static String keyFor(String title, String artist, List<String> lines) =>
      'sb|${sha1.convert(utf8.encode('$artist␞$title␞${lines.join('␞')}'))}';

  /// Roteiro da música (com as fotos); feito uma vez e guardado. Nulo se não houver chip, a IA falhar ou
  /// a resposta vier fora do formato.
  Future<Storyboard?> storyboard({
    required String title,
    required String artist,
    String? album,
    required List<String> lines,
    double? durationSeconds,
  }) async {
    await load();
    final key = keyFor(title, artist, lines);
    final hit = _cache[key];
    if (hit != null) return hit;
    return _inFlight[key] ??= _make(key, title, artist, album, lines, durationSeconds).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<Storyboard?> _make(String key, String title, String artist, String? album, List<String> lines, double? duration) async {
    final hasLyrics = lines.any((l) => l.trim().isNotEmpty);
    final String reply;
    try {
      reply = await ai.complete(
        system: hasLyrics ? _lyricsPrompt(title, artist) : _instrumentalPrompt(title, artist, album, duration),
        user: hasLyrics ? jsonEncode(lines) : jsonEncode({'title': title, 'artist': artist, 'album': album}),
        maxTokens: 2048,
      );
    } on BrainAiException catch (e) {
      lastError = e.reason;
      notifyListeners();
      return null;
    } catch (e) {
      lastError = 'failed';
      return null;
    }
    final board = Storyboard.parse(reply, lineCount: hasLyrics ? lines.length : 0);
    if (board == null) {
      lastError = 'bad_reply';
      return null;
    }
    final withPhotos = await _attachPhotos(board);
    lastError = null;
    // Só guarda quando há fotos: sem chave do Unsplash / limite atingido, tenta de novo na próxima vez
    if (withPhotos.hasPhotos) _remember(key, withPhotos);
    return withPhotos;
  }

  /// Uma foto por cena: a primeira da busca que ainda não foi usada nesta música.
  Future<Storyboard> _attachPhotos(Storyboard board) async {
    final s = searcher;
    if (s == null) return board;
    final used = <String>{};
    final scenes = <ImagineScene>[];
    for (final scene in board.scenes) {
      ImaginePhoto? pick;
      try {
        final found = await s.search(scene.query);
        for (final p in found) {
          if (used.add(p.id)) {
            pick = p;
            break;
          }
        }
      } catch (e) {
        debugPrint('[Imagine] Busca "${scene.query}" falhou: $e');
        lastError = 'search_failed';
      }
      scenes.add(scene.withPhoto(pick));
    }
    return Storyboard(scenes: scenes, quotes: board.quotes);
  }

  void _remember(String key, Storyboard value) {
    _cache[key] = value;
    _order
      ..remove(key)
      ..add(key);
    while (_order.length > maxCached) {
      _cache.remove(_order.removeAt(0));
    }
    _store.write(_cacheFile, jsonEncode({for (final k in _order) k: _cache[k]!.toJson()}));
  }

  static String _lyricsPrompt(String title, String artist) =>
      'You are the visual director of "Imagined Music", a slow, cinematic photo slideshow shown behind the lyrics '
      'while a vinyl record plays. You receive the lyrics of "$title" by $artist as a JSON array of lines (index = '
      'position). Split the song into visual scenes that follow its sections and imagery (usually every 3 to 8 lines; '
      '4 to 8 scenes in total). For each scene write a short English search query for a stock photo library: '
      'concrete, photographable subjects, setting, light and mood (for example "solitary silhouette rainy city street '
      'night blue light"); interpret metaphors visually; never use names of people, bands, brands or places that '
      'identify the song, and never ask for text in the image. Also choose 3 to 6 striking short quotes from the '
      'lyrics (the exact text of a single line, up to 60 characters), spread across the whole song, for an immersive '
      'display. Reply with ONLY JSON: {"scenes":[{"line":0,"query":"...","mood":"one word","palette":["#rrggbb",'
      '"#rrggbb","#rrggbb"],"motion":"zoom_in|zoom_out|pan_left|pan_right","transition":"dissolve|cut",'
      '"intensity":0.5}],"quotes":[{"line":4,"text":"..."}]}. Scenes are in increasing line order and the first '
      'starts at line 0. Use "cut" only for sudden changes of energy; intensity follows the energy of the section.';

  static String _instrumentalPrompt(String title, String artist, String? album, double? duration) =>
      'You are the visual director of "Imagined Music", a slow, cinematic photo slideshow shown while a vinyl record '
      'plays. The track "$title" by $artist${album == null ? '' : ' (album "$album")'} has no lyrics'
      '${duration == null ? '' : ' and lasts about ${duration.round()} seconds'}. Imagine its mood from the title and '
      'the album, and create 3 to 6 scenes spread evenly across the track. For each scene write a short English search '
      'query for a stock photo library (concrete subjects, setting, light and mood; no names of people, bands, brands '
      'or places; no text in the image). Reply with ONLY JSON: {"scenes":[{"line":0,"at":0,"query":"...","mood":'
      '"one word","palette":["#rrggbb","#rrggbb","#rrggbb"],"motion":"zoom_in|zoom_out|pan_left|pan_right",'
      '"transition":"dissolve","intensity":0.4}],"quotes":[]} where "at" is the second when the scene starts.';
}
