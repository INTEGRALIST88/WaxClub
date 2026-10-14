import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dropbox/dropbox_service.dart';
import 'tracklist_matcher.dart';

/// Uma letra importada pelo usuário (arquivo .lrc ou .txt que ele tem o direito de usar).
class LocalLyricsEntry {
  final String title;
  final String artist;
  final String? album;
  final String lyrics;
  final double? durationSeconds;
  final String fileName;

  /// Veio da pasta do app no Dropbox (caminho e revisão do arquivo lá); nulo = escolhido no seletor.
  final String? dropboxPath;
  final String? dropboxRev;

  const LocalLyricsEntry({
    required this.title,
    required this.artist,
    this.album,
    required this.lyrics,
    this.durationSeconds,
    required this.fileName,
    this.dropboxPath,
    this.dropboxRev,
  });

  LocalLyricsEntry fromDropbox(String path, String rev) => LocalLyricsEntry(
        title: title,
        artist: artist,
        album: album,
        lyrics: lyrics,
        durationSeconds: durationSeconds,
        fileName: fileName,
        dropboxPath: path,
        dropboxRev: rev,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        if (album != null) 'album': album,
        'lyrics': lyrics,
        if (durationSeconds != null) 'duration': durationSeconds,
        'file': fileName,
        if (dropboxPath != null) 'dropboxPath': dropboxPath,
        if (dropboxRev != null) 'dropboxRev': dropboxRev,
      };

  factory LocalLyricsEntry.fromJson(Map<String, dynamic> j) => LocalLyricsEntry(
        title: j['title'] as String,
        artist: j['artist'] as String,
        album: j['album'] as String?,
        lyrics: j['lyrics'] as String,
        durationSeconds: (j['duration'] as num?)?.toDouble(),
        fileName: j['file'] as String? ?? '',
        dropboxPath: j['dropboxPath'] as String?,
        dropboxRev: j['dropboxRev'] as String?,
      );
}

/// Pasta de letras na nuvem (a pasta do app no Dropbox): listar e baixar.
abstract class LyricsFolderSource {
  Future<List<DropboxFile>> listAppFolder();
  Future<String> download(String path);
}

/// Resultado de uma sincronização com a pasta da nuvem.
class LyricsFolderSync {
  final int added;
  final int updated;
  final int removed;
  final List<String> skipped;
  const LyricsFolderSync({required this.added, required this.updated, required this.removed, required this.skipped});
}

/// Resultado de uma importação: quantas letras entraram e quais arquivos não foram entendidos.
class LocalLyricsImport {
  final int added;
  final List<String> skipped;
  const LocalLyricsImport(this.added, this.skipped);
}

/// Plugin S5 "My lyrics files": letras que o próprio usuário obteve legalmente (compradas, licenciadas,
/// escritas por ele, em domínio público ou com autorização) e copiou para o celular. Ficam **só no
/// aparelho**: o WaxClub não envia, não compartilha e não distribui esses arquivos — apenas os exibe
/// para o próprio usuário enquanto o disco toca.
class LocalLyricsLibrary extends ChangeNotifier {
  static const String _fileName = 'waxclub_my_lyrics.json';
  static const int maxFileBytes = 512 * 1024;

  final Directory? _directory;
  final List<LocalLyricsEntry> _entries = [];
  bool _loaded = false;

  LocalLyricsLibrary({Directory? directory}) : _directory = directory;

  int get count => _entries.length;
  List<LocalLyricsEntry> get entries => List.unmodifiable(_entries);

  Future<File?> _file() async {
    try {
      final dir = _directory ?? await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}$_fileName');
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (f != null && await f.exists()) {
        final list = jsonDecode(await f.readAsString()) as List<dynamic>;
        _entries
          ..clear()
          ..addAll(list.whereType<Map<String, dynamic>>().map(LocalLyricsEntry.fromJson));
      }
    } catch (e) {
      debugPrint('[MyLyrics] Arquivo ilegível: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f?.writeAsString(jsonEncode(_entries.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[MyLyrics] Falha ao salvar: $e');
    }
  }

  /// Importa arquivos ([name] = nome do arquivo, [content] = texto). Letra da mesma música substitui a
  /// anterior.
  Future<LocalLyricsImport> importFiles(List<({String name, String content})> files) async {
    await load();
    var added = 0;
    final skipped = <String>[];
    for (final f in files) {
      final e = parse(f.name, f.content);
      if (e == null) {
        skipped.add(f.name);
        continue;
      }
      _entries.removeWhere((x) => TracklistMatcher.isSameTrack(x.title, x.artist, e.title, e.artist));
      _entries.add(e);
      added++;
    }
    if (added > 0) {
      notifyListeners();
      await _save();
    }
    return LocalLyricsImport(added, skipped);
  }

  int get dropboxCount => _entries.where((e) => e.dropboxPath != null).length;

  /// Atualiza a partir da pasta do app no Dropbox: baixa só os arquivos novos ou alterados (pela
  /// revisão), tira os que foram apagados de lá. Os escolhidos à mão no seletor ficam.
  Future<LyricsFolderSync> syncFrom(LyricsFolderSource folder) async {
    await load();
    final files = (await folder.listAppFolder()).where((f) {
      final n = f.name.toLowerCase();
      return (n.endsWith('.lrc') || n.endsWith('.txt')) && f.size <= maxFileBytes;
    }).toList();
    final byPath = {for (final e in _entries) if (e.dropboxPath != null) e.dropboxPath!.toLowerCase(): e};
    var added = 0, updated = 0;
    final skipped = <String>[];
    for (final f in files) {
      final known = byPath[f.path.toLowerCase()];
      if (known != null && known.dropboxRev == f.rev) continue;
      final String content;
      try {
        content = await folder.download(f.path);
      } catch (_) {
        skipped.add(f.name);
        continue;
      }
      final e = parse(f.name, content)?.fromDropbox(f.path, f.rev);
      if (e == null) {
        skipped.add(f.name);
        continue;
      }
      _entries.removeWhere((x) =>
          (x.dropboxPath?.toLowerCase() == f.path.toLowerCase()) || TracklistMatcher.isSameTrack(x.title, x.artist, e.title, e.artist));
      _entries.add(e);
      known == null ? added++ : updated++;
    }
    final present = files.map((f) => f.path.toLowerCase()).toSet();
    final before = _entries.length;
    _entries.removeWhere((e) => e.dropboxPath != null && !present.contains(e.dropboxPath!.toLowerCase()));
    final removed = before - _entries.length;
    if (added + updated + removed > 0) {
      notifyListeners();
      await _save();
    }
    return LyricsFolderSync(added: added, updated: updated, removed: removed, skipped: skipped);
  }

  Future<void> clear() async {
    _entries.clear();
    notifyListeners();
    await _save();
  }

  /// A letra importada desta música, se houver.
  LocalLyricsEntry? find(String title, String artist) {
    for (final e in _entries) {
      if (TracklistMatcher.isSameTrack(e.title, e.artist, title, artist)) return e;
    }
    return null;
  }

  static final RegExp _tag = RegExp(r'^\[(ar|ti|al|length):\s*(.*?)\s*\]\s*$', caseSensitive: false);
  static final RegExp _timed = RegExp(r'\[\d{1,2}:\d{2}');

  /// Lê um .lrc (tags [ar:], [ti:], [al:], [length:]) ou .txt. Sem as tags, o nome do arquivo
  /// "Artista - Música.lrc" diz de qual música é. Devolve nulo se não der para saber a música.
  static LocalLyricsEntry? parse(String fileName, String content) {
    final lower = fileName.toLowerCase();
    if (!lower.endsWith('.lrc') && !lower.endsWith('.txt')) return null;
    if (content.length > maxFileBytes || content.trim().isEmpty) return null;
    String? artist;
    String? title;
    String? album;
    double? duration;
    final body = <String>[];
    for (final raw in const LineSplitter().convert(content.replaceFirst('﻿', ''))) {
      final m = _tag.firstMatch(raw.trim());
      if (m != null) {
        final value = m.group(2)!;
        switch (m.group(1)!.toLowerCase()) {
          case 'ar':
            artist = value;
          case 'ti':
            title = value;
          case 'al':
            album = value;
          case 'length':
            final p = value.split(':');
            if (p.length == 2) duration = (int.tryParse(p[0]) ?? 0) * 60 + (double.tryParse(p[1]) ?? 0);
        }
        continue;
      }
      body.add(raw);
    }
    if (artist == null || title == null || artist.isEmpty || title.isEmpty) {
      final base = fileName.replaceAll(RegExp(r'\.(lrc|txt)$', caseSensitive: false), '');
      final dash = base.indexOf(' - ');
      if (dash > 0) {
        artist = (artist == null || artist.isEmpty) ? base.substring(0, dash).trim() : artist;
        title = (title == null || title.isEmpty) ? base.substring(dash + 3).trim() : title;
      }
    }
    if (artist == null || title == null || artist.isEmpty || title.isEmpty) return null;
    final lyrics = body.join('\n').trim();
    if (lyrics.isEmpty) return null;
    return LocalLyricsEntry(
      title: title,
      artist: artist,
      album: (album == null || album.isEmpty) ? null : album,
      lyrics: lyrics,
      durationSeconds: duration != null && duration > 0 ? duration : null,
      fileName: fileName,
    );
  }

  static bool hasTimestamps(String lyrics) => _timed.hasMatch(lyrics);
}
