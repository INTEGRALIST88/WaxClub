import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/lrc_parser.dart';

void main() {
  group('LrcParser Tests', () {
    const sampleLrc = '''
[ti:Bohemian Rhapsody]
[ar:Queen]
[00:00.15] Is this the real life? Is this just fantasy?
[00:07.13] Caught in a landslide, no escape from reality
[00:14.77] Open your eyes, look up to the skies and see
[00:25.37] I'm just a poor boy, I need no sympathy
[00:30.75] Because I'm easy come, easy go, little high, little low
''';

    test('deve realizar o parse correto das linhas ignorando metadados', () {
      final lines = LrcParser.parse(sampleLrc);

      expect(lines.length, equals(5));
      expect(lines[0].text, equals('Is this the real life? Is this just fantasy?'));
      expect(lines[0].timestamp, equals(const Duration(milliseconds: 150)));

      expect(lines[2].text, equals('Open your eyes, look up to the skies and see'));
      expect(lines[2].timestamp, equals(const Duration(seconds: 14, milliseconds: 770)));
    });

    test('deve calcular a duração de cada linha em relação à próxima', () {
      final lines = LrcParser.parse(sampleLrc);

      expect(lines[0].duration, equals(const Duration(seconds: 6, milliseconds: 980)));
    });

    test('findActiveIndex deve retornar o índice correto da estrofe ativa', () {
      final lines = LrcParser.parse(sampleLrc);

      // Antes da música começar
      expect(LrcParser.findActiveIndex(lines, Duration.zero), equals(-1));

      // No meio da primeira estrofe (3s)
      expect(LrcParser.findActiveIndex(lines, const Duration(seconds: 3)), equals(0));

      // Exatamente no início da 3ª estrofe (14.77s)
      expect(LrcParser.findActiveIndex(lines, const Duration(seconds: 14, milliseconds: 770)), equals(2));

      // No meio da 4ª estrofe (26s)
      expect(LrcParser.findActiveIndex(lines, const Duration(seconds: 26)), equals(3));

      // Após a última estrofe
      expect(LrcParser.findActiveIndex(lines, const Duration(seconds: 40)), equals(4));
    });

    test('deve suportar timestamps com 3 dígitos fracionários [mm:ss.xxx]', () {
      const lrc3digits = '[01:15.500] Linha com 3 digitos fracionarios';
      final lines = LrcParser.parse(lrc3digits);

      expect(lines.length, equals(1));
      expect(lines.first.timestamp, equals(const Duration(minutes: 1, seconds: 15, milliseconds: 500)));
    });

    test('deve converter letra em texto plano distribuindo timestamps proporcionais', () {
      const plainLyrics = '''
Linha um da musica
Linha dois da musica
Linha tres da musica
''';
      final lines = LrcParser.parse(plainLyrics, estimatedDurationSeconds: 60.0);

      expect(lines.length, equals(3));
      expect(lines[0].text, equals('Linha um da musica'));
      expect(lines[0].timestamp, equals(Duration.zero));
      expect(lines[1].text, equals('Linha dois da musica'));
      expect(lines[2].text, equals('Linha tres da musica'));
      expect(lines[2].timestamp, equals(const Duration(seconds: 40)));
    });

    test('deve aplicar tag [offset:±ms] adiantando ou atrasando a letra', () {
      const lrcWithOffset = '''
[offset:+500]
[00:05.00] Linha adiantada em 500ms
''';
      final lines = LrcParser.parse(lrcWithOffset);
      expect(lines.length, equals(1));
      expect(lines[0].timestamp, equals(const Duration(seconds: 4, milliseconds: 500)));

      const lrcWithNegativeOffset = '''
[offset:-300]
[00:05.00] Linha atrasada em 300ms
''';
      final linesNeg = LrcParser.parse(lrcWithNegativeOffset);
      expect(linesNeg.length, equals(1));
      expect(linesNeg[0].timestamp, equals(const Duration(seconds: 5, milliseconds: 300)));
    });

    test('deve remover tags inline de palavra <mm:ss.xx> do texto', () {
      const lrcInline = '[00:10.00] Palavra1 <00:10.50> Palavra2 <00:11.00> Palavra3';
      final lines = LrcParser.parse(lrcInline);
      expect(lines.length, equals(1));
      expect(lines[0].text, equals('Palavra1 Palavra2 Palavra3'));
    });

    test('deve suportar minutos de 1 dígito e separador de fração com dois pontos', () {
      const lrcFlexible = '[1:05:40] Minuto de 1 digito e fracao com colon';
      final lines = LrcParser.parse(lrcFlexible);
      expect(lines.length, equals(1));
      expect(lines[0].timestamp, equals(const Duration(minutes: 1, seconds: 5, milliseconds: 400)));
    });

    test('deve descartar estrofes duplicadas idênticas mantendo marcadores vazios', () {
      const lrcDupes = '''
[00:05.00] Linha repetida
[00:05.00] Linha repetida
[00:10.00] 
[00:15.00] Proxima linha
''';
      final lines = LrcParser.parse(lrcDupes);
      expect(lines.length, equals(3));
      expect(lines[0].text, equals('Linha repetida'));
      expect(lines[1].text, equals('')); // Marcador instrumental mantido
      expect(lines[2].text, equals('Proxima linha'));
    });
  });
}
