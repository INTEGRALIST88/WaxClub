import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Serviço de log local de eventos estruturados em formato JSON Lines (JSONL).
/// Suporta rotação automática (máx ~2000 linhas / 512 KB) e exportação rápida.
class SessionLogService {
  static const String _fileName = 'waxclub_events.jsonl';
  static const int _maxLines = 2000;
  static const int _maxBytes = 512 * 1024; // 512 KB

  final Directory? _storageDirectory;
  Future<void>? _writeQueue;
  int _writesSinceLastRotation = 0;

  SessionLogService({Directory? storageDirectory})
      : _storageDirectory = storageDirectory;

  Future<Directory> _getBaseDirectory() async {
    final customDir = _storageDirectory;
    if (customDir != null) return customDir;
    return await getApplicationDocumentsDirectory();
  }

  Future<File> _getFile() async {
    final dir = await _getBaseDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Registra um evento de forma não bloqueante e serializada, garantindo que exceções nunca vazem.
  Future<void> log(String event, [Map<String, Object?> data = const {}]) {
    final entry = {
      't': DateTime.now().toIso8601String(),
      'e': event,
      'd': data,
    };

    final completer = (_writeQueue ?? Future.value()).then((_) async {
      try {
        final file = await _getFile();
        final line = '${jsonEncode(entry)}\n';
        await file.writeAsString(line, mode: FileMode.append, flush: true);

        _writesSinceLastRotation++;
        if (_writesSinceLastRotation >= 200) {
          _writesSinceLastRotation = 0;
          await _checkRotation();
        }
      } catch (e) {
        debugPrint('[SessionLogService] Erro ao gravar log: $e');
      }
    }).catchError((e) {
      debugPrint('[SessionLogService] Erro na fila de escrita de log: $e');
    });

    _writeQueue = completer;
    return completer;
  }

  /// Verifica e trunca o arquivo se ultrapassar o limite de linhas ou bytes.
  Future<void> _checkRotation() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return;

      final length = await file.length();
      if (length <= _maxBytes) return;

      final lines = await file.readAsLines();
      if (lines.length > _maxLines) {
        final keep = lines.sublist(lines.length - _maxLines);
        await file.writeAsString('${keep.join('\n')}\n', flush: true);
        debugPrint('[SessionLogService] 🔄 Rotação de log aplicada: mantidas $_maxLines linhas.');
      }
    } catch (e) {
      debugPrint('[SessionLogService] Erro na rotação de log: $e');
    }
  }

  /// Retorna as últimas [lines] linhas gravadas como texto formatado para exportação.
  Future<String> tail({int lines = 200}) async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return 'No log entries yet.';

      final allLines = await file.readAsLines();
      if (allLines.isEmpty) return 'Log file is empty.';

      final takeCount = allLines.length > lines ? lines : allLines.length;
      final tailLines = allLines.sublist(allLines.length - takeCount);
      return tailLines.join('\n');
    } catch (e) {
      debugPrint('[SessionLogService] Erro ao ler tail do log: $e');
      return 'Could not read logs: $e';
    }
  }

  void dispose() {}
}
