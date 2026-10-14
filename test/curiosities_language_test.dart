import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/curiosities_service.dart';
import 'package:waxclub/services/language_detector.dart';

/// Banco compartilhado falso: guarda por disco|faixa|idioma.
class _FakeRemote implements CuriositiesRemote {
  final Map<String, List<Curiosity>> rows = {};
  final List<String> fetched = [];

  @override
  Future<List<Curiosity>?> fetch(String record, String lang, {String? track}) async {
    fetched.add('$record|${track ?? ''}|$lang');
    return rows['$record|${track ?? ''}|$lang'] ?? const [];
  }

  @override
  Future<void> save(String record, String lang, List<Curiosity> items, {String? track, String? discogsReleaseId}) async {
    rows['$record|${track ?? ''}|$lang'] = items;
  }
}

const _ptAlbum = 'Clube da Esquina é o primeiro álbum de Milton Nascimento e Lô Borges, lançado em 1972 pela EMI-Odeon. '
    'O disco foi gravado no Rio de Janeiro com músicos do movimento mineiro e se tornou um dos mais importantes da música brasileira. '
    'Em 2022 foi eleito o melhor álbum brasileiro de todos os tempos pelo podcast Discoteca Básica.';

void main() {
  group('idioma do artista', () {
    test('reconhece o idioma pelos títulos e pela letra', () {
      expect(LanguageDetector.detect('Clube da Esquina Tudo o que você podia ser Cais O trem azul Nada será como antes'), 'pt');
      expect(LanguageDetector.detect('Abbey Road Come Together Something Here Comes the Sun'), 'en');
      expect(LanguageDetector.detect('El amor de mi vida, la noche y el corazón'), 'es');
      expect(LanguageDetector.detect('Je ne regrette rien, la vie en rose, c\'est pour toi'), 'fr');
      expect(LanguageDetector.detect('Ich liebe dich und die Nacht ist schön'), 'de');
      expect(LanguageDetector.detect('真夜中のドア〜stay with me'), 'ja');
      expect(LanguageDetector.detect('Thriller'), 'en', reason: 'pouca evidência: inglês');
    });
  });

  group('curiosidades no idioma do artista, banco compartilhado primeiro', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('waxclub_curio_lang_'));
    tearDown(() async => dir.delete(recursive: true));

    test('banco sem nada: busca na Wikipedia do idioma do artista e grava no banco', () async {
      final hosts = <String>[];
      final client = MockClient((req) async {
        hosts.add(req.url.host);
        final q = req.url.queryParameters;
        if (q['list'] == 'search') {
          return http.Response.bytes(utf8.encode(jsonEncode({
            'query': {
              'search': [
                {'title': 'Clube da Esquina (álbum)', 'snippet': 'álbum de <b>Milton Nascimento</b>'}
              ]
            }
          })), 200);
        }
        return http.Response.bytes(utf8.encode(jsonEncode({
          'query': {
            'pages': [
              {'extract': _ptAlbum}
            ]
          }
        })), 200);
      });
      final remote = _FakeRemote();
      final service = CuriositiesService(client: client, directory: dir, remote: remote);
      final facts = await service.albumFacts(artist: 'Milton Nascimento', album: 'Clube da Esquina', lang: 'pt');

      expect(remote.fetched.first, endsWith('|pt'), reason: 'procura no banco antes da web');
      expect(hosts.every((h) => h == 'pt.wikipedia.org'), isTrue, reason: 'Wikipedia em português');
      expect(facts, isNotEmpty);
      expect(facts.first.text, contains('Milton Nascimento'));
      expect(facts.first.url, startsWith('https://pt.wikipedia.org/wiki/'));
      final key = '${CuriositiesService.recordKey('Milton Nascimento', 'Clube da Esquina')}||pt';
      expect(remote.rows[key], isNotNull, reason: 'o que veio da web foi gravado no banco');
    });

    test('banco com as curiosidades: não vai à web', () async {
      var webCalls = 0;
      final client = MockClient((_) async {
        webCalls++;
        return http.Response('{}', 200);
      });
      final remote = _FakeRemote();
      final record = CuriositiesService.recordKey('Milton Nascimento', 'Clube da Esquina');
      remote.rows['$record||pt'] = const [Curiosity('Fato guardado no banco do WaxClub.', 'Wikipedia')];
      final service = CuriositiesService(client: client, directory: dir, remote: remote);
      final facts = await service.albumFacts(artist: 'Milton Nascimento', album: 'Clube da Esquina', lang: 'pt');
      expect(facts.single.text, 'Fato guardado no banco do WaxClub.');
      expect(webCalls, 0);
    });
  });

  test('frases em português são escolhidas (maiúsculas acentuadas, palavras-chave)', () {
    final facts = CuriositiesService.pickFacts(_ptAlbum, max: 3);
    expect(facts.length, greaterThanOrEqualTo(2));
    expect(facts.any((f) => f.contains('1972')), isTrue);
  });
}
