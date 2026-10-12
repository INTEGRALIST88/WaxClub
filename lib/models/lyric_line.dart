/// Representa uma linha individual de letra sincronizada (.lrc).
class LyricLine {
  /// O timestamp em que a estrofe/linha começa a ser cantada.
  final Duration timestamp;

  /// O texto correspondente à linha da letra.
  final String text;

  /// Duração estimada até a próxima linha (opcional).
  final Duration? duration;

  LyricLine({
    required this.timestamp,
    required this.text,
    this.duration,
  });

  /// Indica se esta linha representa uma pausa instrumental ou silêncio.
  bool get isInstrumental => text.trim().isEmpty || text.trim() == '♪' || text.trim().toLowerCase() == '[instrumental]';

  /// Retorna o timestamp formatado no padrão [mm:ss.xx].
  String get formattedTimestamp {
    final minutes = timestamp.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = timestamp.inSeconds.remainder(60).toString().padLeft(2, '0');
    final centiseconds = (timestamp.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '[$minutes:$seconds.$centiseconds]';
  }

  @override
  String toString() => '$formattedTimestamp $text';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricLine &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          text == other.text;

  @override
  int get hashCode => timestamp.hashCode ^ text.hashCode;
}
