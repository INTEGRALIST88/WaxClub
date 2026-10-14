import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/cloud/cloud_folder.dart';
import 'package:waxclub/services/cloud/dropbox_folder.dart';
import 'package:waxclub/services/cloud/google_drive_folder.dart';
import 'package:waxclub/services/cloud/onedrive_folder.dart';
import 'package:waxclub/services/local_lyrics_library.dart';

/// Pasta do app no Dropbox, em memória.
class _Folder implements LyricsFolderSource {
  @override
  final String cloudId;
  _Folder([this.cloudId = 'dropbox']);
  final Map<String, ({String rev, String content})> files = {};
  int downloads = 0;

  @override
  Future<List<CloudFile>> listAppFolder() async => [
        for (final e in files.entries)
          CloudFile(id: e.key, path: e.key, name: e.key.split('/').last, rev: e.value.rev, size: e.value.content.length),
      ];

  @override
  Future<String> download(CloudFile file) async {
    downloads++;
    return files[file.id]!.content;
  }
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('waxclub_dropbox_'));
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('PKCE: desafio S256 do RFC 7636 e cabeçalho com acentos escapados', () {
    expect(Pkce.challenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    expect(DropboxFolder.headerJson({'path': '/Elis Regina - Águas de Março.lrc'}),
        '{"path":"/Elis Regina - \\u00c1guas de Mar\\u00e7o.lrc"}');
  });

  test('login: troca o código pelo acesso (com o mesmo state) e guarda; state diferente é recusado', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add(req.url.path);
      if (req.url.path == '/oauth2/token') {
        expect(req.bodyFields['client_id'], 'chave');
        expect(req.bodyFields['grant_type'], 'authorization_code');
        expect(req.bodyFields['code_verifier'], isNotEmpty);
        return http.Response(jsonEncode({'access_token': 'A1', 'refresh_token': 'R1', 'expires_in': 14400}), 200);
      }
      if (req.url.path == '/2/users/get_current_account') {
        return http.Response(jsonEncode({'name': {'display_name': 'Gustavo'}}), 200);
      }
      return http.Response('', 404);
    });
    final store = MemoryCloudTokenStore();
    final d = DropboxFolder(store: store, client: client, appKey: 'chave');

    final url = d.authorizeUrl();
    expect(url.queryParameters['token_access_type'], 'offline');
    expect(url.queryParameters['code_challenge_method'], 'S256');
    final state = url.queryParameters['state']!;
    expect(await d.finishLogin(Uri.parse('${DropboxConfig.redirectUri}?code=X&state=errado')), isFalse);

    d.authorizeUrl();
    final url2 = d.authorizeUrl();
    expect(url2.queryParameters['state'], isNot(state));
    expect(await d.finishLogin(Uri.parse('${DropboxConfig.redirectUri}?code=X&state=${url2.queryParameters['state']}')), isTrue);
    expect(d.isConnected, isTrue);
    expect(d.accountName, 'Gustavo');

    final again = DropboxFolder(store: store, client: client, appKey: 'chave');
    await again.load();
    expect(again.isConnected, isTrue, reason: 'fica salvo no aparelho');
  });

  test('acesso vencido é renovado pelo refresh token antes de listar a pasta', () async {
    final store = MemoryCloudTokenStore()
      ..values['waxclub_dropbox'] = jsonEncode({'refresh': 'R1', 'access': 'velho', 'expires': '2000-01-01T00:00:00Z'});
    String? usedToken;
    final client = MockClient((req) async {
      if (req.url.path == '/oauth2/token') {
        expect(req.bodyFields['grant_type'], 'refresh_token');
        return http.Response(jsonEncode({'access_token': 'novo', 'expires_in': 14400}), 200);
      }
      if (req.url.path == '/2/files/list_folder') {
        usedToken = req.headers['Authorization'];
        return http.Response(
            jsonEncode({
              'entries': [
                {'.tag': 'file', 'name': 'A - B.lrc', 'path_display': '/A - B.lrc', 'rev': '1', 'size': 10},
                {'.tag': 'folder', 'name': 'Pasta', 'path_display': '/Pasta'},
              ],
              'has_more': false,
            }),
            200);
      }
      return http.Response('', 404);
    });
    final d = DropboxFolder(store: store, client: client, appKey: 'chave');
    await d.load();
    final files = await d.listAppFolder();
    expect(usedToken, 'Bearer novo');
    expect(files.map((f) => f.name), ['A - B.lrc']);
  });

  test('sincroniza: novos entram, alterados (revisão) são baixados de novo, apagados saem; os do seletor ficam', () async {
    final lib = LocalLyricsLibrary(directory: dir);
    await lib.importFiles([(name: 'Elis Regina - Como Nossos Pais.lrc', content: '[00:01.00]Não quero lhe falar')]);
    final folder = _Folder()
      ..files['/The Beatles - Something.lrc'] = (rev: 'r1', content: '[00:01.00]Something')
      ..files['/Abbey Road/The Beatles - Because.lrc'] = (rev: 'r1', content: '[00:02.00]Because')
      ..files['/notas.docx'] = (rev: 'r1', content: 'x')
      ..files['/semtraco.lrc'] = (rev: 'r1', content: '[00:01.00]linha');

    var r = await lib.syncFrom(folder);
    expect(r.added, 2);
    expect(r.skipped, ['semtraco.lrc']);
    expect(lib.count, 3);
    expect(lib.countFrom('dropbox'), 2);

    // Sem mudanças: nada é baixado de novo (exceto o arquivo que não foi entendido)
    folder.downloads = 0;
    r = await lib.syncFrom(folder);
    expect(r.added + r.updated + r.removed, 0);
    expect(folder.downloads, 1);

    // Um arquivo mudou e outro foi apagado no Dropbox
    folder.files['/The Beatles - Something.lrc'] = (rev: 'r2', content: '[00:01.00]Something in the way');
    folder.files.remove('/Abbey Road/The Beatles - Because.lrc');
    r = await lib.syncFrom(folder);
    expect(r.updated, 1);
    expect(r.removed, 1);
    expect(lib.find('Something', 'The Beatles')!.lyrics, contains('in the way'));
    expect(lib.find('Because', 'The Beatles'), isNull);
    expect(lib.find('Como Nossos Pais', 'Elis Regina'), isNotNull, reason: 'escolhido no seletor: fica');

    final again = LocalLyricsLibrary(directory: dir);
    await again.load();
    expect(again.countFrom('dropbox'), 1);
  });

  test('pastas de nuvens diferentes não se misturam; o formato da 1.4.11 (dropboxPath) continua valendo', () async {
    File('${dir.path}/waxclub_my_lyrics.json').writeAsStringSync(jsonEncode([
      {'title': 'Something', 'artist': 'The Beatles', 'lyrics': '[00:01.00]x', 'file': 'a.lrc', 'dropboxPath': '/a.lrc', 'dropboxRev': 'r1'},
    ]));
    final lib = LocalLyricsLibrary(directory: dir);
    await lib.load();
    expect(lib.countFrom('dropbox'), 1);

    final onedrive = _Folder('onedrive')..files['/Elis Regina - Madalena.lrc'] = (rev: 'e1', content: '[00:01.00]Oh Madalena');
    final r = await lib.syncFrom(onedrive);
    expect(r.added, 1);
    expect(r.removed, 0, reason: 'a letra do Dropbox não é da pasta do OneDrive');
    expect(lib.countFrom('onedrive'), 1);
    expect(lib.countFrom('dropbox'), 1);
  });

  test('OneDrive: login PKCE na Microsoft, pasta do app com subpastas e download pelo endereço autorizado', () async {
    final client = MockClient((req) async {
      final u = req.url.toString();
      if (u.endsWith('/oauth2/v2.0/token')) {
        expect(req.bodyFields['scope'], contains('Files.ReadWrite.AppFolder'));
        return http.Response(jsonEncode({'access_token': 'A', 'refresh_token': 'R', 'expires_in': 3600}), 200);
      }
      if (u.contains('/me?')) return http.Response(jsonEncode({'displayName': 'Gustavo'}), 200);
      if (u.contains('/special/approot/children')) {
        return http.Response(
            jsonEncode({
              'value': [
                {'id': 'f1', 'name': 'Abbey Road', 'folder': {'childCount': 1}},
                {
                  'id': 'x1',
                  'name': 'The Beatles - Something.lrc',
                  'file': {},
                  'eTag': 'e1',
                  'size': 20,
                  '@microsoft.graph.downloadUrl': 'https://dl.example/x1',
                },
              ],
            }),
            200);
      }
      if (u.contains('/items/f1/children')) {
        return http.Response(
            jsonEncode({
              'value': [
                {'id': 'x2', 'name': 'The Beatles - Because.lrc', 'file': {}, 'eTag': 'e2', 'size': 20},
              ],
            }),
            200);
      }
      if (u == 'https://dl.example/x1') {
        expect(req.headers['Authorization'], isNull, reason: 'endereço já autorizado: sem o token');
        return http.Response('[00:01.00]Something', 200);
      }
      if (u.contains('/items/x2/content')) return http.Response('[00:01.00]Because', 200);
      return http.Response('', 404);
    });
    final o = OneDriveFolder(store: MemoryCloudTokenStore(), client: client, clientId: 'cliente');
    final url = o.authorizeUrl();
    expect(url.queryParameters['code_challenge_method'], 'S256');
    expect(await o.finishLogin(Uri.parse('${OneDriveConfig.redirectUri}?code=C&state=${url.queryParameters['state']}')), isTrue);
    expect(o.accountName, 'Gustavo');

    final lib = LocalLyricsLibrary(directory: dir);
    final r = await o.syncInto(lib);
    expect(r.added, 2);
    expect(lib.find('Because', 'The Beatles'), isNotNull);
    expect(lib.entries.map((e) => e.cloudPath), containsAll(['/The Beatles - Something.lrc', '/Abbey Road/The Beatles - Because.lrc']));
    expect(o.lastSync, isNotNull);
  });

  test('Google Drive: acha a pasta "WaxClub Lyrics", percorre subpastas e baixa; sem acesso pede para conectar de novo', () async {
    final client = MockClient((req) async {
      expect(req.headers['Authorization'], 'Bearer G');
      final q = req.url.queryParameters['q'] ?? '';
      if (req.url.path.endsWith('/files') && q.startsWith("name = 'WaxClub Lyrics'")) {
        return http.Response(jsonEncode({'files': [{'id': 'root1', 'name': 'WaxClub Lyrics'}]}), 200);
      }
      if (q == "'root1' in parents and trashed = false") {
        return http.Response(
            jsonEncode({
              'files': [
                {'id': 'sub', 'name': 'Elis', 'mimeType': 'application/vnd.google-apps.folder'},
                {'id': 'g1', 'name': 'Os Mutantes - Panis et Circenses.lrc', 'mimeType': 'text/plain', 'size': '30', 'md5Checksum': 'm1'},
              ],
            }),
            200);
      }
      if (q == "'sub' in parents and trashed = false") {
        return http.Response(
            jsonEncode({
              'files': [
                {'id': 'g2', 'name': 'Elis Regina - Madalena.txt', 'mimeType': 'text/plain', 'size': '20', 'md5Checksum': 'm2'},
              ],
            }),
            200);
      }
      if (req.url.path.endsWith('/files/g1')) return http.Response('[00:01.00]Eu quis cantar', 200);
      if (req.url.path.endsWith('/files/g2')) return http.Response('Oh Madalena', 200);
      if (req.url.path.endsWith('/about')) return http.Response(jsonEncode({'user': {'displayName': 'Gustavo'}}), 200);
      return http.Response('', 404);
    });
    String? token = 'G';
    final g = GoogleDriveFolder(
      store: MemoryCloudTokenStore(),
      client: client,
      tokens: ({required bool interactive}) async => token,
    );
    expect(await g.connect(), isTrue);
    expect(g.accountName, 'Gustavo');
    final lib = LocalLyricsLibrary(directory: dir);
    final r = await g.syncInto(lib);
    expect(r.added, 2);
    expect(lib.countFrom('gdrive'), 2);
    expect(lib.find('Madalena', 'Elis Regina'), isNotNull);

    token = null; // acesso perdido (ex.: permissão retirada na conta Google)
    await expectLater(g.syncInto(lib), throwsStateError);
  });
}
