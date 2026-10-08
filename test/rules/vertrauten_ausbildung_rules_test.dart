import 'package:dsa_heldenverwaltung/catalog/vertrautenmagie_preset.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_kampfprofil_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_wirkwert_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vertrauten_ausbildung_rules.dart';
import 'package:flutter_test/flutter_test.dart';

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

HeroCompanion _vertrauter({
  String artId = 'vart_hund',
  bool machtvoll = false,
  List<VertrautenAusbildungsbuchung> ausbildungen = const [],
  int apGesamt = 1000,
  int kl = 2,
}) => HeroCompanion(
  id: 'v',
  typ: BegleiterTyp.vertrauter,
  kl: kl,
  ge: 10,
  ini: 8,
  maxLep: 24,
  startLep: 24,
  apGesamt: apGesamt,
  angriffe: const [HeroCompanionAttack(id: 'biss', at: 11, pa: 6, tp: '1W6+3')],
  geschwindigkeiten: const [HeroCompanionSpeed(art: 'Boden', wert: 10)],
  ritualCategories: [
    kVertrautenmagiePresetCategory.copyWith(
      rituals: [
        kVertrautenmagiePresetCategory.rituals.firstWhere(
          (r) => r.name == 'Zwiegespräch',
        ),
      ],
    ),
  ],
  vertrautenBindung: VertrautenBindung(
    artId: artId,
    machtvoll: machtvoll,
    ausbildungen: ausbildungen,
  ),
);

HeroSheet _hexe(HeroCompanion v) => HeroSheet(
  id: 'hexe',
  name: 'Hexe',
  level: 1,
  apTotal: 1000,
  apSpent: 500,
  apAvailable: 500,
  attributes: _attribute,
  companions: [v],
);

void main() {
  group('vertrautenZauberZugaenge (WdZ S. 126–128)', () {
    VertrautenZauberZugang zugang(HeroCompanion c, String name) =>
        vertrautenZauberZugaenge(c).firstWhere((z) => z.zauber.name == name);

    test('artgebundene Zauber und Machtvolle', () {
      final hund = _vertrauter();
      expect(zugang(hund, 'Tarnung').sperrgrund, contains('Kröte'));
      expect(zugang(hund, 'Wachsame Augen').sperrgrund, contains('Machtvolle'));
      expect(zugang(hund, 'Zwiegespräch').bekannt, isTrue);
      expect(zugang(hund, 'Tiersinne').lernbar, isTrue);
      expect(zugang(hund, 'Erster unter Gleichen').lernkosten, 20);

      final machtvoll = _vertrauter(machtvoll: true);
      expect(zugang(machtvoll, 'Erster unter Gleichen').lernkosten, 10);
      expect(zugang(machtvoll, 'Wachsame Augen').lernbar, isTrue);
    });
  });

  group('lerneVertrautenZauber', () {
    test('übernimmt das Ritual und zahlt aus den AP des Vertrauten', () {
      final held = lerneVertrautenZauber(
        _hexe(_vertrauter()),
        begleiterId: 'v',
        ritualName: 'Tiersinne',
        apKosten: 15,
      );
      final v = held.companions.single;
      expect(v.apAusgegeben, 15);
      expect(held.apSpent, 500, reason: 'die Hexe zahlt nichts');
      expect(v.ritualCategories.single.rituals.map((r) => r.name), [
        'Zwiegespräch',
        'Tiersinne',
      ]);
    });

    test('bekannte Zauber und zu wenig AP werden abgewiesen', () {
      expect(
        () => lerneVertrautenZauber(
          _hexe(_vertrauter()),
          begleiterId: 'v',
          ritualName: 'Zwiegespräch',
          apKosten: 0,
        ),
        throwsStateError,
      );
      expect(
        () => lerneVertrautenZauber(
          _hexe(_vertrauter(apGesamt: 10)),
          begleiterId: 'v',
          ritualName: 'Tiersinne',
          apKosten: 15,
        ),
        throwsStateError,
      );
    });

    test('ohne Vertrautenmagie gibt es nichts zu lernen', () {
      final ohne = _vertrauter().copyWith(
        ritualCategories: const <HeroRitualCategory>[],
      );
      expect(
        () => lerneVertrautenZauber(
          _hexe(ohne),
          begleiterId: 'v',
          ritualName: 'Tiersinne',
          apKosten: 15,
        ),
        throwsStateError,
      );
    });
  });

  group('vertrautenAusbildungSperrgrund (WdZ S. 124, ZBA S. 20 f.)', () {
    test('Kampftier ist gesperrt, auch per Meisterentscheid', () {
      final hund = _vertrauter();
      expect(
        vertrautenAusbildungSperrgrund(hund, 'vausb_kampftier'),
        contains('nicht wählbar'),
      );
      expect(
        () => bucheVertrautenAusbildung(
          _hexe(hund),
          begleiterId: 'v',
          katalogId: 'vausb_kampftier',
          apKosten: 500,
          erwarteteAnzahl: 0,
          meisterentscheid: true,
        ),
        throwsStateError,
      );
    });

    test('nur eine Stufe, beim Hund zwei', () {
      const jagd = VertrautenAusbildungsbuchung(katalogId: 'vausb_jagdtier');
      expect(
        vertrautenAusbildungSperrgrund(
          _vertrauter(artId: 'vart_katze', ausbildungen: const [jagd]),
          'vausb_zirkustier',
        ),
        contains('eine Ausbildungsstufe'),
      );
      expect(
        vertrautenAusbildungSperrgrund(
          _vertrauter(ausbildungen: const [jagd]),
          'vausb_wachtier',
        ),
        isNull,
      );
    });

    test('Voraussetzung und höchstens KL Tricks', () {
      final ohneSitz = _vertrauter();
      expect(
        vertrautenAusbildungSperrgrund(ohneSitz, 'vfert_ablegen'),
        contains('Sitz'),
      );
      final zweiTricks = _vertrauter(
        ausbildungen: const [
          VertrautenAusbildungsbuchung(katalogId: 'vfert_trick'),
          VertrautenAusbildungsbuchung(katalogId: 'vfert_trick'),
        ],
      );
      expect(
        vertrautenAusbildungSperrgrund(zweiTricks, 'vfert_trick'),
        contains('KL (2)'),
      );
    });
  });

  group('bucheVertrautenAusbildung', () {
    test('zahlt aus den AP des Vertrauten und wirkt abgeleitet', () {
      final held = bucheVertrautenAusbildung(
        _hexe(_vertrauter()),
        begleiterId: 'v',
        katalogId: 'vausb_jagdtier',
        apKosten: 400,
        erwarteteAnzahl: 0,
      );
      final v = held.companions.single;
      expect(v.apAusgegeben, 400);
      expect(v.ge, 10, reason: 'Grundwerte bleiben');
      expect(begleiterWirksamerWert(v, 'ge'), 12);
      expect(begleiterWirksamerWert(v, 'ini'), 10);
      expect(begleiterWirksamerPoolwert(v, 'lep'), 29);
      final angriff = v.angriffe.single;
      expect(begleiterWirksamerAngriffAt(v, angriff), 13);
      expect(begleiterWirksamerAngriffPa(v, angriff), 7);
      expect(begleiterWirksameGeschwindigkeiten(v).single.wert, 11);
      final profil = begleiterKampfprofil(v);
      expect(profil.ini, 10);
      expect(profil.angriffe.single.pa, 7);
    });

    test('Trick mit Bezeichnung; geänderte Anzahl wird abgewiesen', () {
      final held = bucheVertrautenAusbildung(
        _hexe(_vertrauter()),
        begleiterId: 'v',
        katalogId: 'vfert_trick',
        apKosten: 45,
        erwarteteAnzahl: 0,
        bezeichnung: ' Rolle ',
      );
      final buchung = held.companions.single.vertrautenBindung!.ausbildungen;
      expect(buchung.single.bezeichnung, 'Rolle');
      expect(
        () => bucheVertrautenAusbildung(
          held,
          begleiterId: 'v',
          katalogId: 'vfert_komm',
          apKosten: 10,
          erwarteteAnzahl: 0,
        ),
        throwsStateError,
      );
    });

    test('gesperrt nur mit Meisterentscheid', () {
      expect(
        () => bucheVertrautenAusbildung(
          _hexe(_vertrauter()),
          begleiterId: 'v',
          katalogId: 'vfert_ablegen',
          apKosten: 25,
          erwarteteAnzahl: 0,
        ),
        throwsStateError,
      );
      final held = bucheVertrautenAusbildung(
        _hexe(_vertrauter()),
        begleiterId: 'v',
        katalogId: 'vfert_ablegen',
        apKosten: 25,
        erwarteteAnzahl: 0,
        meisterentscheid: true,
      );
      expect(
        held.companions.single.vertrautenBindung!.ausbildungen,
        hasLength(1),
      );
    });
  });
}
