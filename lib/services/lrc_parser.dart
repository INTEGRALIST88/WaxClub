import 'dart:math';
import '../models/lyric_line.dart';

/// Utilitário e parser para processamento de arquivos de letra sincronizada (.lrc).
class LrcParser {
  // Regex para capturar timestamps no formato [m:ss.xx], [mm:ss.xx], [mmm:ss.xxx] com '.' ou ':'
  static final RegExp _timestampRegex = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');

  // Regex para tags de sincronismo aprimorado inline como <00:12.34>
  static final RegExp _inlineWordTimeRegex = RegExp(r'<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>');

  // Regex para captura de offset global [offset:±ms]
  static final RegExp _offsetRegex = RegExp(r'^\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);

  /// Converte uma string bruta de arquivo .lrc em uma lista ordenada de [LyricLine].
  /// Suporta tags [offset:±ms], minutos de 1-3 dígitos, frações de 1-3 dígitos,
  /// limpeza de tags <mm:ss.xx> e deduplicação de estrofes idênticas.
  /// Caso o texto seja uma letra simples sem timestamps, distribui as estrofes
  /// ao longo da duração estimada.
  static List<LyricLine> parse(String lrcContent, {double? estimatedDurationSeconds}) {
    if (lrcContent.trim().isEmpty) return [];

    final lines = lrcContent.split(RegExp(r'\r?\n'));
    final List<LyricLine> parsedLines = [];

    // 1. Extração preliminar do offset global [offset:±ms]
    int globalOffsetMs = 0;
    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      final offsetMatch = _offsetRegex.firstMatch(trimmed);
      if (offsetMatch != null) {
        globalOffsetMs = int.tryParse(offsetMatch.group(1)!) ?? 0;
        break;
      }
    }

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      // Ignora tags de metadados como [ti:...], [ar:...], [al:...], [by:...] e [offset:...]
      if (RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(trimmed)) {
        continue;
      }

      // Procura todas as ocorrências de timestamps na linha
      final matches = _timestampRegex.allMatches(trimmed);
      if (matches.isEmpty) continue;

      // O texto da letra é o restante da linha após todos os timestamps e tags inline
      var text = trimmed.replaceAll(_timestampRegex, '').trim();
      text = text.replaceAll(_inlineWordTimeRegex, '').replaceAll(RegExp(r'\s+'), ' ').trim();

      // Suporta linhas com múltiplos timestamps (ex: [00:12.34][00:24.56] Refrão)
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fractionStr = match.group(3);

        int milliseconds = 0;
        if (fractionStr != null) {
          if (fractionStr.length == 1) {
            milliseconds = int.parse(fractionStr) * 100;
          } else if (fractionStr.length == 2) {
            milliseconds = int.parse(fractionStr) * 10;
          } else {
            milliseconds = int.parse(fractionStr);
          }
        }

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        // Convenção LRC: offset positivo adianta a letra (subtrai do timestamp)
        final effectiveMs = max(0, duration.inMilliseconds - globalOffsetMs);

        parsedLines.add(LyricLine(
          timestamp: Duration(milliseconds: effectiveMs),
          text: text,
        ));
      }
    }

    // Se nenhuma linha continha timestamps, trata como texto simples (fallback)
    if (parsedLines.isEmpty) {
      final textLines = lines
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(l))
          .toList();
      if (textLines.isNotEmpty) {
        final totalSec = (estimatedDurationSeconds != null && estimatedDurationSeconds > 0)
            ? estimatedDurationSeconds
            : (textLines.length * 4.0).clamp(60.0, 300.0);
        final stepSec = totalSec / textLines.length;
        for (int i = 0; i < textLines.length; i++) {
          final timeMs = (i * stepSec * 1000).round();
          parsedLines.add(LyricLine(
            timestamp: Duration(milliseconds: timeMs),
            text: textLines[i],
          ));
        }
      }
    }

    // Ordena as linhas cronologicamente
    parsedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Deduplicação: descarta estrofes com mesmo timestamp E mesmo texto
    final List<LyricLine> dedupedLines = [];
    for (final line in parsedLines) {
      if (dedupedLines.isEmpty) {
        dedupedLines.add(line);
      } else {
        final last = dedupedLines.last;
        if (last.timestamp == line.timestamp && last.text == line.text) {
          continue; // Pula duplicata exata
        }
        dedupedLines.add(line);
      }
    }

    // Calcula durações estimadas entre linhas consecutivas
    final List<LyricLine> finalLines = [];
    for (int i = 0; i < dedupedLines.length; i++) {
      final current = dedupedLines[i];
      Duration? duration;
      if (i + 1 < dedupedLines.length) {
        duration = dedupedLines[i + 1].timestamp - current.timestamp;
      }
      finalLines.add(LyricLine(
        timestamp: current.timestamp,
        text: current.text,
        duration: duration,
      ));
    }

    return finalLines;
  }

  /// Retorna o índice da estrofe ativa com base na posição temporal atual da reprodução.
  /// Retorna -1 se a música ainda não tiver começado.
  static int findActiveIndex(List<LyricLine> lines, Duration currentPosition) {
    if (lines.isEmpty) return -1;
    if (currentPosition < lines.first.timestamp) return -1;

    // Busca binária para alta performance em loops de 60fps
    int low = 0;
    int high = lines.length - 1;
    int candidate = -1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].timestamp <= currentPosition) {
        candidate = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return candidate;
  }
}
