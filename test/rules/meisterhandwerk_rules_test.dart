import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meisterhandwerk_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_herleitung_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_support/real_catalog.dart';

/// Magisches Meisterhandwerk (WdH S. 256, WdZ S. 37).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RulesCatalog catalog;

  setUpAll(() async {
    catalog = (await ladeEchtenRegelkatalog()).catalog;
  });

  HeroMerkmal meisterhandwerk(String talent, {String variante = 'viertel'}) {
    return HeroMerkmal(
      katalogId: 'adv_meisterhandwerk_${variante}zauberer',
      text: 'Meisterhandwerk $talent',
      auswahl: talent,
    );
  }

  HeroSheet held(List<HeroMerkmal> vorteile) {
    return HeroSheet(
      id: 'h',
      name: 'Test',
      level: 1,
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      ),
      vorteilEintraege: vorteile,
    );
  }

  /// Talentprobe mit TaW [taw] in der Herleitung und Pool [pool].
  ResolvedProbeRequest probe(
    String talent, {
    int taw = 7,
    int? pool,
    String? titel,
  }) {
    return ResolvedProbeRequest(
      type: ProbeType.talent,
      title: titel ?? 'Talentprobe: $talent',
      subtitle: 'IN / CH / KO',
      ruleHint: '',
      diceSpec: const DiceSpec(count: 3, sides: 20),
      targets: const <ProbeTargetValue>[
        ProbeTargetValue(label: 'IN', value: 12),
        ProbeTargetValue(label: 'CH', value: 12),
        ProbeTargetValue(label: 'KO', value: 12),
      ],
      basePool: pool ?? taw,
      poolHerleitung: Herleitung(
        bezeichnung: 'TaW*',
        schritte: <HerleitungsSchritt>[
          HerleitungsSchritt(
            bezeichnung: kTalentTawSchritt,
            betrag: taw,
            art: HerleitungsArt.zukauf,
          ),
          if (pool != null && pool != taw)
            HerleitungsSchritt(
              bezeichnung: 'BE',
              betrag: pool - taw,
              art: HerleitungsArt.modifikator,
            ),
        ],
      ),
    );
  }

  ProbeResult wurf(ResolvedProbeRequest request, List<int> wuerfe) {
    return evaluateProbe(
      request,
      ProbeRollInput(
        mode: ProbeRollMode.manual,
        diceValues: wuerfe,
        situationalModifier: 0,
        specializationApplied: false,
      ),
    );
  }

  MeisterhandwerkAngebot angebot({int taw = 7, int asp = 20}) {
    return MeisterhandwerkAngebot(
      talent: 'Singen',
      taw: taw,
      verfuegbareAsp: asp,
      quelle: 'Meisterhandwerk Singen',
    );
  }

  group('Wirkung und Auswahl', () {
    test('alle drei Varianten liefern das gewählte Talent', () {
      final hero = held(<HeroMerkmal>[
        meisterhandwerk('Singen'),
        meisterhandwerk('Grobschmied', variante: 'halb'),
        meisterhandwerk('Fährtensuchen', variante: 'voll'),
      ]);

      final wirkungen = meisterhandwerkWirkungen(hero, catalog: catalog);

      expect(wirkungen.map((w) => w.auswahl), <String>[
        'Singen',
        'Grobschmied',
        'Fährtensuchen',
      ]);
      expect(wirkungen.first.quelle, 'Meisterhandwerk Singen');
    });

    test('ohne Katalog wirkt kein Meisterhandwerk', () {
      final hero = held(<HeroMerkmal>[meisterhandwerk('Singen')]);
      expect(meisterhandwerkWirkungen(hero, catalog: null), isEmpty);
    });

    test('höchstens fünf Talente über alle Varianten', () {
      final fuenf = <HeroMerkmal>[
        meisterhandwerk('Singen'),
        meisterhandwerk('Musizieren'),
        meisterhandwerk('Grobschmied', variante: 'halb'),
        meisterhandwerk('Fährtensuchen', variante: 'voll'),
        meisterhandwerk('Klettern'),
      ];
      expect(
        meisterhandwerkGrenzeUeberschritten(fuenf, catalog: catalog),
        isFalse,
      );
      expect(
        meisterhandwerkGrenzeUeberschritten(<HeroMerkmal>[
          ...fuenf,
          meisterhandwerk('Tanzen'),
        ], catalog: catalog),
        isTrue,
      );
    });
  });

  group('Angebot', () {
    final wirkungen = <MeisterhandwerkWirkung>[
      const MeisterhandwerkWirkung(
        auswahl: 'Singen',
        quelle: 'Meisterhandwerk Singen',
      ),
    ];

    test('nur für Proben auf ein gewähltes Talent', () {
      final treffer = meisterhandwerkAngebotFuer(
        request: probe('Singen', taw: 9, pool: 6),
        wirkungen: wirkungen,
        verfuegbareAsp: 12,
      );
      expect(treffer, isNotNull);
      expect(treffer!.taw, 9, reason: 'Roh-TaW, nicht TaW*');
      expect(treffer.verfuegbareAsp, 12);
      expect(treffer.quelle, 'Meisterhandwerk Singen');

      expect(
        meisterhandwerkAngebotFuer(
          request: probe('Tanzen'),
          wirkungen: wirkungen,
          verfuegbareAsp: 12,
        ),
        isNull,
      );
    });

    test('nicht für Ersatzproben, bei TaW 0 oder ohne AsP', () {
      expect(
        meisterhandwerkAngebotFuer(
          request: probe(
            'Singen',
            titel: 'Talentprobe: Singen (über Musizieren)',
          ),
          wirkungen: wirkungen,
          verfuegbareAsp: 12,
        ),
        isNull,
      );
      expect(
        meisterhandwerkAngebotFuer(
          request: probe('Singen', taw: 0),
          wirkungen: wirkungen,
          verfuegbareAsp: 12,
        ),
        isNull,
      );
      expect(
        meisterhandwerkAngebotFuer(
          request: probe('Singen'),
          wirkungen: wirkungen,
          verfuegbareAsp: 0,
        ),
        isNull,
      );
    });
  });

  group('Vorab', () {
    test('zwei TaW je AsP, höchstens bis zum doppelten TaW', () {
      expect(meisterhandwerkMaxVorabAsp(angebot(taw: 7)), 3);
      expect(meisterhandwerkMaxVorabAsp(angebot(taw: 8)), 4);
      expect(meisterhandwerkMaxVorabAsp(angebot(taw: 8, asp: 2)), 2);
    });

    test('erhöht Pool und Herleitung', () {
      final request = wendeMeisterhandwerkVorabAn(probe('Singen', taw: 7), 3);

      expect(request.basePool, 13);
      final schritt = request.poolHerleitung!.schritte.last;
      expect(schritt.bezeichnung, 'Meisterhandwerk (3 AsP)');
      expect(schritt.betrag, 6);
      expect(request.poolHerleitung!.wert, request.basePool);
    });

    test('ohne Einsatz bleibt die Probe dieselbe', () {
      final original = probe('Singen');
      expect(
        identical(wendeMeisterhandwerkVorabAn(original, 0), original),
        isTrue,
      );
    });

    test('Buchung beschreibt den Einsatz', () {
      final buchung = meisterhandwerkVorabBuchung(angebot(), 3);
      expect(buchung.asp, 3);
      expect(buchung.erschoepfung, 0);
      expect(buchung.beschreibung, '3 AsP vorab (+6 TaW)');
    });
  });

  group('Nachträglich', () {
    test('rettet eine misslungene Probe für die fehlenden TaP', () {
      // TaW 7, Überschreitung 4 + 5 = 9: es fehlen 2 TaP.
      final ergebnis = wurf(probe('Singen'), <int>[16, 17, 10]);
      expect(ergebnis.success, isFalse);

      final nachtrag = meisterhandwerkNachtragFuer(
        result: ergebnis,
        angebot: angebot(),
        verfuegbareAsp: 20,
      )!;
      expect(nachtrag.art, MeisterhandwerkNachtragArt.rettung);
      expect(nachtrag.rettungsKosten, 2);

      final gerettet = wendeMeisterhandwerkNachtragAn(ergebnis, nachtrag, 0);
      expect(gerettet.success, isTrue);
      expect(gerettet.remainingPool, 0, reason: 'knapper Erfolg');
      expect(
        meisterhandwerkNachtragBuchung(angebot(), nachtrag, 0).beschreibung,
        '2 AsP: Probe gerettet',
      );
    });

    test('keine Rettung bei Patzer, über TaW oder ohne genug AsP', () {
      final patzer = wurf(probe('Singen'), <int>[20, 20, 3]);
      expect(
        meisterhandwerkNachtragFuer(
          result: patzer,
          angebot: angebot(),
          verfuegbareAsp: 20,
        ),
        isNull,
      );

      // Es fehlen 8 TaP bei TaW 7.
      final weit = wurf(probe('Singen'), <int>[20, 19, 10]);
      expect(-weit.remainingPool, 8);
      expect(
        meisterhandwerkNachtragFuer(
          result: weit,
          angebot: angebot(),
          verfuegbareAsp: 20,
        ),
        isNull,
      );

      final knapp = wurf(probe('Singen'), <int>[16, 17, 10]);
      expect(
        meisterhandwerkNachtragFuer(
          result: knapp,
          angebot: angebot(),
          verfuegbareAsp: 1,
        ),
        isNull,
      );
    });

    test('verbessert eine gelungene Probe: erst 1:1, dann 2 AsP und '
        'Erschöpfung bis zum TaW', () {
      // TaW 7, Überschreitung 5: TaP* 2.
      final ergebnis = wurf(probe('Singen'), <int>[17, 10, 10]);
      expect(ergebnis.remainingPool, 2);

      final nachtrag = meisterhandwerkNachtragFuer(
        result: ergebnis,
        angebot: angebot(),
        verfuegbareAsp: 20,
      )!;
      expect(nachtrag.art, MeisterhandwerkNachtragArt.verbesserung);
      expect(nachtrag.guenstigePunkte, 2);
      expect(nachtrag.teurePunkte, 3, reason: 'TaP* insgesamt bis TaW 7');

      expect(meisterhandwerkNachtragKosten(nachtrag, 2), (
        asp: 2,
        erschoepfung: 0,
      ));
      expect(meisterhandwerkNachtragKosten(nachtrag, 4), (
        asp: 6,
        erschoepfung: 2,
      ));
      expect(meisterhandwerkNachtragKosten(nachtrag, 99), (
        asp: 8,
        erschoepfung: 3,
      ), reason: 'gekappt auf das Erlaubte');

      final verbessert = wendeMeisterhandwerkNachtragAn(ergebnis, nachtrag, 4);
      expect(verbessert.success, isTrue);
      expect(verbessert.remainingPool, 6);
      expect(
        meisterhandwerkNachtragBuchung(angebot(), nachtrag, 4).beschreibung,
        'TaP* +4: 6 AsP, 2 Erschöpfung',
      );
    });

    test('teure Punkte nur mit genug AsP', () {
      final ergebnis = wurf(probe('Singen'), <int>[17, 10, 10]);
      final knapp = meisterhandwerkNachtragFuer(
        result: ergebnis,
        angebot: angebot(),
        verfuegbareAsp: 3,
      )!;
      expect(knapp.guenstigePunkte, 2);
      expect(knapp.teurePunkte, 0, reason: '1 AsP reicht für keinen teuren');
    });

    test('ohne TaP* nur teure Punkte, über dem TaW nur günstige', () {
      final knappGelungen = wurf(probe('Singen'), <int>[19, 10, 10]);
      expect(knappGelungen.remainingPool, 0);
      final nachtrag = meisterhandwerkNachtragFuer(
        result: knappGelungen,
        angebot: angebot(),
        verfuegbareAsp: 20,
      )!;
      expect(nachtrag.guenstigePunkte, 0);
      expect(nachtrag.teurePunkte, 7);

      // TaP* schon über dem TaW (Vorab-Einsatz): keine teuren Punkte mehr.
      final hoch = wurf(wendeMeisterhandwerkVorabAn(probe('Singen'), 3), <int>[
        3,
        3,
        3,
      ]);
      expect(hoch.remainingPool, 13);
      final mehr = meisterhandwerkNachtragFuer(
        result: hoch,
        angebot: angebot(),
        verfuegbareAsp: 5,
      )!;
      expect(mehr.guenstigePunkte, 5);
      expect(mehr.teurePunkte, 0);
    });
  });
}
