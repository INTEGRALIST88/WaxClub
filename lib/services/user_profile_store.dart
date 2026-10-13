import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Perfil local do usuário (por enquanto só o nome usado nas saudações), guardado no aparelho.
/// Quando a conta WaxClub existir, o nome passa a vir do cadastro e este arquivo vira o cache dele.
class UserProfileStore extends ChangeNotifier {
  static const String _fileName = 'waxclub_profile.json';
  final Directory? _directory;

  UserProfileStore({Directory? directory}) : _directory = directory;

  String? _displayName;
  bool _loaded = false;

  /// Nome que o usuário quer ver nas saudações (ex.: "Gustavo"); `null` se ainda não informou.
  String? get displayName => _displayName;
  bool get isLoaded => _loaded;

  Future<File?> _file() async {
    try {
      final dir = _directory ?? await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}$_fileName');
    } catch (_) {
      return null; // sem armazenamento (ex.: testes): perfil só em memória
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file();
      if (f != null && await f.exists()) {
        final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final name = (json['displayName'] as String?)?.trim();
        _displayName = (name == null || name.isEmpty) ? null : name;
      }
    } catch (e) {
      debugPrint('[UserProfileStore] Perfil local ilegível: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDisplayName(String? name) async {
    final clean = name?.trim();
    _displayName = (clean == null || clean.isEmpty) ? null : clean;
    notifyListeners();
    try {
      final f = await _file();
      if (f != null) await f.writeAsString(jsonEncode({'displayName': _displayName}));
    } catch (e) {
      debugPrint('[UserProfileStore] Falha ao salvar o perfil: $e');
    }
  }
}
