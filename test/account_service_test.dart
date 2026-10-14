import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/account/account_service.dart';
import 'package:waxclub/services/collection_service.dart';

/// Servidor falso com as mesmas regras da API (o mais recente vence; ?since pela hora do servidor).
class FakeApi {
  final Map<String, Map<String, dynamic>> items = {};
  final List<Map<String, dynamic>> plays = [];
  final List<String> calls = [];
  int clock = 1000;
  bool expireSession = false;
  Map<String, dynamic>? registered;
  Map<String, dynamic> user = {'id': 7, 'email': 'a@b.com', 'username': 'vinylfan', 'profileComplete': true};

  String _time(int t) => DateTime.utc(2026, 1, 1).add(Duration(seconds: t)).toIso8601String();

  Future<http.Response> handle(http.Request r) async {
    calls.add('${r.method} ${r.url.path}');
    final body = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;
    final authed = r.headers['Authorization'] == 'Bearer wx_test';
    http.Response json(int s, Object o) =>
        http.Response(jsonEncode(o), s, headers: {'content-type': 'application/json; charset=utf-8'});
    final path = r.url.path.replaceFirst('/v1', '');
    final session = {'token': 'wx_test', 'user': user};
    if (path == '/auth/register') {
      registered = body;
      return json(200, {'pending': 'verify_email', 'email': body['email']});
    }
    if (path == '/auth/verify-email') {
      return body['code'] == '123456' ? json(200, session) : json(401, {'error': 'invalid_code', 'attemptsLeft': 4});
    }
    if (path == '/auth/login') {
      if (body['email'] == 'new@b.com') return json(403, {'error': 'email_not_verified'});
      return body['password'] == 'password1' ? json(200, session) : json(401, {'error': 'invalid_credentials'});
    }
    if (path == '/auth/username-available') {
      final u = r.url.queryParameters['u']!;
      return json(200, {'valid': u.length >= 3, 'available': u != 'taken'});
    }
    if (path == '/geo/states') {
      return json(200, {
        'states': [
          {'code': '27', 'name': 'São Paulo'},
        ],
      });
    }
    if (path == '/geo/cities') {
      return json(200, {
        'cities': [
          {'id': 3467865, 'name': 'Campinas', 'stateCode': '27'},
        ],
      });
    }
    if (!authed || expireSession) return json(401, {'error': 'unauthorized'});
    if (path == '/me' && r.method == 'PATCH') {
      user = {...user, 'username': body['username'], 'countryCode': body['countryCode'], 'cityId': body['cityId'], 'profileComplete': true};
      return json(200, {'user': user});
    }
    if (path == '/me') return json(200, {'user': user});
    if (path == '/auth/logout') return json(200, {'ok': true});
    if (path == '/collection/sync') {
      final out = [];
      for (final it in (body['items'] as List).cast<Map<String, dynamic>>()) {
        final key = it['key'] as String;
        final cur = items[key];
        if (cur == null || (cur['updatedAt'] as String).compareTo(it['updatedAt'] as String) < 0) {
          items[key] = {...it, 'deleted': it['deleted'] == true, '_synced': ++clock};
        }
        out.add(items[key]);
      }
      return json(200, {'items': out, 'serverTime': _time(clock)});
    }
    if (path == '/collection') {
      final since = r.url.queryParameters['since'];
      final now = ++clock;
      final list = items.values
          .where((i) => since == null ? i['deleted'] != true : _time(i['_synced'] as int).compareTo(since) > 0)
          .toList();
      return json(200, {'items': list, 'serverTime': _time(now)});
    }
    if (path == '/plays') {
      plays.addAll((body['plays'] as List).cast<Map<String, dynamic>>());
      return json(200, {'added': (body['plays'] as List).length});
    }
    return json(404, {'error': 'not_found'});
  }
}

/// O login dispara a primeira sincronização em segundo plano; espera ela terminar.
Future<void> settle(AccountService a) async {
  await Future<void>.delayed(Duration.zero);
  while (a.isSyncing) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory dir;
  late FakeApi api;
  late CollectionService collection;
  late MemoryAccountStore store;
  late AccountService account;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('waxclub_account_');
    api = FakeApi();
    collection = CollectionService(directory: dir);
    await collection.load();
    store = MemoryAccountStore();
    account = AccountService(baseUrl: 'https://api.test/v1', store: store, client: MockClient(api.handle));
    account.attachCollection(collection);
  });

  tearDown(() async {
    account.dispose();
    await dir.delete(recursive: true);
  });

  CollectionItem disc(String album, {String artist = 'Artist'}) =>
      CollectionItem(album: album, artist: artist, addedAt: DateTime(2026, 1, 1));

  test('senha errada mostra o erro da API; senha certa abre a sessão e guarda o token', () async {
    await expectLater(account.login('a@b.com', 'errada'),
        throwsA(isA<AccountApiException>().having((e) => e.code, 'code', 'invalid_credentials')));
    expect(account.isSignedIn, isFalse);

    await account.login('a@b.com', 'password1');
    await settle(account);
    expect(account.isSignedIn, isTrue);
    expect(account.account!.username, 'vinylfan');
    expect(store.values['waxclub.account.token'], 'wx_test');
  });

  test('cadastro envia nome de usuário e local; o código do e-mail confirma e entra na conta', () async {
    final location = LocationChoice(
      country: const GeoCountry('BR', 'Brazil', hasStates: true),
      state: const GeoState('27', 'São Paulo'),
      city: const GeoCity(3467865, 'Campinas', '27'),
    );
    await account.register(email: 'new@b.com', password: 'password1', username: 'NewFan', location: location);
    expect(api.registered, containsPair('username', 'NewFan'));
    expect(api.registered, containsPair('countryCode', 'BR'));
    expect(api.registered, containsPair('stateCode', '27'));
    expect(api.registered, containsPair('cityId', 3467865));
    expect(account.isSignedIn, isFalse, reason: 'só entra depois de confirmar o e-mail');

    await expectLater(account.verifyEmail('new@b.com', '000000'),
        throwsA(isA<AccountApiException>().having((e) => e.attemptsLeft, 'attemptsLeft', 4)));
    await account.verifyEmail('new@b.com', '123456');
    await settle(account);
    expect(account.isSignedIn, isTrue);
  });

  test('login de conta não confirmada avisa email_not_verified', () async {
    await expectLater(account.login('new@b.com', 'password1'),
        throwsA(isA<AccountApiException>().having((e) => e.code, 'code', 'email_not_verified')));
  });

  test('listas do cadastro e perfil: estados, cidades, nome livre/ocupado e atualização do perfil', () async {
    expect((await account.states('BR')).single.name, 'São Paulo');
    expect((await account.cities('BR', stateCode: '27', query: 'camp')).single.id, 3467865);
    expect(await account.usernameAvailable('vinylfan2'), isTrue);
    expect(await account.usernameAvailable('taken'), isFalse);
    expect(await account.usernameAvailable('ab'), isNull);

    api.user = {'id': 7, 'email': 'a@b.com', 'profileComplete': false};
    await account.login('a@b.com', 'password1');
    await settle(account);
    expect(account.account!.profileComplete, isFalse);
    await account.updateProfile(
      username: 'vinylfan',
      location: const LocationChoice(country: GeoCountry('BR', 'Brazil'), city: GeoCity(3467865, 'Campinas', '27')),
    );
    expect(account.account!.profileComplete, isTrue);
  });
  test('primeira sincronização envia a coleção e as audições do aparelho', () async {
    await collection.add(disc('Abbey Road'));
    await collection.add(disc('Revolver'));
    await collection.recordTrackPlay(album: 'Abbey Road', artist: 'Artist', track: 'Come Together');
    await account.login('a@b.com', 'password1');
    await settle(account);
    expect(await account.sync(), isTrue);

    expect(api.items.length, 2);
    expect(api.items.values.map((i) => i['album']), containsAll(['Abbey Road', 'Revolver']));
    expect(api.plays.single['track'], 'Come Together');
    expect(account.lastSyncAt, isNotNull);

    // nada mudou: a próxima sincronização não reenvia nada
    api.calls.clear();
    await account.sync();
    expect(api.calls.where((c) => c.contains('/collection/sync') || c.contains('/plays')), isEmpty);
  });

  test('remoção no aparelho apaga na conta; disco vindo de outro aparelho entra na coleção', () async {
    await collection.add(disc('Abbey Road'));
    await account.login('a@b.com', 'password1');
    await settle(account);
    await account.sync();

    await collection.remove('Abbey Road', 'Artist');
    final key = CollectionService.keyFor('Thriller', 'Michael Jackson');
    api.items[key] = {
      'key': key,
      'album': 'Thriller',
      'artist': 'Michael Jackson',
      'addedAt': DateTime.utc(2026, 2, 1).toIso8601String(),
      'updatedAt': DateTime.utc(2026, 2, 1).toIso8601String(),
      'deleted': false,
      'rating': 5,
      '_synced': ++api.clock,
    };
    await account.sync();

    expect(api.items[CollectionService.keyFor('Abbey Road', 'Artist')]!['deleted'], isTrue);
    expect(collection.contains('Abbey Road', 'Artist'), isFalse);
    expect(collection.itemFor('Thriller', 'Michael Jackson')!.rating, 5);
  });

  test('versão mais antiga do servidor não sobrescreve a alteração local mais nova', () async {
    await collection.add(disc('Kind of Blue'));
    final local = collection.itemFor('Kind of Blue', 'Artist')!;
    await collection.applyRemote(upserts: [
      CollectionItem.fromJson({...local.toJson(), 'notes': 'old', 'updatedAt': DateTime(2020).toIso8601String()}),
    ]);
    expect(collection.itemFor('Kind of Blue', 'Artist')!.notes, isNull);
    await collection.applyRemote(deletions: {local.key: DateTime(2020)});
    expect(collection.contains('Kind of Blue', 'Artist'), isTrue);
  });

  test('sessão expirada no servidor sai da conta no aparelho', () async {
    await account.login('a@b.com', 'password1');
    await settle(account);
    api.expireSession = true;
    expect(await account.sync(), isFalse);
    expect(account.isSignedIn, isFalse);
    expect(store.values.containsKey('waxclub.account.token'), isFalse);
  });

  test('sessão salva é retomada ao abrir o app', () async {
    await account.login('a@b.com', 'password1');
    await settle(account);
    final again = AccountService(baseUrl: 'https://api.test/v1', store: store, client: MockClient(api.handle));
    await again.load();
    expect(again.isSignedIn, isTrue);
    expect(again.account!.id, 7);
    again.dispose();
  });
}
