import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/tracklist_provider.dart';

ReleaseCandidate _c(String id, String? format, {String? type}) =>
    ReleaseCandidate(providerId: 'discogs', releaseId: id, albumTitle: 'Disco $id', format: format, primaryType: type);

void main() {
  test('escolha de disco mostra só vinil LP ou EP', () {
    final list = [
      _c('lp', 'Vinyl, LP, Album'),
      _c('ep', 'Vinyl, 7", 45 RPM, EP'),
      _c('mb-lp', '12" Vinyl', type: 'Album'),
      _c('cd', 'CD, Album'),
      _c('digital', 'File, MP3', type: 'Album'),
      _c('fita', 'Cassette, Album'),
      _c('single', 'Vinyl, 7", 45 RPM, Single'),
      _c('maxi', 'Vinyl, 12", 33 ⅓ RPM, Maxi-Single'),
      _c('mb-single', '7" Vinyl', type: 'Single'),
      _c('sem-formato', null, type: 'Album'),
    ];
    expect(vinylLpOrEpOnly(list).map((c) => c.releaseId), ['lp', 'ep', 'mb-lp']);
  });

  test('LP de vinil sem tipo informado continua na lista', () {
    expect(_c('x', 'Vinyl, Reissue').isVinylLpOrEp, isTrue);
  });
}
