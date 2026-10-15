import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'brain/brain_ai.dart';

/// Idioma de destino do tradutor (nome no próprio idioma, como aparece na lista).
class TranslatorLanguage {
  final String code;
  final String name;

  /// Nome em inglês, usado no pedido à IA.
  final String english;
  const TranslatorLanguage(this.code, this.name, this.english);

  static const List<TranslatorLanguage> all = [
    TranslatorLanguage('pt-BR', 'Português (Brasil)', 'Brazilian Portuguese'),
    TranslatorLanguage('pt-PT', 'Português (Portugal)', 'European Portuguese'),
    TranslatorLanguage('es', 'Español', 'Spanish'),
    TranslatorLanguage('fr', 'Français', 'French'),
    TranslatorLanguage('it', 'Italiano', 'Italian'),
    TranslatorLanguage('de', 'Deutsch', 'German'),
    TranslatorLanguage('nl', 'Nederlands', 'Dutch'),
    TranslatorLanguage('en', 'English', 'English'),
    TranslatorLanguage('pl', 'Polski', 'Polish'),
    TranslatorLanguage('cs', 'Čeština', 'Czech'),
    TranslatorLanguage('ro', 'Română', 'Romanian'),
    TranslatorLanguage('hu', 'Magyar', 'Hungarian'),
    TranslatorLanguage('el', 'Ελληνικά', 'Greek'),
    TranslatorLanguage('sv', 'Svenska', 'Swedish'),
    TranslatorLanguage('da', 'Dansk', 'Danish'),
    TranslatorLanguage('nb', 'Norsk', 'Norwegian'),
    TranslatorLanguage('fi', 'Suomi', 'Finnish'),
    TranslatorLanguage('ru', 'Русский', 'Russian'),
    TranslatorLanguage('uk', 'Українська', 'Ukrainian'),
    TranslatorLanguage('tr', 'Türkçe', 'Turkish'),
    TranslatorLanguage('ar', 'العربية', 'Arabic'),
    TranslatorLanguage('he', 'עברית', 'Hebrew'),
    TranslatorLanguage('hi', 'हिन्दी', 'Hindi'),
    TranslatorLanguage('ja', '日本語', 'Japanese'),
    TranslatorLanguage('ko', '한국어', 'Korean'),
    TranslatorLanguage('zh-Hans', '简体中文', 'Simplified Chinese'),
    TranslatorLanguage('zh-Hant', '繁體中文', 'Traditional Chinese'),
    TranslatorLanguage('id', 'Bahasa Indonesia', 'Indonesian'),
    TranslatorLanguage('vi', 'Tiếng Việt', 'Vietnamese'),
    TranslatorLanguage('th', 'ไทย', 'Thai'),
  ];

  static TranslatorLanguage? byCode(String? code) {
    for (final l in all) {
      if (l.code == code) return l;
    }
    return null;
  }
}

/// Onde o tradutor guarda o idioma e as traduções feitas (só no celular; nada vai para o servidor).
abstract class TranslatorStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
}

class FileTranslatorStore implements TranslatorStore {
  Future<File?> _file(String name) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$name');
    } catch (_) {
      return null; // testes
    }
  }

  @override
  Future<String?> read(String name) async {
    final f = await _file(name);
    if (f == null || !await f.exists()) return null;
    return f.readAsString();
  }

  @override
  Future<void> write(String name, String value) async {
    final f = await _file(name);
    if (f != null) await f.writeAsString(value);
  }
}

class MemoryTranslatorStore implements TranslatorStore {
  final Map<String, String> files = {};
  @override
  Future<String?> read(String name) async => files[name];
  @override
  Future<void> write(String name, String value) async => files[name] = value;
}

/// Plugin A2 — tradutor de IA: traduz tudo o que não é menu do app (letras, curiosidades, notícias e
/// informações do disco) para o idioma escolhido no plugin, com a chave do WaxBrain do usuário.
/// A letra é traduzida linha por linha (a sincronia não muda). Cada tradução é feita uma vez e guardada
/// no celular; não é enviada ao servidor nem compartilhada (a tradução de uma letra é uma obra derivada).
class AiTranslator extends ChangeNotifier {
  final BrainAi ai;
  final TranslatorStore _store;

  AiTranslator({required this.ai, TranslatorStore? store}) : _store = store ?? FileTranslatorStore();

  static const _settingsFile = 'waxclub_translator.json';
  static const _cacheFile = 'waxclub_translations.json';
  static const int maxCached = 400;

  TranslatorLanguage? _language;
  TranslatorLanguage? get language => _language;

  /// Última falha (ex.: 'no_chip'), para avisar o usuário; nula quando a última tradução deu certo.
  String? lastError;

  final Map<String, List<String>> _cache = {};
  final List<String> _order = []; // mais antigo primeiro (para descartar quando passar do limite)
  bool _loaded = false;
  Future<void>? _loading;
  final Map<String, Future<List<String>?>> _inFlight = {};

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final s = await _store.read(_settingsFile);
      if (s != null) _language = TranslatorLanguage.byCode((jsonDecode(s) as Map<String, dynamic>)['language'] as String?);
      final c = await _store.read(_cacheFile);
      if (c != null) {
        for (final e in (jsonDecode(c) as Map<String, dynamic>).entries) {
          _cache[e.key] = (e.value as List<dynamic>).map((x) => '$x').toList();
          _order.add(e.key);
        }
      }
    } catch (e) {
      debugPrint('[Translator] Arquivo ilegível, recomeçando: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  bool get isLoaded => _loaded;

  Future<void> setLanguage(TranslatorLanguage lang) async {
    _language = lang;
    await _store.write(_settingsFile, jsonEncode({'language': lang.code}));
    notifyListeners();
  }

  /// Tradução já feita (sem chamar a IA); nula se ainda não houver.
  List<String>? cached(String kind, List<String> texts) {
    final lang = _language;
    if (lang == null) return null;
    return _cache[_key(kind, lang.code, texts)];
  }

  /// Traduz as linhas de uma letra, uma por uma, mantendo a quantidade e a ordem (a sincronia não muda).
  Future<List<String>?> translateLyrics(List<String> lines, {required String title, required String artist}) => _translate(
        'lyrics',
        lines,
        'Translate song lyrics into {lang} so they read well while the song plays. You receive a JSON array with the '
            'lines of the song "$title" by $artist, in order; each line is shown at the moment it is sung, and the '
            'translation is shown under it. Reply with ONLY a JSON array of strings with exactly the same number of items. '
            'Item i is shown under line i. Translate whole phrases, not word by word: when one phrase runs across '
            'consecutive lines, put the translation of the whole phrase in the item of its FIRST line and leave the '
            'items of the following lines of that phrase as empty strings. When a line is long, you may break its '
            'translation into two lines with "\\n". Never move a translation to a line that comes before the words '
            'are sung. Keep empty strings empty and musical marks like ♪ as they are. Keep proper names. '
            'If the song is already in {lang}, reply with an array of empty strings.',
      );

  /// Traduz textos soltos (curiosidades, notícias, notas do disco), na mesma ordem.
  Future<List<String>?> translateTexts(List<String> texts, {required String context}) => _translate(
        'texts',
        texts,
        'Translate texts about music records into {lang}. They are about $context. You receive a JSON array of texts. '
            'Reply with ONLY a JSON array of strings with exactly the same number of items, where item i is the translation '
            'of text i. Keep names of people, bands, albums, songs and labels as they are. '
            'If a text is already in {lang}, repeat it unchanged.',
      );

  Future<List<String>?> _translate(String kind, List<String> texts, String instructions) async {
    await load();
    final lang = _language;
    if (lang == null || texts.isEmpty || texts.every((t) => t.trim().isEmpty)) return null;
    final key = _key(kind, lang.code, texts);
    final hit = _cache[key];
    if (hit != null) return hit;
    // Mesma tradução já pedida (ex.: a tela redesenhou): espera a mesma resposta
    // (bloco, e não "=> remove": remove() devolve o próprio Future e o whenComplete esperaria por ele mesmo)
    return _inFlight[key] ??= _ask(key, texts, instructions.replaceAll('{lang}', lang.english)).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<List<String>?> _ask(String key, List<String> texts, String instructions) async {
    try {
      final reply = await ai.complete(system: instructions, user: jsonEncode(texts), maxTokens: 4096);
      final out = parseArray(reply, texts.length);
      if (out == null) {
        debugPrint('[Translator] Resposta fora do formato (esperava ${texts.length} itens).');
        lastError = 'bad_reply';
        return null;
      }
      lastError = null;
      _remember(key, out);
      return out;
    } on BrainAiException catch (e) {
      lastError = e.reason;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[Translator] Falha: $e');
      lastError = 'failed';
      return null;
    }
  }

  /// Lê o JSON da resposta (aceita texto em volta ou bloco ```json); nulo se a quantidade não bater.
  static List<String>? parseArray(String reply, int expected) {
    final start = reply.indexOf('[');
    final end = reply.lastIndexOf(']');
    if (start < 0 || end <= start) return null;
    try {
      final list = jsonDecode(reply.substring(start, end + 1));
      if (list is! List || list.length != expected) return null;
      return [for (final x in list) x is String ? x : '$x'];
    } catch (_) {
      return null;
    }
  }

  void _remember(String key, List<String> value) {
    _cache[key] = value;
    _order
      ..remove(key)
      ..add(key);
    while (_order.length > maxCached) {
      _cache.remove(_order.removeAt(0));
    }
    _store.write(_cacheFile, jsonEncode({for (final k in _order) k: _cache[k]}));
  }

  static String _key(String kind, String lang, List<String> texts) =>
      '$kind|$lang|${sha1.convert(utf8.encode(texts.join('␞'))).toString()}';
}
