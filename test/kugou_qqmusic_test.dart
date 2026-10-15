import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';

void main() {
  const lrc = '[00:10.00]Something in the way she moves\n[00:15.00]Attracts me like no other lover\n'
      '[00:20.00]Something in the way she woos me\n[02:50.00]I don\'t want to leave her now';
  final b64 = base64Encode(utf8.encode(lrc));

  tearDown(() {
    LyricsProviderService.sourceOrder = () => const ['local', 'lrclib', 'netease', 'megalobiz', 'kugou', 'qqmusic'];
    LyricsProviderService.sourceEnabled = (_) => true;
  });

  test('Kugou: pula o candidato de outro artista e baixa o LRC (base64) do certo', () async {
    final downloaded = <String>[];
    final client = MockClient((req) async {
      if (req.url.path == '/search') {
        return http.Response(
            jsonEncode({
              'candidates': [
                {'id': '1', 'accesskey': 'A', 'singer': 'Cover Band', 'song': 'Something', 'duration': 180},
                {'id': '2', 'accesskey': 'B', 'singer': 'The Beatles', 'song': 'Something', 'duration': 182000},
              ],
            }),
            200);
      }
      if (req.url.path == '/download') {
        downloaded.add(req.url.queryParameters['id']!);
        return http.Response(jsonEncode({'content': b64}), 200);
      }
      return http.Response('', 404);
    });
    LyricsProviderService.sourceOrder = () => const ['kugou'];
    final s = LyricsProviderService(client: client);
    final r = await s.fetchLyricsDetails(trackName: 'Something', artistName: 'Beatles', durationSeconds: 182);
    expect(downloaded, ['2']);
    expect(r?.source, 'kugou');
    expect(r?.durationSeconds, 182, reason: 'duração em milissegundos convertida');
    expect(s.lastAttempts['kugou'], LyricsAttempt.found);
  });

  test('QQ Music: ignora a versão ao vivo, escolhe a de duração mais perto; sem resultado fica vermelho', () async {
    final asked = <String>[];
    var empty = false;
    final client = MockClient((req) async {
      if (req.url.path.contains('client_search_cp')) {
        if (empty) return http.Response(jsonEncode({'data': {'song': {'list': []}}}), 200);
        return http.Response(
            jsonEncode({
              'data': {
                'song': {
                  'list': [
                    {'songmid': 'live', 'songname': 'Something (Live)', 'singer': [{'name': 'The Beatles'}], 'interval': 200},
                    {'songmid': 'far', 'songname': 'Something', 'singer': [{'name': 'The Beatles'}], 'interval': 300},
                    {'songmid': 'near', 'songname': 'Something', 'singer': [{'name': 'The Beatles'}], 'interval': 183, 'albumname': 'Abbey Road'},
                  ],
                },
              },
            }),
            200);
      }
      if (req.url.path.contains('fcg_query_lyric_new')) {
        expect(req.headers['Referer'], 'https://y.qq.com/');
        asked.add(req.url.queryParameters['songmid']!);
        return http.Response(jsonEncode({'lyric': b64}), 200);
      }
      return http.Response('', 404);
    });
    LyricsProviderService.sourceOrder = () => const ['qqmusic'];
    final s = LyricsProviderService(client: client);
    final r = await s.fetchLyricsDetails(trackName: 'Something', artistName: 'The Beatles', durationSeconds: 182);
    expect(asked, ['near']);
    expect(r?.source, 'qqmusic');
    expect(r?.albumName, 'Abbey Road');

    empty = true;
    expect(await s.fetchLyricsDetails(trackName: 'Something', artistName: 'The Beatles', durationSeconds: 182), isNull);
    expect(s.lastAttempts['qqmusic'], LyricsAttempt.notFound);
  });
}
