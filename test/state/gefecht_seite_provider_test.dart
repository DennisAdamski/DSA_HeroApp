import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/externer_held.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ueberzahl_rules.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_seite_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

const _attribute = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 12,
  kk: 12,
);

void main() {
  test('Gefährten der Heldengruppe erscheinen automatisch, ohne Doppel', () {
    final jetzt = DateTime(2026, 10, 16);
    const held = HeroSheet(
      id: 'a',
      name: 'Alrike',
      level: 1,
      attributes: _attribute,
      gruppen: [
        HeroGruppenMitgliedschaft(
          gruppenCode: 'g1',
          gruppenName: 'Gefährten vom Svellt',
          externeHeldIds: ['y', 'ich'],
        ),
        HeroGruppenMitgliedschaft(gruppenCode: 'g2', externeHeldIds: ['y']),
      ],
    );
    final c = ProviderContainer(
      overrides: [
        heroByIdProvider('a').overrideWithValue(held),
        externeHeldenProvider.overrideWith(
          (ref) => Stream.value({
            'y': ExternerHeld(
              id: 'y',
              name: 'Yasmina',
              iniBase: 12,
              updatedAt: jetzt,
            ),
            // Die eigene Visitenkarte steht nicht doppelt auf der Seite.
            'ich': ExternerHeld(
              id: 'ich',
              name: 'Alrike',
              quelleHeroId: 'a',
              updatedAt: jetzt,
            ),
          }),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(externeHeldenProvider, (_, _) {});
    return Future<void>.delayed(Duration.zero, () {
      List<GefechtsTeilnehmer> seite() =>
          c.read(gefechtsEigeneSeiteProvider('a'));
      expect(seite().map((t) => t.id), ['a', 'extern:y']);
      expect(seite().last.ini, 12);
      expect(gefechtsEigeneNahkaempfer(seite()), 2);
      c
          .read(gefechtBegegnungProvider.notifier)
          .beteiligungSetzen(
            'extern:y',
            'Yasmina',
            GefechtsBeteiligung.fernkampf,
          );
      expect(gefechtsEigeneNahkaempfer(seite()), 1);
      expect(seite().last.beteiligung, GefechtsBeteiligung.fernkampf);
    });
  });
}
