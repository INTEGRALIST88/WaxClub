import '../account/account_service.dart';
import 'imagined_music.dart';

/// Busca de fotos do A3 pela API do WaxClub (`/v1/imagine`), que consulta o Unsplash com a chave do servidor.
class AccountImagineSearch implements ImagineSearch {
  final AccountService account;
  AccountImagineSearch(this.account);

  @override
  Future<List<ImaginePhoto>> search(String query) async =>
      [for (final p in await account.imagineSearch(query)) ImaginePhoto.fromJson(p)];

  @override
  Future<List<ImaginePhoto>> searchArt(String query) async =>
      [for (final a in await account.imagineArt(query)) ImaginePhoto.fromArt(a)];

  @override
  Future<List<ImaginePhoto>> searchEmotion(String emotion) async =>
      [for (final a in await account.imagineEmotion(emotion)) ImaginePhoto.fromArt(a)];

  @override
  Future<void> used(ImaginePhoto photo) async {
    if (photo.isArt) return; // obras do acervo não têm aviso de uso
    final d = photo.download;
    if (d != null && d.isNotEmpty) await account.imagineUsed(d);
  }
}
