import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/discogs/discogs_auth_service.dart';

void main() {
  const token = 'abcdefghijABCDEFGHIJ0123456789klmnopqrst'; // 40 letras e números, como os do Discogs

  test('página em português: "Token atual:" com o token na linha de baixo', () {
    const page = 'Cadastre seu aplicativo agora!\nCriar uma aplicação\nVocê só precisa de um token de acesso pessoal?\n'
        'Gerar novo token\nExcluir Token\nI have read and agree to the Discogs API Terms of Use.\n'
        'Token atual:\n$token\nVer também\nAPI Documentation';
    expect(DiscogsAuthService.tokenFromPageText(page), token);
  });

  test('página em inglês: "Your current token:"', () {
    expect(DiscogsAuthService.tokenFromPageText('Generate new token\nYour current token: $token\nSee also'), token);
  });

  test('outro idioma: linha só com o token', () {
    expect(DiscogsAuthService.tokenFromPageText('Jeton actuel\n$token\n'), token);
  });

  test('página do token reconhecida em qualquer idioma (antes, /pt_BR/ ficava de fora)', () {
    expect(DiscogsAuthService.isTokenPage('https://www.discogs.com/settings/developers'), isTrue);
    expect(DiscogsAuthService.isTokenPage('https://www.discogs.com/pt_BR/settings/developers'), isTrue);
    expect(DiscogsAuthService.isTokenPage('https://www.discogs.com/de/settings/developers/'), isTrue);
    expect(DiscogsAuthService.isTokenPage('https://www.discogs.com/pt_BR/settings/user'), isFalse);
    expect(DiscogsAuthService.isTokenPage('https://www.discogs.com/login?return_to=%2Fsettings%2Fdevelopers'), isFalse);
    expect(DiscogsAuthService.isTokenPage('https://evil.example.com/settings/developers'), isFalse);
  });

  test('sem token gerado na conta: nulo (o app mostra as instruções)', () {
    expect(DiscogsAuthService.tokenFromPageText('Gerar novo token\nI have read and agree to the Discogs API Terms of Use.'),
        isNull);
  });
}
