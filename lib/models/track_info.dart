/// Modelo de dados representando as informações da música reconhecida.
class TrackInfo {
  /// Nome da faixa / música.
  final String title;

  /// Nome do artista / banda.
  final String artist;

  /// Álbum (se disponível).
  final String? album;

  /// URL da capa do álbum (cover art).
  final String? coverUrl;

  /// Offset temporal em segundos retornado pelo reconhecimento do áudio.
  final double offsetSeconds;

  /// Duração total estimada em milissegundos (se disponível).
  final int? durationMs;

  /// Conteúdo bruto das letras (.lrc ou texto puro).
  final String? lrcContent;

  /// Indica se o álbum e a capa física desta faixa estão travados para a sessão.
  final bool isAlbumLocked;

  const TrackInfo({
    required this.title,
    required this.artist,
    this.album,
    this.coverUrl,
    required this.offsetSeconds,
    this.durationMs,
    this.lrcContent,
    this.isAlbumLocked = false,
  });

  TrackInfo copyWith({
    String? title,
    String? artist,
    String? album,
    String? coverUrl,
    double? offsetSeconds,
    int? durationMs,
    String? lrcContent,
    bool? isAlbumLocked,
  }) {
    return TrackInfo(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverUrl: coverUrl ?? this.coverUrl,
      offsetSeconds: offsetSeconds ?? this.offsetSeconds,
      durationMs: durationMs ?? this.durationMs,
      lrcContent: lrcContent ?? this.lrcContent,
      isAlbumLocked: isAlbumLocked ?? this.isAlbumLocked,
    );
  }

  @override
  String toString() => '$artist - $title (offset: ${offsetSeconds.toStringAsFixed(2)}s)';
}
