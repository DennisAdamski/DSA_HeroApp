import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_tragkraft_bonus.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/tragkraft_rules.dart';

// Last und Tragkraft (SPIEL-02, WdS S. 144): TK = KK in Stein, Last = Gewicht
// der Gegenstände plus die Hälfte dessen, was eng am Körper getragen wird
// (Kleidung, Rüstung, getragene Ausrüstung, Waffen in den Händen). Nur
// Dauerhaftes zählt; die Eigenschaften kommen ohne laufende Zauber herein.

const Attributes _werte = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 14,
  kk: 13,
);

HeroSheet _held({
  List<HeroInventoryEntry> eintraege = const <HeroInventoryEntry>[],
  String dukaten = '',
  List<HeroTragkraftBonus> boni = const <HeroTragkraftBonus>[],
  bool episch = false,
  Attributes haupt = const Attributes.zero(),
}) => HeroSheet(
  id: 'h',
  name: 'Held',
  level: 1,
  attributes: _werte,
  apTotal: 0,
  apSpent: 0,
  apAvailable: 0,
  inventoryEntries: eintraege,
  dukaten: dukaten,
  tragkraftBoni: boni,
  isEpisch: episch,
  epicMainAttributes: haupt,
);

HeroInventoryEntry _stueck(
  int gramm, {
  int menge = 1,
  InventoryItemSource source = InventoryItemSource.manuell,
  InventoryItemType typ = InventoryItemType.sonstiges,
  bool ausgeruestet = false,
  InventoryTraeger traeger = InventoryTraeger.held,
}) => HeroInventoryEntry(
  gegenstand: 'Ding',
  gewichtGramm: gramm,
  anzahl: '$menge',
  menge: menge,
  source: source,
  itemType: typ,
  istAusgeruestet: ausgeruestet,
  traegerTyp: traeger,
);

TragkraftErgebnis _rechne(
  HeroSheet held, {
  bool epik = true,
  Attributes werte = _werte,
}) =>
    berechneTragkraft(hero: held, permanent: werte, epicAdvantagesActive: epik);

void main() {
  group('Tragkraft', () {
    test('entspricht der Körperkraft in Stein', () {
      final e = _rechne(_held());
      expect(e.tragkraftStein, 13);
      expect(e.tragkraftGramm, 13000);
      expect(e.lastGramm, 0);
      expect(e.stufe, TragkraftStufe.frei);
      expect(e.zusatzBe, 0);
      expect(e.hinweis, isNull);
    });

    test('rechnet mit der Körperkraft ohne laufende Zauber', () {
      // Der Aufrufer reicht die dauerhaften Eigenschaften; ein Zauber-Bonus
      // auf KK käme hier nie an.
      final e = _rechne(_held(), werte: _werte.copyWith(kk: 15));
      expect(e.tragkraftStein, 15);
    });

    test('Bärenrune: RkP* mal 10 Stein, Hausregel zusätzlich KK +1', () {
      final rune = baerenruneBonus(id: 'r', rkp: 7);
      expect(rune.stein, 70);
      expect(rune.kk, 0);
      expect(rune.name, 'Bärenrune (RkP* 7)');
      expect(_rechne(_held(boni: [rune])).tragkraftStein, 83);

      final mitHausregel = baerenruneBonus(id: 'r', rkp: 7, hausregelKk: true);
      expect(mitHausregel.kk, 1);
      expect(_rechne(_held(boni: [mitHausregel])).tragkraftStein, 84);
    });

    test('mehrere Quellen addieren sich, die Herleitung nennt sie', () {
      final e = _rechne(
        _held(
          boni: const [
            HeroTragkraftBonus(id: 'a', name: 'Gürtel', stein: 5),
            HeroTragkraftBonus(id: 'b', name: 'Bärenrune', stein: 20, kk: 1),
          ],
        ),
      );
      expect(e.tragkraftStein, 13 + 1 + 5 + 20);
      expect(tragkraftFormel(e.tragkraft), contains('Bärenrune'));
      expect(e.tragkraft.wert, e.tragkraftStein);
    });

    test('epische Haupteigenschaft KK: KK mal 1,5 aufgerundet', () {
      final haupt = const Attributes.zero().copyWith(kk: 1);
      final ohne = _rechne(_held(episch: false, haupt: haupt));
      expect(ohne.tragkraftStein, 13);
      final regelAus = _rechne(_held(episch: true, haupt: haupt), epik: false);
      expect(regelAus.tragkraftStein, 13);
      final andere = _rechne(
        _held(episch: true, haupt: const Attributes.zero().copyWith(mu: 1)),
      );
      expect(andere.tragkraftStein, 13);
      final mit = _rechne(_held(episch: true, haupt: haupt));
      // 13 × 1,5 = 19,5 → 20
      expect(mit.tragkraftStein, 20);
    });

    test('die KK-Quelle der Rune zählt vor der epischen Vervielfachung', () {
      final haupt = const Attributes.zero().copyWith(kk: 1);
      final e = _rechne(
        _held(
          episch: true,
          haupt: haupt,
          boni: [baerenruneBonus(id: 'r', rkp: 2, hausregelKk: true)],
        ),
      );
      // (13 + 1) × 1,5 = 21, dazu 20 Stein
      expect(e.tragkraftStein, 41);
    });

    test('fällt nie unter 0', () {
      final e = _rechne(
        _held(
          boni: const [HeroTragkraftBonus(id: 'a', name: 'Fluch', kk: -20)],
        ),
      );
      expect(e.tragkraftStein, 0);
    });
  });

  group('Last', () {
    test('summiert Stapel aus Stückgewicht mal Menge', () {
      final e = _rechne(
        _held(eintraege: [_stueck(500, menge: 4), _stueck(1500)]),
      );
      expect(e.lastGramm, 3500);
      expect(e.ohneGewicht, 0);
    });

    test('Kleidung und Rüstung am Leib zählen halb, im Gepäck voll', () {
      final getragen = _stueck(
        10000,
        source: InventoryItemSource.ruestung,
        typ: InventoryItemType.ausruestung,
        ausgeruestet: true,
      );
      final imGepaeck = _stueck(
        10000,
        source: InventoryItemSource.ruestung,
        typ: InventoryItemType.ausruestung,
      );
      expect(_rechne(_held(eintraege: [getragen])).lastGramm, 5000);
      expect(_rechne(_held(eintraege: [imGepaeck])).lastGramm, 10000);
      expect(_rechne(_held(eintraege: [getragen])).amLeibGramm, 10000);
    });

    test('getragene Ausrüstung und Kleidung zählen halb', () {
      final kleidung = _stueck(
        2000,
        typ: InventoryItemType.ausruestung,
        ausgeruestet: true,
      );
      expect(_rechne(_held(eintraege: [kleidung])).lastGramm, 1000);
    });

    test('Waffen und Schild in den Händen zählen halb, abgelegt voll', () {
      final schwert = _stueck(
        3000,
        source: InventoryItemSource.waffe,
        typ: InventoryItemType.ausruestung,
        ausgeruestet: true,
      );
      final schild = _stueck(
        4000,
        source: InventoryItemSource.nebenhand,
        typ: InventoryItemType.ausruestung,
        ausgeruestet: true,
      );
      final imGepaeck = _stueck(
        3000,
        source: InventoryItemSource.waffe,
        typ: InventoryItemType.ausruestung,
      );
      expect(_rechne(_held(eintraege: [schwert, schild])).lastGramm, 3500);
      expect(_rechne(_held(eintraege: [imGepaeck])).lastGramm, 3000);
    });

    test('Geschosse, Verbrauchsgut und Sonstiges zählen voll', () {
      final pfeile = _stueck(
        500,
        menge: 10,
        source: InventoryItemSource.geschoss,
        typ: InventoryItemType.verbrauchsgegenstand,
      );
      final beutel = _stueck(2000);
      final proviant = _stueck(
        1000,
        typ: InventoryItemType.verbrauchsgegenstand,
        ausgeruestet: true,
      );
      final e = _rechne(_held(eintraege: [pfeile, beutel, proviant]));
      expect(e.lastGramm, 5000 + 2000 + 1000);
      expect(e.amLeibGramm, 0);
    });

    test('Was ein Begleiter trägt, belastet den Helden nicht', () {
      final e = _rechne(
        _held(
          eintraege: [
            _stueck(8000, traeger: InventoryTraeger.begleiter),
            _stueck(1000),
          ],
        ),
      );
      expect(e.lastGramm, 1000);
    });

    test('Menge 0 zählt nichts und gilt nicht als gewichtslos', () {
      final e = _rechne(_held(eintraege: [_stueck(0, menge: 0)]));
      expect(e.lastGramm, 0);
      expect(e.ohneGewicht, 0);
    });

    test('Einträge ohne Gewicht werden gezählt', () {
      final e = _rechne(
        _held(eintraege: [_stueck(0), _stueck(0), _stueck(100)]),
      );
      expect(e.ohneGewicht, 2);
      expect(e.lastGramm, 100);
    });

    test('Geld wiegt mit: Dukat 25 g, Silbertaler, Heller, Kreuzer je 5 g', () {
      expect(geldGewichtGramm(''), 0);
      expect(geldGewichtGramm('kein Betrag'), 0);
      // 12 D = 300 g, 5 S = 25 g, 3 K = 15 g
      expect(geldGewichtGramm('12 D 5 S 3 K'), 340);
      // 1 Heller = 10 Kreuzer, kleinstmögliche Münzzahl: ein Heller, 5 g
      expect(geldGewichtGramm('10 K'), 5);
      final e = _rechne(_held(dukaten: '12 D 5 S 3 K'));
      expect(e.geldGramm, 340);
      expect(e.lastGramm, 340);
    });
  });

  group('Belastungsstufen (TK 13 Stein)', () {
    TragkraftErgebnis mit(int gramm) =>
        _rechne(_held(eintraege: [_stueck(gramm)]));

    test('bis zur Tragkraft keine Folgen', () {
      final e = mit(13000);
      expect(e.stufe, TragkraftStufe.frei);
      expect(e.zusatzBe, 0);
    });

    test('pro angefangenen 50 % über der Tragkraft steigt die BE um 1', () {
      expect(mit(13001).zusatzBe, 1);
      expect(mit(19500).zusatzBe, 1);
      expect(mit(19501).zusatzBe, 2);
      expect(mit(26000).zusatzBe, 2);
      expect(mit(26001).zusatzBe, 3);
      expect(mit(13001).stufe, TragkraftStufe.belastet);
      expect(mit(13001).hinweis, contains('BE +1'));
    });

    test('über der doppelten Tragkraft: Verschnaufpausen alle KO Runden', () {
      final e = mit(26001);
      expect(e.stufe, TragkraftStufe.verschnaufen);
      expect(e.hinweis, contains('alle 14 Spielrunden'));
      expect(mit(26000).stufe, TragkraftStufe.belastet);
    });

    test('ab der vierfachen Tragkraft: Last alle 5 × KO Schritt absetzen', () {
      final e = mit(52000);
      expect(e.stufe, TragkraftStufe.absetzen);
      expect(e.hinweis, contains('alle 70 Schritt'));
      expect(mit(51999).stufe, TragkraftStufe.verschnaufen);
    });

    test('eine höhere Tragkraft verschiebt die Stufen', () {
      final rune = baerenruneBonus(id: 'r', rkp: 7);
      final e = _rechne(_held(eintraege: [_stueck(40000)], boni: [rune]));
      expect(e.tragkraftStein, 83);
      expect(e.stufe, TragkraftStufe.frei);
    });
  });

  group('Quellen ändern', () {
    test('mitTragkraftBonus legt an und ersetzt per ID', () {
      final held = _held();
      final a = mitTragkraftBonus(
        held,
        const HeroTragkraftBonus(id: 'a', name: 'A', stein: 3),
      );
      expect(a.tragkraftBoni, hasLength(1));
      final b = mitTragkraftBonus(
        a,
        const HeroTragkraftBonus(id: 'a', name: 'A2', stein: 4),
      );
      expect(b.tragkraftBoni, hasLength(1));
      expect(b.tragkraftBoni.single.name, 'A2');
      // Alles andere bleibt.
      expect(b.attributes, held.attributes);
    });

    test('ersetzen bewahrt unbekannte Felder der alten Quelle', () {
      final alt = HeroTragkraftBonus.fromJson(<String, dynamic>{
        'id': 'a',
        'name': 'A',
        'stein': 1,
        'zukunft': 'x',
      })!;
      final held = _held(boni: [alt]);
      final neu = mitTragkraftBonus(
        held,
        const HeroTragkraftBonus(id: 'a', name: 'A2', stein: 2),
      );
      expect(neu.tragkraftBoni.single.toJson()['zukunft'], 'x');
    });

    test('ohneTragkraftBonus entfernt; fehlt sie, kommt der Held selbst', () {
      final held = _held(
        boni: const [HeroTragkraftBonus(id: 'a', name: 'A', stein: 3)],
      );
      expect(ohneTragkraftBonus(held, 'a').tragkraftBoni, isEmpty);
      expect(identical(ohneTragkraftBonus(held, 'x'), held), isTrue);
    });
  });

  group('Anzeige', () {
    test('formatiereStein mit Dezimalkomma', () {
      expect(formatiereStein(0), '0');
      expect(formatiereStein(14000), '14');
      expect(formatiereStein(23500), '23,5');
      expect(formatiereStein(340), '0,3');
    });
  });
}
