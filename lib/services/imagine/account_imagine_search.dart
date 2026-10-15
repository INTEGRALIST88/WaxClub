import 'dart:math';
import '../account/account_service.dart';
import 'imagined_music.dart';

/// Busca de fotos do A3 pela API do WaxClub (`/v1/imagine`), que consulta o Unsplash com a chave do servidor.
class AccountImagineSearch implements ImagineSearch {
  final AccountService account;
  AccountImagineSearch(this.account);

  static final _random = Random();

  @override
  Future<List<ImaginePhoto>> search(String query) async =>
      [for (final p in await account.imagineSearch(query)) ImaginePhoto.fromJson(p)];

  @override
  Future<List<ImaginePhoto>> searchArt(String query) async =>
      [for (final a in await account.imagineArt(query)) ImaginePhoto.fromArt(a)];

  /// Fotos do Unsplash pelas buscas fixas do sentimento, intercaladas e embaralhadas, mais as obras do
  /// acervo marcadas com o sentimento (se houver). Uma busca que falhar não derruba as outras.
  @override
  Future<List<ImaginePhoto>> searchEmotion(String emotion) async {
    final lists = <List<ImaginePhoto>>[];
    Object? lastError;
    for (final q in ImagineScene.emotionQueries[emotion] ?? const <String>[]) {
      try {
        lists.add(await search(q));
      } catch (e) {
        lastError = e;
      }
    }
    try {
      lists.add([for (final a in await account.imagineEmotion(emotion)) ImaginePhoto.fromArt(a)]);
    } catch (_) {} // acervo de sentimentos ainda vazio ou indisponível
    final all = [for (final l in lists) ...l];
    if (all.isEmpty && lastError != null) throw lastError;
    return all..shuffle(_random);
  }

  @override
  Future<void> used(ImaginePhoto photo) async {
    if (photo.isArt) return; // obras do acervo não têm aviso de uso
    final d = photo.download;
    if (d != null && d.isNotEmpty) await account.imagineUsed(d);
  }
}
