import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../ai_translator.dart' show TranslatorStore, FileTranslatorStore;
import '../brain/brain_ai.dart';

/// Imagem de uma cena: foto do Unsplash (exibida pelo endereço do Unsplash, com crédito ao fotógrafo) ou
/// obra de arte em domínio público do acervo do WaxClub (The Met, Art Institute of Chicago).
class ImaginePhoto {
  final String id;
  final String url; // Unsplash: urls.raw (o tamanho vai nos parâmetros); acervo: o arquivo 512 px no servidor
  final String? color;
  final String author; // fotógrafo ou artista
  final String? authorUrl;
  final String? photoUrl;
  final String? download; // links.download_location (avisar o uso ao Unsplash)

  /// 'unsplash' ou o museu da obra ('The Met', 'Art Institute of Chicago').
  final String source;

  /// Título da obra (acervo) ou descrição da foto.
  final String? title;
  final String? date;

  const ImaginePhoto({
    required this.id,
    required this.url,
    required this.author,
    this.color,
    this.authorUrl,
    this.photoUrl,
    this.download,
    this.source = 'unsplash',
    this.title,
    this.date,
  });

  bool get isArt => source != 'unsplash';

  /// Endereço no tamanho usado pelo WaxClub (512 px; as obras do acervo já estão nesse tamanho).
  String sized({int width = ImaginedMusic.imageWidth}) =>
      isArt ? url : '$url${url.contains('?') ? '&' : '?'}w=$width&q=75&auto=format&fit=max';

  /// Crédito exibido junto da imagem (em inglês, como o resto da tela da TV).
  String get credit {
    if (!isArt) return 'Photo: $author · Unsplash'; // l10n-ignore
    final who = author.trim().isEmpty ? '' : ' — ${author.trim()}';
    final when = (date ?? '').trim().isEmpty ? '' : ' (${date!.trim()})';
    return '${title ?? 'Untitled'}$who$when · $source'; // l10n-ignore
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'author': author,
        if (color != null) 'color': color,
        if (authorUrl != null) 'authorUrl': authorUrl,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (download != null) 'download': download,
        if (source != 'unsplash') 'source': source,
        if (title != null) 'title': title,
        if (date != null) 'date': date,
      };

  factory ImaginePhoto.fromJson(Map<String, dynamic> j) => ImaginePhoto(
        id: '${j['id']}',
        url: '${j['url']}',
        author: '${j['author'] ?? 'Unsplash'}',
        color: j['color'] as String?,
        authorUrl: j['authorUrl'] as String?,
        photoUrl: j['photoUrl'] as String?,
        download: j['download'] as String?,
        source: (j['source'] as String?) ?? 'unsplash',
        title: j['title'] as String?,
        date: j['date'] as String?,
      );

  /// Obra do acervo, como vem de /v1/imagine/art.
  factory ImaginePhoto.fromArt(Map<String, dynamic> j) => ImaginePhoto(
        id: '${j['id']}',
        url: '${j['url']}',
        author: '${j['artist'] ?? ''}',
        color: j['color'] as String?,
        source: '${j['museum'] ?? 'Museum'}',
        title: j['title'] as String?,
        date: j['date'] as String?,
      );
}

/// Uma cena do roteiro: começa na linha [line] da letra (ou em [atSeconds], música sem letra).
class ImagineScene {
  final int line;
  final double? atSeconds;
  final String query;

  /// Busca de obra de arte (acervo de museus) para a mesma cena.
  final String art;

  /// Sentimento do trecho (um de [emotions]); escolhe a imagem de sentimento da cena. Vazio se não houver.
  final String emotion;
  final String mood;
  final List<String> palette; // cores #rrggbb
  final String motion; // zoom_in, zoom_out, pan_left, pan_right
  final String transition; // dissolve, cut
  final double intensity; // 0..1
  final ImaginePhoto? photo;

  /// Mais fotos da mesma busca: a cena vira várias tomadas curtas (a imagem troca a cada ~13 s).
  final List<ImaginePhoto> more;

  /// Todas as fotos da cena, na ordem das tomadas.
  List<ImaginePhoto> get photos => [if (photo != null) photo!, ...more];

  const ImagineScene({
    required this.line,
    this.atSeconds,
    required this.query,
    this.art = '',
    this.emotion = '',
    this.mood = '',
    this.palette = const [],
    this.motion = 'zoom_in',
    this.transition = 'dissolve',
    this.intensity = 0.5,
    this.photo,
    this.more = const [],
  });

  ImagineScene withPhoto(ImaginePhoto? p, [List<ImaginePhoto> more = const []]) => ImagineScene(
        line: line,
        atSeconds: atSeconds,
        query: query,
        art: art,
        emotion: emotion,
        mood: mood,
        palette: palette,
        motion: motion,
        transition: transition,
        intensity: intensity,
        photo: p,
        more: p == null ? const [] : more,
      );

  Map<String, dynamic> toJson() => {
        'line': line,
        if (atSeconds != null) 'at': atSeconds,
        'query': query,
        if (art.isNotEmpty) 'art': art,
        if (emotion.isNotEmpty) 'emotion': emotion,
        'mood': mood,
        'palette': palette,
        'motion': motion,
        'transition': transition,
        'intensity': intensity,
        if (photo != null) 'photo': photo!.toJson(),
        if (more.isNotEmpty) 'more': [for (final p in more) p.toJson()],
      };

  static const _motions = {'zoom_in', 'zoom_out', 'pan_left', 'pan_right'};

  /// Sentimentos (as mesmas chaves do servidor) e as buscas fixas de cada um no Unsplash: imagens diretas do
  /// sentimento (casal se beijando, raio, pessoa sozinha...). São poucas buscas no total e o servidor guarda
  /// cada uma por dias, então quase não gastam o limite do Unsplash.
  static const emotionQueries = {
    'love': ['couple silhouette at sunset', 'two people holding hands in warm light', 'warm golden hour couple'],
    'desire': ['couple dancing close in dim light', 'deep red sunset sky', 'warm candle light glow'],
    'longing': ['person looking at the horizon', 'empty road at dusk', 'rain on a window at night'],
    'loneliness': ['lone person on an empty street at night', 'solitary tree in an open field', 'empty beach in fog'],
    'sadness': ['rain on a window', 'grey cloudy sky over fields', 'person walking alone in the rain'],
    'anger': ['lightning storm over the sea', 'crashing waves in a storm', 'wildfire flames at night'],
    'fear': ['dark forest in fog', 'stormy night sky', 'dark empty alley at night'],
    'hope': ['sunrise over green fields', 'sunlight breaking through clouds', 'spring blossoms in sunlight'],
    'joy': ['friends laughing outdoors in the sun', 'sunflower field on a sunny day', 'children running in a meadow'],
    'euphoria': ['concert crowd with colorful lights', 'fireworks over the night sky', 'people dancing in neon lights'],
    'freedom': ['bird flying in a wide sky', 'open road through mountains', 'person with arms open on a hilltop'],
    'nostalgia': ['golden hour on a quiet old street', 'faded summer field at sunset', 'warm evening light on an old house'],
    'peace': ['calm lake reflection at dawn', 'quiet forest in the morning', 'meadow at sunset'],
    'melancholy': ['autumn leaves in the rain', 'foggy grey city', 'dusk over a still lake'],
    'faith': ['light rays through the clouds', 'starry night sky', 'candles glowing in the dark'],
    'rebellion': ['crowd with raised fists', 'stormy sea with huge waves', 'city at night with neon lights'],
  };
  static final emotions = emotionQueries.keys.toList(growable: false);
  static final _hex = RegExp(r'^#[0-9a-fA-F]{6}$');

  factory ImagineScene.fromJson(Map<String, dynamic> j) {
    final motion = '${j['motion'] ?? 'zoom_in'}';
    final intensity = (j['intensity'] is num) ? (j['intensity'] as num).toDouble() : 0.5;
    final emotion = '${j['emotion'] ?? ''}'.trim().toLowerCase();
    return ImagineScene(
      line: (j['line'] is num) ? (j['line'] as num).toInt() : 0,
      atSeconds: (j['at'] is num) ? (j['at'] as num).toDouble() : null,
      query: '${j['query'] ?? ''}'.trim(),
      art: '${j['art'] ?? ''}'.trim(),
      emotion: emotions.contains(emotion) ? emotion : '',
      mood: '${j['mood'] ?? ''}',
      palette: [
        for (final c in (j['palette'] as List<dynamic>? ?? const []))
          if (c is String && _hex.hasMatch(c)) c,
      ].take(4).toList(),
      motion: _motions.contains(motion) ? motion : 'zoom_in',
      transition: j['transition'] == 'cut' ? 'cut' : 'dissolve',
      intensity: intensity.clamp(0.0, 1.0),
      photo: j['photo'] is Map<String, dynamic> ? ImaginePhoto.fromJson(j['photo'] as Map<String, dynamic>) : null,
      more: [
        for (final p in (j['more'] as List<dynamic>? ?? const []))
          if (p is Map<String, dynamic>) ImaginePhoto.fromJson(p),
      ],
    );
  }
}

/// Uma tomada: uma foto na tela a partir de [ms] (milissegundos da música), dentro de uma cena.
class ImagineShot {
  final int ms;
  final ImaginePhoto photo;
  final ImagineScene scene;
  const ImagineShot(this.ms, this.photo, this.scene);
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

  /// Duração de cada tomada: a imagem troca mais ou menos nesse ritmo.
  static const int shotMs = 13000;

  /// A imagem de uma cena entra um pouco antes do verso dela ser cantado (antecipa o contexto).
  static const int leadMs = 2500;

  /// Tomadas da música: cada cena com foto é dividida em pedaços de ~13 s, até o número de fotos que ela
  /// tem (cenas longas com poucas fotos ficam mais tempo em cada uma). [startMs] dá o início de cada cena
  /// (pela linha da letra ou pelo segundo, nas instrumentais); [endMs] é o fim da música (ou nulo).
  List<ImagineShot> shots(int Function(ImagineScene) startMs, {int? endMs}) {
    final withPhoto = [for (final s in scenes) if (s.photo != null) s];
    final out = <ImagineShot>[];
    for (var i = 0; i < withPhoto.length; i++) {
      final s = withPhoto[i];
      final start = startMs(s);
      final end = i + 1 < withPhoto.length ? startMs(withPhoto[i + 1]) : (endMs ?? start + 4 * shotMs);
      final photos = s.photos;
      final n = ((end - start) / shotMs).round().clamp(1, photos.length);
      final step = (end - start) / n;
      for (var k = 0; k < n; k++) {
        // a primeira tomada da cena se antecipa ao verso, sem passar da tomada anterior
        var at = start + (step * k).round() - (k == 0 && i > 0 ? leadMs : 0);
        if (out.isNotEmpty && at <= out.last.ms + 2000) at = out.last.ms + 2000;
        out.add(ImagineShot(at, photos[k], s));
      }
    }
    return out;
  }

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

  /// Obras de arte do acervo do WaxClub (domínio público; sem limite de buscas).
  Future<List<ImaginePhoto>> searchArt(String query);

  /// Imagens escolhidas para um sentimento (um de [ImagineScene.emotions]), já embaralhadas.
  Future<List<ImaginePhoto>> searchEmotion(String emotion);

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

  /// Fotos por cena no máximo (tomadas de ~13 s).
  static const int maxShotsPerScene = 4;

  static const _settingsFile = 'waxclub_imagine.json';
  static const _cacheFile = 'waxclub_storyboards_v2.json'; // v2: várias fotos por cena (tomadas); os antigos são refeitos
  static const int maxCached = 200;

  ImagineMode _mode = ImagineMode.lyrics;
  ImagineMode get mode => _mode;

  /// Por que a última música ficou sem imagens: 'no_chip', 'all_failed' (o chip não respondeu),
  /// 'bad_reply' (resposta fora do formato), 'search_failed' (busca de fotos falhou), 'no_photos'.
  String? lastError;

  /// Está montando o roteiro de alguma música agora.
  bool get working => _inFlight.isNotEmpty;
  final Map<String, Storyboard> _cache = {};
  final List<String> _order = [];
  final Map<String, Future<Storyboard?>> _inFlight = {};
  Future<void>? _loading;

  // Imagens de sentimento: a lista de cada sentimento vem uma vez por sessão; as usadas por último ficam de lado
  // para não repetir de uma música para a outra (com ~20 por sentimento, um disco inteiro triste não repete)
  final Map<String, Future<List<ImaginePhoto>>> _emotionPool = {};
  final List<String> _recentEmotion = [];
  static const int _recentEmotionMax = 60;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final s = await _store.read(_settingsFile);
      if (s != null) {
        _mode =
            (jsonDecode(s) as Map<String, dynamic>)['mode'] == 'immersive' ? ImagineMode.immersive : ImagineMode.lyrics;
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
    final running = _inFlight[key];
    if (running != null) return running;
    final job = _inFlight[key] = _make(key, title, artist, album, lines, durationSeconds).whenComplete(() {
      _inFlight.remove(key);
      notifyListeners(); // terminou (com ou sem imagens): a tela atualiza o aviso
    });
    scheduleMicrotask(notifyListeners); // começou: "Imagining this song…"
    return job;
  }

  Future<Storyboard?> _make(
      String key, String title, String artist, String? album, List<String> lines, double? duration) async {
    final hasLyrics = lines.any((l) => l.trim().isNotEmpty);
    final String reply;
    try {
      reply = await ai.complete(
        system: hasLyrics ? _lyricsPrompt(title, artist) : _instrumentalPrompt(title, artist, album, duration),
        user: hasLyrics ? jsonEncode(lines) : jsonEncode({'title': title, 'artist': artist, 'album': album}),
        maxTokens: 4096, // 16 cenas com buscas, cores e frases passam de 2 mil tokens (a resposta vinha cortada)
      );
    } on BrainAiException catch (e) {
      lastError = e.reason;
      debugPrint('[Imagine] Sem roteiro para "$title": ${e.reason}');
      return null;
    } catch (e) {
      lastError = 'all_failed';
      debugPrint('[Imagine] Sem roteiro para "$title": $e');
      return null;
    }
    final board = Storyboard.parse(reply, lineCount: hasLyrics ? lines.length : 0);
    if (board == null) {
      lastError = 'bad_reply';
      debugPrint('[Imagine] Resposta fora do formato para "$title" (${reply.length} caracteres)');
      return null;
    }
    lastError = null;
    final withPhotos = await _attachPhotos(board);
    if (!withPhotos.hasPhotos) {
      lastError ??= 'no_photos';
      debugPrint('[Imagine] Roteiro de "$title" sem nenhuma imagem ($lastError)');
    } else {
      lastError = null;
      debugPrint('[Imagine] Roteiro de "$title": ${withPhotos.scenes.length} cenas, ${withPhotos.quotes.length} frases');
    }
    // Só guarda quando há fotos: sem chave do Unsplash / limite atingido, tenta de novo na próxima vez
    if (withPhotos.hasPhotos) _remember(key, withPhotos);
    return withPhotos;
  }

  /// Uma imagem por cena, sem repetir na música, em rodízio de três fontes: foto do Unsplash, obra de arte do
  /// acervo (não gasta o limite do Unsplash) e imagem do sentimento do trecho. Se uma fonte não achar, as
  /// outras cobrem.
  Future<Storyboard> _attachPhotos(Storyboard board) async {
    final s = searcher;
    if (s == null) return board;
    final used = <String>{};
    final scenes = <ImagineScene>[];
    // Cada texto de busca é pedido uma vez só por música (o agente repete a busca nas cenas de uma mesma
    // parte); as fotos que sobram viram as outras tomadas das cenas
    final results = <String, Future<List<ImaginePhoto>>>{};

    Future<List<ImaginePhoto>> searchOnce(String what, String q, Future<List<ImaginePhoto>> Function() run) =>
        results['$what|${q.toLowerCase().trim()}'] ??= run().catchError((Object e) {
          debugPrint('[Imagine] Busca de $what "$q" falhou: $e');
          lastError = 'search_failed';
          return <ImaginePhoto>[];
        });

    Future<ImaginePhoto?> pickFrom(Future<List<ImaginePhoto>> list) async {
      for (final p in await list) {
        if (used.add(p.id)) return p;
      }
      return null;
    }

    /// Até [n] fotos ainda não usadas da mesma busca da foto principal (para as tomadas da cena).
    Future<List<ImaginePhoto>> extras(Future<List<ImaginePhoto>>? list, int n) async {
      if (list == null) return const [];
      final out = <ImaginePhoto>[];
      for (final p in await list) {
        if (out.length >= n) break;
        if (used.add(p.id)) out.add(p);
      }
      return out;
    }

    Future<ImaginePhoto?> feeling(String emotion) async {
      if (emotion.isEmpty) return null;
      final List<ImaginePhoto> pool;
      try {
        pool = await (_emotionPool[emotion] ??= s.searchEmotion(emotion));
      } catch (e) {
        _emotionPool.remove(emotion); // tenta de novo na próxima música
        debugPrint('[Imagine] Busca do sentimento $emotion falhou: $e');
        return null;
      }
      final fresh = pool.where((p) => !used.contains(p.id) && !_recentEmotion.contains(p.id));
      final pick = fresh.isNotEmpty ? fresh.first : pool.where((p) => !used.contains(p.id)).firstOrNull;
      if (pick == null) return null;
      used.add(pick.id);
      _recentEmotion
        ..remove(pick.id)
        ..add(pick.id);
      if (_recentEmotion.length > _recentEmotionMax) _recentEmotion.removeAt(0);
      return pick;
    }

    for (var i = 0; i < board.scenes.length; i++) {
      final scene = board.scenes[i];
      final artQuery = scene.art.isNotEmpty ? scene.art : scene.query;
      final photoList = searchOnce('foto', scene.query, () => s.search(scene.query));
      Future<List<ImaginePhoto>> artList() => searchOnce('obra', artQuery, () => s.searchArt(artQuery));
      Future<ImaginePhoto?> photo() => pickFrom(photoList);
      Future<ImaginePhoto?> art() async => pickFrom(artList());
      // A foto da letra manda: obra e sentimento entram de vez em quando (1 cena em 4 cada), sem tomar o lugar
      final ImaginePhoto? pick;
      switch (i % 4) {
        case 1:
          pick = await art() ?? await photo() ?? await feeling(scene.emotion);
        case 3:
          pick = await feeling(scene.emotion) ?? await photo() ?? await art();
        default:
          pick = await photo() ?? await art() ?? await feeling(scene.emotion);
      }
      // As outras tomadas da cena vêm da busca da letra (o que a música descreve)
      final more = pick == null ? const <ImaginePhoto>[] : await extras(photoList, maxShotsPerScene - 1);
      scenes.add(scene.withPhoto(pick, more));
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
      'position). Split the song into visual scenes that follow its sections and imagery (usually every 2 to 4 lines; '
      '8 to 16 scenes in total). For each scene write two short English searches: "query" for a stock photo library '
      'and "art" for a museum collection. The "query" must show what the lyrics of that scene literally describe or '
      'evoke — its places, nature, weather, light, colors, people and actions (if the lines talk about trees and green '
      'fields, the query is about trees and green fields, for example "green meadow tall trees summer light"); 3 to 6 '
      'plain words, concrete and photographable, no abstract ideas, no objects that are not in the lyrics. Use at most '
      '6 different queries in the whole song: scenes of the same part of the song reuse the same query. The "art" search '
      'is for a museum collection of public-domain paintings, prints and old photographs '
      '(subject plus a fitting art style or era, for example "stormy sea romantic painting" or "night street '
      'impressionism"); interpret metaphors visually. Give each scene the "emotion" it carries, one of: '
      '${ImagineScene.emotions.join(', ')}; never use names of people, bands, brands or places that '
      'identify the song, and never ask for text in the image. Also choose 6 to 10 striking short quotes from the '
      'lyrics (the exact text of a single line, up to 60 characters), spread across the whole song, for an immersive '
      'display. Reply with ONLY JSON: {"scenes":[{"line":0,"query":"...","art":"...","emotion":"longing","mood":"one word","palette":["#rrggbb",'
      '"#rrggbb","#rrggbb"],"motion":"zoom_in|zoom_out|pan_left|pan_right","transition":"dissolve|cut",'
      '"intensity":0.5}],"quotes":[{"line":4,"text":"..."}]}. Scenes are in increasing line order and the first '
      'starts at line 0. Use "cut" only for sudden changes of energy; intensity follows the energy of the section.';

  static String _instrumentalPrompt(String title, String artist, String? album, double? duration) =>
      'You are the visual director of "Imagined Music", a slow, cinematic photo slideshow shown while a vinyl record '
      'plays. The track "$title" by $artist${album == null ? '' : ' (album "$album")'} has no lyrics'
      '${duration == null ? '' : ' and lasts about ${duration.round()} seconds'}. Imagine its mood from the title and '
      'the album, and create 6 to 12 scenes spread evenly across the track. For each scene write two short English '
      'searches: "query" for a stock photo library and "art" for a museum collection of public-domain paintings and '
      'old photographs (subject plus an art style or era), and the "emotion" of the scene, one of: '
      '${ImagineScene.emotions.join(', ')}; no names of people, bands, brands or places; no text in '
      'the image. Reply with ONLY JSON: {"scenes":[{"line":0,"at":0,"query":"...","art":"...","emotion":"peace","mood":'
      '"one word","palette":["#rrggbb","#rrggbb","#rrggbb"],"motion":"zoom_in|zoom_out|pan_left|pan_right",'
      '"transition":"dissolve","intensity":0.4}],"quotes":[]} where "at" is the second when the scene starts.';
}
