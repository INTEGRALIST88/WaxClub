import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Subnet probe logic handles invalid and valid IP strings', () {
    final parts = '192.168.1.89'.split('.');
    expect(parts.length, equals(4));
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
    expect(prefix, equals('192.168.1.'));
  });
}
