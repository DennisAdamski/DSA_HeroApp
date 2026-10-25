import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_proben_favorit.dart';
import 'package:dsa_heldenverwaltung/rules/derived/proben_favoriten_rules.dart';

HeroProbenFavorit _t(String ref) =>
    HeroProbenFavorit.von(ProbenFavoritArt.talent, ref);

List<String> _ids(List<HeroProbenFavorit> liste) =>
    liste.map((f) => f.id).toList();

void main() {
  group('schalteProbenFavorit', () {
    test('nimmt neue Favoriten hinten auf', () {
      final liste = schalteProbenFavorit([_t('a')], _t('b'));
      expect(_ids(liste), ['talent:a', 'talent:b']);
    });

    test('entfernt einen vorhandenen Favoriten', () {
      final liste = schalteProbenFavorit([_t('a'), _t('b')], _t('a'));
      expect(_ids(liste), ['talent:b']);
    });

    test('dieselbe Probe wird nie doppelt aufgenommen', () {
      var liste = <HeroProbenFavorit>[];
      liste = schalteProbenFavorit(liste, _t('a'));
      liste = schalteProbenFavorit(liste, _t('a'));
      expect(liste, isEmpty);
    });

    test('eine volle Liste nimmt nichts mehr auf, entfernt aber', () {
      final voll = [for (var i = 0; i < kProbenFavoritenMax; i++) _t('t$i')];
      expect(kannProbenFavoritAufnehmen(voll, _t('neu')), isFalse);
      expect(kannProbenFavoritAufnehmen(voll, _t('t3')), isTrue);
      expect(schalteProbenFavorit(voll, _t('neu')), voll);
      expect(schalteProbenFavorit(voll, _t('t3')), hasLength(voll.length - 1));
    });

    test('unbekannte Einträge samt Zusatzfeldern bleiben unverändert', () {
      const fremd = HeroProbenFavorit(
        id: 'ritual:r1',
        unbekannteFelder: <String, Object?>{'x': 1},
      );
      final liste = schalteProbenFavorit([fremd], _t('a'));
      expect(liste.first, same(fremd));
    });
  });

  group('verschiebeProbenFavorit', () {
    final basis = [_t('a'), _t('b'), _t('c')];

    test('verschiebt nach vorn und hinten', () {
      expect(_ids(verschiebeProbenFavorit(basis, 'talent:c', -1)), [
        'talent:a',
        'talent:c',
        'talent:b',
      ]);
      expect(_ids(verschiebeProbenFavorit(basis, 'talent:a', 1)), [
        'talent:b',
        'talent:a',
        'talent:c',
      ]);
    });

    test('am Rand und bei unbekannter ID bleibt die Liste gleich', () {
      expect(verschiebeProbenFavorit(basis, 'talent:a', -1), same(basis));
      expect(verschiebeProbenFavorit(basis, 'talent:c', 1), same(basis));
      expect(verschiebeProbenFavorit(basis, 'talent:x', 1), same(basis));
      expect(verschiebeProbenFavorit(basis, 'talent:a', 0), same(basis));
    });

    test('große Schritte setzen den Eintrag an den Rand', () {
      expect(_ids(verschiebeProbenFavorit(basis, 'talent:a', 9)), [
        'talent:b',
        'talent:c',
        'talent:a',
      ]);
    });
  });

  test('entferneProbenFavoriten löscht nur die genannten IDs', () {
    final basis = [_t('a'), _t('b'), _t('c')];
    expect(_ids(entferneProbenFavoriten(basis, {'talent:a', 'talent:c'})), [
      'talent:b',
    ]);
    expect(entferneProbenFavoriten(basis, const <String>{}), same(basis));
  });
}
