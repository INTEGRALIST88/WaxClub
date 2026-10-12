import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/app_info.dart';

void main() {
  test('kAppVersion coincide com a versão declarada no pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    // Versão exibida pode omitir o '.0' final exigido pelo pubspec (ex.: 1.3.0 -> 1.3)
    expect(kAppVersion, equals(match!.group(1)!.replaceFirst(RegExp(r'\.0$'), '')));
  });
}
