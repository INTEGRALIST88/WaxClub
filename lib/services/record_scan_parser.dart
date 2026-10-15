/// Interpretação do que a câmera leu: código de barras e números de catálogo.
class RecordScanParser {
  RecordScanParser._();

  /// Código de barras de disco válido (EAN-13, EAN-8, UPC-A ou UPC-E), conferindo o dígito verificador.
  static bool isValidBarcode(String raw) {
    final code = raw.replaceAll(RegExp(r'\D'), '');
    if (code.length == 6 || code.length == 7) return true; // UPC-E (sem verificação completa)
    if (code.length != 8 && code.length != 12 && code.length != 13) return false;
    final digits = code.split('').map(int.parse).toList();
    final check = digits.removeLast();
    var sum = 0;
    for (var i = 0; i < digits.length; i++) {
      // da direita para a esquerda: peso 3, 1, 3, 1...
      final fromRight = digits.length - 1 - i;
      sum += digits[i] * (fromRight.isEven ? 3 : 1);
    }
    return (10 - sum % 10) % 10 == check;
  }

  /// Números de catálogo prováveis no texto lido do selo, da lombada ou da contracapa
  /// (ex.: "6349 123", "SHVL 804", "LPGW-4", "MOFI 1-034"). No máximo [max], na ordem em que aparecem.
  static List<String> catalogNumberCandidates(String text, {int max = 6}) {
    final out = <String>[];
    final seen = <String>{};
    final token = RegExp(r'\b([A-Z]{1,6}[ .-]?\d[\dA-Z.-]{0,9}|\d{2,6}[ .-]\d{2,6}(?:[ .-]\d{1,4})?|\d{4,9})\b');
    for (final raw in text.toUpperCase().split(RegExp(r'[\r\n]+'))) {
      final line = raw.trim();
      for (final m in token.allMatches(line)) {
        final c = m.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (!_plausible(c)) continue;
        if (seen.add(c)) out.add(c);
        if (out.length >= max) return out;
      }
    }
    return out;
  }

  /// Códigos de barras válidos escritos no texto da foto (ex.: "PIASC0999DLP / 5400863170370." ou
  /// os números sob as barras, "5 400863 170370"), sem repetir.
  static List<String> barcodesIn(String text) {
    final out = <String>[];
    for (final m in RegExp(r'\d[\d ]{6,18}\d').allMatches(text)) {
      final digits = m.group(0)!.replaceAll(' ', '');
      if ((digits.length == 12 || digits.length == 13) && isValidBarcode(digits) && !out.contains(digits)) {
        out.add(digits);
      }
    }
    return out;
  }

  static bool _plausible(String c) {
    final digits = c.replaceAll(RegExp(r'\D'), '');
    final hasLetters = RegExp(r'[A-Z]').hasMatch(c);
    // Com letras ("LPGW-4", "SHVL 804"): ao menos 4 caracteres; só números: ao menos 3 dígitos
    if (c.length > 16 || (hasLetters ? c.length < 4 : digits.length < 3)) return false;
    if (RegExp(r'^(19|20)\d\d$').hasMatch(c)) return false; // ano
    if (RegExp(r'^\d{1,2}[.:]\d{2}$').hasMatch(c)) return false; // duração 3:45 / 3.45
    if (RegExp(r'^(RPM|STEREO|MONO|SIDE|LADO)').hasMatch(c)) return false;
    if (RegExp(r'^\d{8,}$').hasMatch(c) && isValidBarcode(c)) return false; // é o código de barras
    return true;
  }
}
