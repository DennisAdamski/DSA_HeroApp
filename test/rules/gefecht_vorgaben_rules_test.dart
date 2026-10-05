import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_freigabe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_vorgaben_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

void main() {
  const w = Gefechtswerte(
    iniBasis: 10,
    at: 15,
    pa: 14,
    ausweichen: 12,
    be: 1,
    ausweichen1: true,
    waffenDk: 'N',
  );

  test('Vorgaben füllen nur unbekannte Angaben', () {
    final leer = gefechtsKontextMitVorgaben(const Gefechtskontext());
    expect(leer.angriffsart, Gefechtsangriffsart.nahkampf);
    expect(leer.finte, 0);
    expect(leer.situationsZuschlag, 0);
    expect(leer.platzZumAusweichen, isTrue);
    expect(leer.schildWmWirksam, isTrue);
    // Ohne Vorgabe: eine falsche Annahme gäbe Schüsse frei.
    expect(leer.geladen, isNull);
    expect(leer.entfernung, isNull);
    expect(leer.gegnerzahl, isNull);

    final erfasst = gefechtsKontextMitVorgaben(
      const Gefechtskontext(
        kontakt: 'Ork',
        angriffsart: Gefechtsangriffsart.fernkampf,
        finte: 3,
        platzZumAusweichen: false,
        schildWmWirksam: false,
        situationsZuschlag: 4,
        paradeVerboten: true,
        entfernung: 12,
        geladen: false,
      ),
    );
    expect(erfasst.kontakt, 'Ork');
    expect(erfasst.angriffsart, Gefechtsangriffsart.fernkampf);
    expect(erfasst.finte, 3);
    expect(erfasst.platzZumAusweichen, isFalse);
    expect(erfasst.schildWmWirksam, isFalse);
    expect(erfasst.situationsZuschlag, 4);
    expect(erfasst.paradeVerboten, isTrue);
    expect(erfasst.entfernung, 12);
    expect(erfasst.geladen, isFalse);
  });

  test('Start-DK folgt der geführten Waffe', () {
    expect(gefechtsStartDk('N'), 'N');
    expect(gefechtsStartDk('NS'), 'N');
    expect(gefechtsStartDk('HN'), 'N');
    expect(gefechtsStartDk('H'), 'H');
    expect(gefechtsStartDk('S'), 'S');
    expect(gefechtsStartDk('SP'), 'S');
    expect(gefechtsStartDk('P'), 'P');
    expect(gefechtsStartDk('sp'), 'S');
    expect(gefechtsStartDk(''), 'N');
    expect(gefechtsStartDk('S', fernkampf: true), 'N');
    expect(gefechtsStartDkFuer(null), 'N');
    expect(
      gefechtsStartDkFuer(
        const MainWeaponSlot(id: 'd', name: 'Dolch', distanceClass: 'H'),
      ),
      'H',
    );
  });

  test('Neues Gefecht beginnt mit Start-DK und Vorgaben', () {
    final s = beginneGefecht(6, dk: 'S');
    expect(s.dk, 'S');
    expect(s.kontext.finte, 0);
    expect(s.kontext.angriffsart, Gefechtsangriffsart.nahkampf);
    expect(beginneGefecht(6).dk, isNull);
  });

  test('Normale Abwehr ist ohne Eingabe bereit, Sperren bleiben', () {
    final s = beginneGefecht(6, dk: 'N');
    for (final aktion in [
      Gefechtsaktion.parade,
      Gefechtsaktion.freiesAusweichen,
      Gefechtsaktion.gezieltesAusweichen,
    ]) {
      final p = pruefeGefechtsaktion(s, w, aktion);
      expect(p.fehlendeAngaben, isEmpty, reason: '$aktion');
      expect(p.sperrgruende, isEmpty, reason: '$aktion');
    }
    final parade = pruefeGefechtsaktion(
      s.copyWith(
        kontext: const Gefechtskontext(
          angriffsart: Gefechtsangriffsart.nahkampf,
          finte: 0,
          paradeVerboten: true,
        ),
      ),
      w,
      Gefechtsaktion.parade,
    );
    expect(parade.status, Gefechtsfreigabe.gesperrt);
    final ohnePlatz = pruefeGefechtsaktion(
      s.copyWith(
        kontext: gefechtsKontextMitVorgaben(
          const Gefechtskontext(platzZumAusweichen: false),
        ),
      ),
      w,
      Gefechtsaktion.freiesAusweichen,
    );
    expect(ohnePlatz.status, Gefechtsfreigabe.gesperrt);
  });

  test('Ausweichen nutzt die Gegnerzahl der Rundenleiste', () {
    final s = beginneGefecht(6, dk: 'S').copyWith(gegner: 3);
    expect(gefechtsGegnerzahl(s), 3);
    final p = pruefeGefechtsaktion(s, w, Gefechtsaktion.freiesAusweichen);
    expect(p.fehlendeAngaben, isEmpty);
    // BE 1 + zwei weitere Gegner je 2 + Ausweich-DK Stangenwaffen 1.
    expect(p.erschwernis, 1 + 4 + 1);
    expect(
      gefechtsGegnerzahl(
        s.copyWith(
          kontext: gefechtsKontextMitVorgaben(
            const Gefechtskontext(gegnerzahl: 2),
          ),
        ),
      ),
      2,
    );
  });

  test('Nach einer Abwehr gelten wieder die Vorgaben', () {
    final s = beginneGefecht(6, dk: 'N').copyWith(
      kontext: const Gefechtskontext(
        kontakt: 'Ork',
        angriffsart: Gefechtsangriffsart.nahkampf,
        finte: 4,
        schildWmWirksam: false,
        situationsZuschlag: 3,
        entfernung: 15,
      ),
    );
    final p = pruefeGefechtsaktion(s, w, Gefechtsaktion.parade);
    final nachher = verbraucheGefechtsaktion(s, w, p, erfolg: true);
    expect(nachher.kontext.kontakt, 'Ork');
    expect(nachher.kontext.finte, 0);
    expect(nachher.kontext.angriffsart, Gefechtsangriffsart.nahkampf);
    expect(nachher.kontext.schildWmWirksam, isTrue);
    // Zielsituation und Entfernung beschreiben das eigene Ziel.
    expect(nachher.kontext.situationsZuschlag, 3);
    expect(nachher.kontext.entfernung, 15);
  });

  test('Freie Aktion braucht keine pauschale Bestätigung', () {
    final p = pruefeGefechtsaktion(
      beginneGefecht(6, dk: 'N'),
      w,
      Gefechtsaktion.freieAktion,
    );
    expect(p.status, Gefechtsfreigabe.bereit);
  });

  test('Hinweise allein ergeben Bereit, fehlende Angaben Prüfen', () {
    const auftrag = GefechtAuftrag(
      aktion: Gefechtsaktion.angriff,
      titel: 'Test',
      zuschlag: 0,
      dk: 'N',
      dauer: 1,
      kosten: 1,
    );
    const nurHinweis = Gefechtspruefung(
      aktion: Gefechtsaktion.angriff,
      status: Gefechtsfreigabe.pruefen,
      gruende: ['Zeitpunkt prüfen.'],
      hinweise: ['Zeitpunkt prüfen.'],
      zielwert: 14,
    );
    final bereit = ergaenzeGefechtsfreigabe(nurHinweis, auftrag);
    expect(bereit.status, Gefechtsfreigabe.bereit);
    expect(bereit.hinweise, ['Zeitpunkt prüfen.']);
    expect(bereit.ausfuehrbar, isTrue);
    const fehlt = Gefechtspruefung(
      aktion: Gefechtsaktion.angriff,
      status: Gefechtsfreigabe.pruefen,
      gruende: ['DK festlegen.'],
      fehlendeAngaben: ['DK festlegen.'],
      zielwert: null,
    );
    expect(
      ergaenzeGefechtsfreigabe(fehlt, auftrag).status,
      Gefechtsfreigabe.pruefen,
    );
  });

  test('Normale AT des Helden ist mit Start-DK sofort bereit', () {
    final snapshot = buildHeroComputedSnapshot(
      hero: testHero().copyWith(
        combatConfig: const CombatConfig(
          weapons: [
            MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N'),
          ],
        ),
      ),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    final s = beginneGefecht(
      6,
      dk: gefechtsStartDkFuer(snapshot.hero.combatConfig.selectedWeaponOrNull),
    );
    for (final aktion in [Gefechtsaktion.angriff, Gefechtsaktion.parade]) {
      final p = pruefeGefechtAuftrag(
        s,
        snapshot,
        testCatalog,
        GefechtAuftrag(
          aktion: aktion,
          titel: 'Test',
          zuschlag: 0,
          dk: s.dk,
          dauer: 1,
          kosten: 1,
        ),
      );
      expect(p.status, Gefechtsfreigabe.bereit, reason: p.gruende.join(' '));
    }
  });
}
