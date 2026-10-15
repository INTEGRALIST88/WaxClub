/// Nome do aplicativo e sufixo exibidos na interface.
const String kAppName = 'WaxClub';
const String kAppTagline = 'Vinyl Social Club';

/// Versão do aplicativo exibida na interface.
/// Deve coincidir com o campo `version` do pubspec.yaml (validado em test/app_info_test.dart).
const String kAppVersion = '1.4.19';

/// ID do cliente "Aplicativo da Web" do projeto Google Cloud "waxclub" (público). O login com Google
/// pede o idToken para este ID, e a API (api.waxclub.com.br) confere o token com o Google.
/// O cliente Android (pacote com.waxclub.app + SHA-1 da chave de assinatura) fica registrado no mesmo projeto.
const String kGoogleServerClientId = '191594960482-stdsa9ahvrou6k025ftecf5vhs2pj1ll.apps.googleusercontent.com';