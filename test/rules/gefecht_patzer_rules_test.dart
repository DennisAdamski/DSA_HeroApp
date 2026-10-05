import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_patzer.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_patzer_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';

void main() {
  test(
    'Patzerfreigabe erhält Fachmetadaten und blockiert konkrete verlorene ID',
    () {
      const w = GefechtsKampfmittelwahl(
        GefechtsKampfmittelArt.nebenwaffe,
        'w1',
      );
      const p = Gefechtspruefung(
        aktion: Gefechtsaktion.parade,
        status: Gefechtsfreigabe.bereit,
        gruende: [],
        zielwert: 15,
        paraden: 1,
        kampfmittel: w,
        ausruestungspaar: 'pair',
        meisterparadeAnsage: 4,
        verbrauchterMeisterparadeBonus: 2,
        ansageFehlmalus: 7,
        beendetAnsageFolgemalus: true,
        hinweise: ['Hinweis'],
      );
      final gesperrt = ergaenzeGefechtsPatzerfreigabe(
        p,
        const Gefechtszustand(
          iniWurf: 6,
          gesperrteKampfmittel: {'waffe:w1': 'verloren'},
        ),
        w,
      );
      expect(gesperrt.ausfuehrbar, false);
      expect(gesperrt.sperrgruende, ['verloren']);
      expect(gesperrt.paraden, 1);
      expect(gesperrt.zielwert, 15);
      expect(gesperrt.ausruestungspaar, 'pair');
      expect(gesperrt.meisterparadeAnsage, 4);
      expect(gesperrt.verbrauchterMeisterparadeBonus, 2);
      expect(gesperrt.ansageFehlmalus, 7);
      expect(gesperrt.beendetAnsageFolgemalus, true);
      expect(gesperrt.hinweise, ['Hinweis']);
      expect(
        identical(
          ergaenzeGefechtsPatzerfreigabe(
            p,
            const Gefechtszustand(iniWurf: 6),
            w,
          ),
          p,
        ),
        true,
      );
    },
  );
  test('Rundenverlust und offene Folgewürfe sind getrennte Grenzen', () {
    const s = GefechtsPatzerstand(verloreneRunde: 1);
    expect(gefechtFolgewuerfeOffen(s), false);
    expect(gefechtPatzerSperrt(s, 1), true);
    expect(gefechtPatzerSperrt(s, 2), false);
  });
  test(
    'Wiederaufnahme entsperrt nur verlorene, niemals zerbrochene Mittel',
    () {
      const s = GefechtsPatzerstand(
        gesperrteMittel: {'waffe:a': 'verloren', 'waffe:b': 'zerbrochen'},
        verloreneMittel: {'waffe:a'},
      );
      expect(
        identical(bestaetigeGefechtsWiederaufnahme(s, 'waffe:b'), s),
        true,
      );
      final neu = bestaetigeGefechtsWiederaufnahme(s, 'waffe:a');
      expect(neu.gesperrteMittel, {'waffe:b': 'zerbrochen'});
      expect(neu.verloreneMittel, isEmpty);
    },
  );
  test(
    'Bruchtest: Gleichheit zerbricht; 12 und kritischer Treffer erhalten BF',
    () {
      expect(werteGefechtsBruchtest(5, 5, kritisch: false).zerbrochen, true);
      expect(werteGefechtsBruchtest(5, 6, kritisch: false).bf, 6);
      expect(werteGefechtsBruchtest(5, 6, kritisch: true).bf, 5);
      expect(werteGefechtsBruchtest(5, 12, kritisch: false).bf, 5);
      expect(werteGefechtsBruchtest(12, 12, kritisch: false).zerbrochen, true);
    },
  );
  test('Tabelle deckt alle 2W6-Ergebnisse und stabile Waffen ab', () {
    expect(gefechtsPatzerfolge(2, bf: 3).zerbrochen, true);
    final stabil = gefechtsPatzerfolge(2, bf: 0);
    expect(stabil.waffeVerloren, true);
    expect(stabil.bfAenderung, 2);
    expect(stabil.iniVerlust, 4);
    expect(gefechtsPatzerfolge(2, bf: -2, unzerstoerbar: true).bfAenderung, 0);
    expect(gefechtsPatzerfolge(4, bf: 3).sturz, true);
    expect(gefechtsPatzerfolge(7, bf: 3).iniVerlust, 2);
    expect(gefechtsPatzerfolge(9, bf: 3).waffeVerloren, true);
    expect(gefechtsPatzerfolge(11, bf: 3).schadensFaktor, 1);
    expect(gefechtsPatzerfolge(12, bf: 3).schadensFaktor, 2);
    expect(gefechtsPatzerfolge(2, bf: 0, natuerlich: true).schadensFaktor, 2);
    expect(gefechtsPatzerfolge(9, bf: 0, natuerlich: true).sturz, true);
    expect(() => gefechtsPatzerfolge(13, bf: 0), throwsArgumentError);
  });
  test('Bestätigter Patzer verbraucht jede Restmarke und Reserve', () {
    const w = Gefechtswerte(
      iniBasis: 50,
      at: 15,
      pa: 12,
      ausweichen: 10,
      zusatzaktionen: 2,
      schildkampf2: true,
      schildPa: 14,
    );
    final neu = verbraucheGefechtsPatzer(
      const Gefechtszustand(iniWurf: 6, reserveIni: 50, reserveBereit: true),
      w,
      gefechtsPatzerfolge(7, bf: 3),
    );
    expect(gefechtsAngriffe(neu, inklusiveReserve: true), 0);
    expect(gefechtsParaden(neu, w), 0);
    expect(neu.schildparadenVerbraucht, 1);
    expect(neu.zusatzVerbraucht, 2);
    expect(neu.freieVerbraucht, 5);
    expect(neu.iniVerlust, 2);
  });
  test('Frischer Schreibweg trifft ID und erhält fremde Felder', () {
    const w = MainWeaponSlot(
      id: 'w',
      name: 'Schwert',
      breakFactor: 3,
      unbekannteFelder: {'future': 42},
    );
    const x = MainWeaponSlot(id: 'x', name: 'Dolch');
    const c = CombatConfig(weapons: [w, x]);
    final profil = gefechtsBruchprofil(
      c,
      const GefechtsKampfmittelwahl(GefechtsKampfmittelArt.hauptwaffe, 'w'),
    )!;
    final reordered = c.copyWith(weapons: [x, w], selectedWeaponIndex: 1);
    final neu = schreibeGefechtsBruchfaktor(reordered, profil, 4);
    expect(neu.weaponSlots[1].breakFactor, 4);
    expect(neu.weaponSlots[1].unbekannteFelder['future'], 42);
    expect(
      () => schreibeGefechtsBruchfaktor(
        c.copyWith(weapons: [w.copyWith(breakFactor: 8), x]),
        profil,
        4,
      ),
      throwsStateError,
    );
  });
  test('Schildbruchprofil trifft konkreten Eintrag', () {
    const c = CombatConfig(
      offhandEquipment: [
        OffhandEquipmentEntry(
          id: 's',
          name: 'Schild',
          breakFactor: 4,
          type: OffhandEquipmentType.shield,
        ),
      ],
    );
    final p = gefechtsBruchprofil(
      c,
      const GefechtsKampfmittelwahl(GefechtsKampfmittelArt.schild, 's'),
    )!;
    expect(
      schreibeGefechtsBruchfaktor(c, p, 5).offhandEquipment.single.breakFactor,
      5,
    );
    expect(p.wahl.id, 's');
  });
}
