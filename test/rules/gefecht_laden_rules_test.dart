import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_fernkampf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_ansagen_paket2_test.dart' as fixture;
import '../ui2/shell/karto_test_support.dart';

/// Realer FK-Snapshot für Regeln und dieselben Widgetabläufe.
HeroComputedSnapshot ladeSnapshot({
  int dauer = 4,
  bool schnell = false,
  String id = 'a',
  int geschoss = 0,
  bool nebenhand = false,
  bool kampfgespuer = false,
  String? art,
}) {
  final b = fixture.ansageSnapshot();
  final waffenart = art ?? (nebenhand ? 'Balestrina' : 'Armbrust');
  final w = b.hero.combatConfig.selectedWeapon.copyWith(
    id: id,
    // Die Nebenhandprüfung nutzt die belegte einhändige Armbrust-Ausnahme.
    name: waffenart,
    weaponType: waffenart,
    talentId: waffenart == 'Balestrina'
        ? 'tal_armbrust'
        : b.hero.combatConfig.selectedWeapon.talentId,
    combatType: WeaponCombatType.ranged,
    rangedProfile: RangedWeaponProfile(
      reloadTime: dauer,
      selectedProjectileIndex: geschoss,
      projectiles: const [
        RangedProjectile(id: 'p1', name: 'Bolzen', count: 5),
        RangedProjectile(id: 'p2', name: 'Brandbolzen', count: 5),
      ],
      distanceBands: const [
        RangedDistanceBand(label: '5'),
        RangedDistanceBand(label: '10'),
        RangedDistanceBand(label: '20'),
        RangedDistanceBand(label: '40'),
        RangedDistanceBand(label: '80'),
      ],
    ),
  );
  return buildHeroComputedSnapshot(
    hero: b.hero.copyWith(
      combatConfig: b.hero.combatConfig.copyWith(
        weapons: nebenhand
            ? [const MainWeaponSlot(id: 's', name: 'Schwert'), w]
            : [w],
        offhandAssignment: nebenhand
            ? const OffhandAssignment(weaponIndex: 1)
            : const OffhandAssignment(),
        specialRules: CombatSpecialRules(
          kampfgespuer: kampfgespuer,
          activeManeuvers: schnell ? ['man_schnellladen_armbrust'] : [],
        ),
      ),
    ),
    state: const HeroState.empty(),
    catalog: testCatalog,
    epicAdvantagesActive: false,
  );
}

const mittel = GefechtsKampfmittelwahl(GefechtsKampfmittelArt.hauptwaffe, 'a');

/// Bestätigter Auftrag mit drei zusätzlichen Zielaktionen.
const zielauftrag = GefechtAuftrag(
  aktion: Gefechtsaktion.angriff,
  titel: 'Angreifen',
  zuschlag: 0,
  dk: null,
  dauer: 1,
  kosten: 1,
  fernkampfansage: 5,
  kampfmittel: mittel,
  kontext: Gefechtskontext(
    kontakt: 'Ork',
    geladen: true,
    entfernung: 5,
    situationsZuschlag: 0,
  ),
);

void main() {
  test('Fertig bezahltes Zielen erlaubt spontane KG-Umwandlung mit Zuschlag ohne Erstattung', () {
    final basis = ladeSnapshot();
    final snap = buildHeroComputedSnapshot(
      hero: basis.hero.copyWith(
        combatConfig: basis.hero.combatConfig.copyWith(
          specialRules: const CombatSpecialRules(kampfgespuer: true),
        ),
      ),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    var s = beginneGefechtsZielen(
      const Gefechtszustand(iniWurf: 6),
      snap,
      testCatalog,
      zielauftrag,
    );
    s = bezahleGefechtsVorbereitung(s, snap);
    s = bezahleGefechtsVorbereitung(naechsteGefechtsrunde(s), snap);
    final w = gefechtswerteFuer(snap);
    expect(s.handlung!.verbleibend, 0);
    expect(
      gefechtUmwandlungMoeglich(s, Gefechtsumwandlung.zweiteAttacke, werte: w),
      true,
    );
    final neu = wandleGefechtUm(
      s,
      Gefechtsumwandlung.zweiteAttacke,
      werte: w,
      rundenbeginn: false,
    );
    expect(neu.angriffeVerbraucht, 1);
    expect(neu.handlung, same(s.handlung));
    expect(neu.zielstand, same(s.zielstand));
    final p = pruefeGefechtsZielschuss(neu, snap, testCatalog);
    expect(p.ausfuehrbar, true);
    expect(p.erschwernis, 7, reason: 'Entfernung -2, Ansage5, Umwandlung4.');
    expect(
      gefechtUmwandlungMoeglich(
        s,
        Gefechtsumwandlung.zweiteAttacke,
        werte: gefechtswerteFuer(basis),
      ),
      false,
    );
  });
  test('Ladung derselben physischen Waffe bleibt beim Handwechsel; fremde ID unbekannt', () {
    // Derselbe gültige Waffentyp bleibt beim tatsächlichen Handwechsel erhalten.
    final snap = ladeSnapshot(dauer: 1, art: 'Balestrina');
    final geladen = beginneGefechtsLaden(
      const Gefechtszustand(iniWurf: 6),
      snap,
      mittel,
      anfangGeladen: false,
    );
    final neben = ladeSnapshot(dauer: 1, nebenhand: true);
    expect(
      gefechtsLadezustand(geladen, neben.hero.combatConfig.weaponSlots[1]),
      true,
    );
    expect(
      gefechtsLadezustand(
        geladen,
        ladeSnapshot(id: 'b').hero.combatConfig.selectedWeapon,
      ),
      isNull,
    );
  });
  test('Entladene Waffe kann nicht mit erneuter Anfangsangabe oder Schusskontext laden', () {
    final snap = ladeSnapshot();
    final leer = bestaetigeGefechtsLadung(
      const Gefechtszustand(iniWurf: 6),
      snap.hero.combatConfig.selectedWeapon,
      false,
    );
    final neu = beginneGefechtsLaden(leer, snap, mittel, anfangGeladen: true);
    expect(neu.handlung!.verbleibend, 3);
    expect(
      gefechtsLadezustand(neu, snap.hero.combatConfig.selectedWeapon),
      false,
    );
    final p = pruefeGefechtsFernkampf(
      leer.copyWith(kontext: zielauftrag.kontext),
      snap.hero.combatConfig.selectedWeapon,
    );
    expect(p.sperren.join(), contains('nicht geladen'));
  });
  test('Längere aktuelle Ladezeit erhält bezahlte Aktionen; Profilwechsel erklärt Sperre', () {
    final snap = ladeSnapshot();
    final s = beginneGefechtsLaden(
      const Gefechtszustand(iniWurf: 6),
      snap,
      mittel,
      anfangGeladen: false,
    );
    final p = pruefeGefechtsVorbereitung(s, ladeSnapshot(dauer: 8));
    expect(p.bezahlt, 1);
    expect(p.rest, 7);
    expect(p.hinweise.join(), contains('erhalten'));
    final anders = ladeSnapshot(geschoss: 1);
    expect(
      pruefeGefechtsVorbereitung(s, anders).gruende.join(),
      contains('Geschossprofil'),
    );
  });
  test('Zielkontaktwechsel und leere stabile ID verhindern Übertragung', () {
    final snap = ladeSnapshot();
    final s = beginneGefechtsZielen(
      const Gefechtszustand(iniWurf: 6),
      snap,
      testCatalog,
      zielauftrag,
    );
    final andererKontakt = s.copyWith(
      kontext: const Gefechtskontext(kontakt: 'Goblin'),
    );
    expect(
      pruefeGefechtsVorbereitung(andererKontakt, snap).gruende.join(),
      contains('Zielkontakt geändert'),
    );
    final ohneId = ladeSnapshot(id: '');
    expect(
      () => beginneGefechtsLaden(
        const Gefechtszustand(iniWurf: 6),
        ohneId,
        const GefechtsKampfmittelwahl(GefechtsKampfmittelArt.hauptwaffe, ''),
        anfangGeladen: false,
      ),
      throwsStateError,
    );
  });
  test('Laden bezahlt regulär über Runden und lädt erst am Ende', () {
    final snap = ladeSnapshot();
    var s = const Gefechtszustand(iniWurf: 6);
    s = beginneGefechtsLaden(s, snap, mittel, anfangGeladen: false);
    expect(s.handlung!.vorbereitung!.bezahlteAktionen, 1);
    expect(
      gefechtsLadezustand(s, snap.hero.combatConfig.selectedWeapon),
      false,
    );
    s = bezahleGefechtsVorbereitung(s, snap);
    expect(s.paradenVerbraucht, 1);
    expect(() => bezahleGefechtsVorbereitung(s, snap), throwsStateError);
    s = naechsteGefechtsrunde(s);
    s = bezahleGefechtsVorbereitung(s, snap);
    s = bezahleGefechtsVorbereitung(s, snap);
    expect(s.handlung, isNull);
    expect(gefechtsLadezustand(s, snap.hero.combatConfig.selectedWeapon), true);
  });
  test(
    'Dynamische Verkürzung behält Zahlung, Abschluss kostet keine neue Marke',
    () {
      final snap = ladeSnapshot();
      var s = beginneGefechtsLaden(
        const Gefechtszustand(iniWurf: 6),
        snap,
        mittel,
        anfangGeladen: false,
      );
      s = bezahleGefechtsVorbereitung(s, snap);
      s = naechsteGefechtsrunde(s);
      s = bezahleGefechtsVorbereitung(s, snap);
      final p = pruefeGefechtsVorbereitung(s, ladeSnapshot(schnell: true));
      expect(p.rest, 0);
      expect(p.bezahlt, 3);
      expect(p.hinweise.join(), contains('erhalten'));
      final fertig = bezahleGefechtsVorbereitung(
        s,
        ladeSnapshot(schnell: true),
      );
      expect(fertig.angriffeVerbraucht, s.angriffeVerbraucht);
      expect(fertig.paradenVerbraucht, s.paradenVerbraucht);
      expect(fertig.handlung, isNull);
    },
  );
  test('Waffen- und Geschosswechsel sperren ohne Fortschrittsübertragung', () {
    final snap = ladeSnapshot();
    final s = beginneGefechtsLaden(
      const Gefechtszustand(iniWurf: 6),
      snap,
      mittel,
      anfangGeladen: false,
    );
    for (final anders in [ladeSnapshot(id: 'b'), ladeSnapshot(geschoss: 1)]) {
      expect(pruefeGefechtsVorbereitung(s, anders).ausfuehrbar, false);
      expect(() => bezahleGefechtsVorbereitung(s, anders), throwsStateError);
    }
    final abbruch = s.copyWith(ohneHandlung: true);
    expect(abbruch.angriffeVerbraucht, 1);
    expect(
      gefechtsLadezustand(abbruch, snap.hero.combatConfig.selectedWeapon),
      false,
    );
  });
  test('Unbekannter Anfang und Zusatzparade ersetzen keine Ladezahlung', () {
    final snap = ladeSnapshot();
    expect(
      () =>
          beginneGefechtsLaden(const Gefechtszustand(iniWurf: 6), snap, mittel),
      throwsStateError,
    );
    const leer = Gefechtszustand(
      iniWurf: 6,
      angriffeVerbraucht: 1,
      paradenVerbraucht: 1,
      zusatzVerbraucht: 0,
    );
    expect(
      () => beginneGefechtsLaden(leer, snap, mittel, anfangGeladen: false),
      throwsStateError,
    );
  });
  test(
    'Bezahltes Zielen erhält Auftrag über Runden ohne Probe oder Doppelzahlung',
    () {
      final snap = ladeSnapshot();
      var s = beginneGefechtsZielen(
        const Gefechtszustand(iniWurf: 6),
        snap,
        testCatalog,
        zielauftrag,
      );
      expect(s.handlung!.art, Gefechtshandlungsart.zielen);
      expect(s.handlung!.vorbereitung!.schussauftrag, same(zielauftrag));
      expect(s.zielstand!.bezahlteAktionen, 1);
      s = bezahleGefechtsVorbereitung(s, snap);
      s = naechsteGefechtsrunde(s);
      s = bezahleGefechtsVorbereitung(s, snap);
      expect(s.zielstand!.bezahlteAktionen, 3);
      expect(s.handlung!.verbleibend, 0);
      final doppelt = bezahleGefechtsVorbereitung(s, snap);
      expect(doppelt.angriffeVerbraucht, s.angriffeVerbraucht);
      expect(doppelt.zielstand!.bezahlteAktionen, 3);
      expect(
        pruefeGefechtsVorbereitung(s, ladeSnapshot(geschoss: 1)).ausfuehrbar,
        false,
      );
    },
  );
  test(
    'Geführte Nebenhand wird geladen ohne Hauptwaffenzustand zu übernehmen',
    () {
      final snap = ladeSnapshot(dauer: 1, nebenhand: true);
      const neben = GefechtsKampfmittelwahl(
        GefechtsKampfmittelArt.nebenwaffe,
        'a',
      );
      final s = beginneGefechtsLaden(
        const Gefechtszustand(iniWurf: 6),
        snap,
        neben,
        anfangGeladen: false,
      );
      expect(s.handlung, isNull);
      expect(
        gefechtsLadezustand(s, snap.hero.combatConfig.weaponSlots[1]),
        true,
      );
      expect(
        gefechtsLadezustand(s, snap.hero.combatConfig.selectedWeapon),
        isNull,
      );
    },
  );
}
