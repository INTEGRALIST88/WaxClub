/// Chaves do app WaxClub cadastrado no Discogs (discogs.com/settings/developers → "Create an Application").
///
/// Com elas, o usuário entra com a própria conta pela tela de login do Discogs (OAuth 1.0a).
/// Sem elas, a mesma tela aceita o "token pessoal" que o usuário gera na conta dele.
/// Podem vir do build: --dart-define=DISCOGS_CONSUMER_KEY=... --dart-define=DISCOGS_CONSUMER_SECRET=...
class DiscogsConfig {
  static const String consumerKey = String.fromEnvironment('DISCOGS_CONSUMER_KEY');
  static const String consumerSecret = String.fromEnvironment('DISCOGS_CONSUMER_SECRET');

  /// Endereço de retorno do login. O app intercepta a navegação para ele dentro do WebView,
  /// então não precisa existir de fato; deve ser o mesmo informado no cadastro do app no Discogs.
  static const String callbackUrl = 'https://waxclub.app/discogs-callback';

  static const String userAgent = 'WaxClub/1.3 +https://github.com/INTEGRALIST88/WaxClub';

  /// Página da conta onde o usuário gera o token pessoal (redireciona para o login se necessário).
  static const String personalTokenPage = 'https://www.discogs.com/settings/developers';

  static bool get hasAppKeys => consumerKey.isNotEmpty && consumerSecret.isNotEmpty;
}
