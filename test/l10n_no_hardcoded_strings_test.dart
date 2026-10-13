import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Remove os trechos `${...}` (com chaves aninhadas), que são código e não texto.
String _withoutInterpolations(String line) {
  final out = StringBuffer();
  var i = 0;
  while (i < line.length) {
    if (line.startsWith(r'${', i)) {
      var depth = 1;
      i += 2;
      while (i < line.length && depth > 0) {
        if (line[i] == '{') depth++;
        if (line[i] == '}') depth--;
        i++;
      }
    } else {
      out.write(line[i]);
      i++;
    }
  }
  return out.toString();
}

/// Textos visíveis das telas ficam em lib/l10n/app_en.arb (base dos plugins de idioma).
/// Literais que não são texto para o usuário (chaves, nomes de fonte...) levam o comentário `l10n-ignore`.
void main() {
  test('nenhum texto para o usuário escrito direto no código das telas (lib/ui)', () {
    final literal = RegExp(r"'((?:[^'\\]|\\.)*)'" r'|"((?:[^"\\]|\\.)*)"');
    final interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');
    final words = RegExp(r'[A-Za-zÀ-ú]{2,}');
    final technical = RegExp(r'^(package:|dart:|assets/|https?://|\.\./)');
    final violations = <String>[];

    for (final f in Directory('lib/ui').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = const LineSplitter().convert(f.readAsStringSync());
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final t = line.trimLeft();
        if (t.startsWith('//') || t.startsWith('///') || t.startsWith('import ') || t.startsWith('export ')) continue;
        if (line.contains('l10n-ignore') || line.contains('debugPrint(') || line.contains('RegExp(')) continue;
        for (final m in literal.allMatches(_withoutInterpolations(line))) {
          final s = m.group(1) ?? m.group(2) ?? '';
          if (technical.hasMatch(s)) continue;
          if (words.hasMatch(s.replaceAll(interpolation, ''))) violations.add('${f.path}:${i + 1}: $s');
        }
      }
    }
    expect(violations, isEmpty, reason: 'mova estes textos para lib/l10n/app_en.arb:\n${violations.join('\n')}');
  });

  test('ignora o código dentro de \${...} (pode ter aspas e parênteses)', () {
    expect(_withoutInterpolations(r"'${a.padLeft(2, '0')}:${b ? 'x' : 'y'}'"), "':'");
  });

  test('app_en.arb é JSON válido e cada placeholder declarado aparece no texto', () {
    final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    expect(arb['@@locale'], 'en');
    for (final e in arb.entries.where((e) => e.key.startsWith('@') && !e.key.startsWith('@@'))) {
      final text = arb[e.key.substring(1)] as String;
      final placeholders = (e.value as Map<String, dynamic>)['placeholders'] as Map<String, dynamic>? ?? const {};
      for (final p in placeholders.keys) {
        expect(text.contains('{$p'), isTrue, reason: '${e.key}: {$p} não aparece em "$text"');
      }
    }
  });
}
