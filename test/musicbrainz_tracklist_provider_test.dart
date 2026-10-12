import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/musicbrainz_tracklist_provider.dart';
import 'package:waxclub/services/tracklist_provider.dart';

void main() {
  group('MusicBrainzTracklistProvider Tests (T0.3)', () {
    test('searchReleases pontua e prioriza lançamentos em vinil e álbuns oficiais', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/recording')) {
          final json = {
            'recordings': [
              {
                'id': 'rec-1',
                'title': 'Love Me Do',
                'releases': [
                  {
                    'id': 'rel-cd',
                    'title': 'Please Please Me',
                    'status': 'Official',
                    'media': [
                      {'format': 'CD'}
                    ],
                    'release-group': {
                      'primary-type': 'Album',
                      'secondary-types': <String>[],
                    }
                  },
                  {
                    'id': 'rel-vinyl',
                    'title': 'Please Please Me',
                    'status': 'Official',
                    'media': [
                      {'format': '12" Vinyl'}
                    ],
                    'release-group': {
                      'primary-type': 'Album',
                      'secondary-types': <String>[],
                    }
                  },
                  {
                    'id': 'rel-comp',
                    'title': 'Greatest Hits',
                    'status': 'Official',
                    'media': [
                      {'format': 'CD'}
                    ],
                    'release-group': {
                      'primary-type': 'Album',
                      'secondary-types': ['Compilation'],
                    }
                  }
                ]
              }
            ]
          };
          return http.Response(jsonEncode(json), 200);
        }
        return http.Response('Not Found', 404);
      });

      final provider = MusicBrainzTracklistProvider(client: mockClient);
      final candidates = await provider.searchReleases(
        title: 'Love Me Do',
        artist: 'The Beatles',
        album: 'Please Please Me',
      );

      expect(candidates.isNotEmpty, isTrue);
      expect(candidates.first.releaseId, equals('rel-vinyl'));
      expect(candidates.first.format, contains('Vinyl'));
    });

    test('loadTracklist mescla mídias e extrai number, length e side', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/release/rel-vinyl')) {
          final json = {
            'media': [
              {
                'position': 1,
                'tracks': [
                  {
                    'number': 'A1',
                    'title': 'I Saw Her Standing There',
                    'length': 175000,
                  },
                  {
                    'number': 'A2',
                    'title': 'Misery',
                    'length': 109000,
                  }
                ]
              },
              {
                'position': 2,
                'tracks': [
                  {
                    'number': 'B1',
                    'title': 'Love Me Do',
                    'length': 140000,
                  }
                ]
              }
            ]
          };
          return http.Response(jsonEncode(json), 200);
        }
        return http.Response('Not Found', 404);
      });

      final provider = MusicBrainzTracklistProvider(client: mockClient);
      final entries = await provider.loadTracklist(const ReleaseCandidate(
        providerId: 'musicbrainz',
        releaseId: 'rel-vinyl',
        albumTitle: 'Please Please Me',
      ));

      expect(entries.length, equals(3));
      expect(entries[0].position, equals(1));
      expect(entries[0].number, equals('A1'));
      expect(entries[0].side, equals('A'));
      expect(entries[0].lengthMs, equals(175000));

      expect(entries[2].position, equals(3));
      expect(entries[2].number, equals('B1'));
      expect(entries[2].side, equals('B'));
      expect(entries[2].title, equals('Love Me Do'));
    });

    test('retry automático em caso de HTTP 503 / 429', () async {
      int attempts = 0;
      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response('Service Unavailable', 503, headers: {'retry-after': '0'});
        }
        return http.Response(jsonEncode({'recordings': []}), 200);
      });

      final provider = MusicBrainzTracklistProvider(client: mockClient);
      final result = await provider.searchReleases(
        title: 'Song',
        artist: 'Artist',
      );

      expect(attempts, equals(2));
      expect(result, isEmpty);
    });
  });
}
