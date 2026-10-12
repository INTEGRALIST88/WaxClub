/// Representa uma faixa com informações de catálogo (ordem, número, lado e duração).
class TrackEntry {
  /// Posição global sequencial de reprodução no disco (1-based: 1, 2, 3...)
  final int position;

  /// Título da faixa
  final String title;

  /// Identificador original do catálogo (ex: "A1", "B3", "7")
  final String? number;

  /// Lado físico do disco ("A", "B", "C", "D"...) se identificado; null se desconhecido
  final String? side;

  /// Duração em milissegundos, se disponível
  final int? lengthMs;

  /// Artista da faixa quando difere do artista do disco (coletâneas, trilhas de novela)
  final String? artist;

  const TrackEntry({
    required this.position,
    required this.title,
    this.number,
    this.side,
    this.lengthMs,
    this.artist,
  });

  TrackEntry copyWith({
    int? position,
    String? title,
    String? number,
    String? side,
    int? lengthMs,
    String? artist,
  }) {
    return TrackEntry(
      position: position ?? this.position,
      title: title ?? this.title,
      number: number ?? this.number,
      side: side ?? this.side,
      lengthMs: lengthMs ?? this.lengthMs,
      artist: artist ?? this.artist,
    );
  }

  factory TrackEntry.fromJson(Map<String, dynamic> json) {
    String? derivedSide = json['side'] as String?;
    final numStr = json['number']?.toString();
    if (derivedSide == null && numStr != null) {
      final match = RegExp(r'^([A-Za-z]+)\d+$').firstMatch(numStr.trim());
      if (match != null) {
        derivedSide = match.group(1)!.toUpperCase();
      }
    }

    return TrackEntry(
      position: (json['position'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      number: numStr,
      side: derivedSide,
      lengthMs: (json['lengthMs'] as num?)?.toInt(),
      artist: json['artist'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'position': position,
      'title': title,
      if (number != null) 'number': number,
      if (side != null) 'side': side,
      if (lengthMs != null) 'lengthMs': lengthMs,
      if (artist != null) 'artist': artist,
    };
  }

  @override
  String toString() => 'TrackEntry(pos: $position, number: $number, side: $side, title: "$title")';
}
