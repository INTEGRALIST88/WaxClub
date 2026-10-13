/// Estados de conservação do Discogs (mesmos valores da API, em inglês, como no site).
class DiscogsGrades {
  DiscogsGrades._();

  /// Disco (media).
  static const List<String> media = [
    'Mint (M)',
    'Near Mint (NM or M-)',
    'Very Good Plus (VG+)',
    'Very Good (VG)',
    'Good Plus (G+)',
    'Good (G)',
    'Fair (F)',
    'Poor (P)',
  ];

  /// Capa (sleeve): os mesmos, mais capa genérica e sem capa.
  static const List<String> sleeve = [...media, 'Generic', 'Not Graded', 'No Cover'];
}
