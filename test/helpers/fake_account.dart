import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/account/account_service.dart';

/// Conta WaxClub para os testes de tela: já logada (ou não) e com um servidor falso que responde o básico.
AccountService fakeAccount({bool signedIn = true, bool profileComplete = true}) {
  final user = {
    'id': 1,
    'email': 'tester@waxclub.com.br',
    'username': profileComplete ? 'tester' : null,
    'countryCode': profileComplete ? 'BR' : null,
    'stateCode': profileComplete ? '27' : null,
    'stateName': profileComplete ? 'São Paulo' : null,
    'cityId': profileComplete ? 3448439 : null,
    'city': profileComplete ? 'São Paulo' : null,
    'hasPassword': true,
    'google': false,
    'profileComplete': profileComplete,
  };
  final store = MemoryAccountStore();
  if (signedIn) {
    store.values['waxclub.account.token'] = 'wx_test';
    store.values['waxclub.account.user'] = jsonEncode(user);
  }
  final client = MockClient((r) async {
    final path = r.url.path.replaceFirst('/v1', '');
    final Object body = switch (path) {
      '/me' => {'user': user},
      '/collection' || '/collection/sync' => {'items': [], 'serverTime': '2026-01-01T00:00:00.000Z'},
      '/plays' => {'added': 0},
      '/geo/countries' => {
          'countries': [
            {'code': 'BR', 'name': 'Brazil', 'hasStates': true},
          ],
        },
      _ => {'error': 'not_found'},
    };
    return http.Response(jsonEncode(body), body is Map && body.containsKey('error') ? 404 : 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });
  return AccountService(baseUrl: 'https://api.test/v1', store: store, client: client);
}
