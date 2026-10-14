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

  String _time(int t) => DateTime.utc(2026, 1, 1).add(Duration(seconds: t)).toIso8601String();

  Future<http.Response> handle(http.Request r) async {
    calls.add('${r.method} ${r.url.path}');
    final body = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;
    final authed = r.headers['Authorization'] == 'Bearer wx_test';
    http.Response json(int s, Object o) =>
        http.Response(jsonEncode(o), s, headers: {'content-type': 'application/json; charset=utf-8'});
    final path = r.url.path.replaceFirst('/v1', '');
    if (path == '/auth/email/start') {
      return (body['email'] as String).contains('@') ? json(200, {'sent': true}) : json(422, {'error': 'invalid_email'});
    }
    if (path == '/auth/email/verify') {
      return body['code'] == '123456'
          ? json(200, {
              'token': 'wx_test',
              'user': {'id': 7, 'email': body['email']},
            })
          : json(401, {'error': 'invalid_code', 'attemptsLeft': 4});
    }
    if (!authed || expireSession) return json(401, {'error': 'unauthorized'});
    if (path == '/me') return json(200, {'user': {'id': 7, 'email': 'a@b.com'}});
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

  test('código errado mostra o erro da API; código certo abre a sessão e guarda o token', () async {
    await expectLater(account.requestCode('sem-arroba'), throwsA(isA<AccountApiException>().having((e) => e.code, 'code', 'invalid_email')));
    await account.requestCode('a@b.com');
    await expectLater(account.verifyCode('a@b.com', '000000'),
        throwsA(isA<AccountApiException>().having((e) => e.attemptsLeft, 'attemptsLeft', 4)));
    expect(account.isSignedIn, isFalse);

    await account.verifyCode('a@b.com', '123456');
    await settle(account);
    expect(account.isSignedIn, isTrue);
    expect(account.account!.email, 'a@b.com');
    expect(store.values['waxclub.account.token'], 'wx_test');
  });

  test('primeira sincronização envia a coleção e as audições do aparelho', () async {
    await collection.add(disc('Abbey Road'));
    await collection.add(disc('Revolver'));
    await collection.recordTrackPlay(album: 'Abbey Road', artist: 'Artist', track: 'Come Together');
    await account.verifyCode('a@b.com', '123456');
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
    await account.verifyCode('a@b.com', '123456');
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
    await account.verifyCode('a@b.com', '123456');
    await settle(account);
    api.expireSession = true;
    expect(await account.sync(), isFalse);
    expect(account.isSignedIn, isFalse);
    expect(store.values.containsKey('waxclub.account.token'), isFalse);
  });

  test('sessão salva é retomada ao abrir o app', () async {
    await account.verifyCode('a@b.com', '123456');
    await settle(account);
    final again = AccountService(baseUrl: 'https://api.test/v1', store: store, client: MockClient(api.handle));
    await again.load();
    expect(again.isSignedIn, isTrue);
    expect(again.account!.id, 7);
    again.dispose();
  });
}
