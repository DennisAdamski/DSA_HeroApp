/// Katalog der Vertrautentiere (WdZ S. 123–128, ZBA S. 19–21).
///
/// Die Konstanten sind die Quelle; `assets/catalogs/house_rules_v1/
/// vertrauten.json` ist ihr per Test geprüfter Spiegel (Muster wie
/// `reittier_ausbildung_katalog.dart`). Texte sind kurze Stichworte, keine
/// Buchzitate. Gespeicherte Helden verweisen nur über die stabilen IDs
/// (`vart_…`, `vausb_…`, `vfert_…`) auf diesen Katalog; Vertrautenzauber
/// liegen weiterhin namentlich im Ritual-Preset, [kVertrautenZauber] ergänzt
/// nur Lernkosten und Zugang.
library;

import 'package:dsa_heldenverwaltung/catalog/vertrauten_typen.dart';

export 'package:dsa_heldenverwaltung/catalog/vertrauten_typen.dart';

/// Bindungskosten eines Machtvollen Vertrauten (WdZ S. 123).
const int kVertrautenBindungskostenMachtvoll = 120;

/// Höchstzahl frei verteilbarer Generierungspunkte (WdZ S. 123).
const int kVertrautenGenerierungspunkte = 20;

/// AP je Generierungspunkt (WdZ S. 123).
const int kVertrautenApJeGenerierungspunkt = 2;

/// Höchstzahl zusätzlicher AsP, LeP und AuP je Wert (WdZ S. 123).
const int kVertrautenZusatzpunkteMax = 3;

/// AP je zusätzlichem AsP oder LeP (WdZ S. 123).
const int kVertrautenApJeZusatzAspLep = 5;

/// AP je zusätzlichem AuP (WdZ S. 123).
const int kVertrautenApJeZusatzAup = 2;

/// AP je Punkt über dem Tabellenmaximum beim Machtvollen Vertrauten
/// (WdZ S. 124).
const int kVertrautenApJePunktUeberMaximum = 5;

/// Loyalität nach der ersten Bindung (WdZ S. 124).
const int kVertrautenStartLoyalitaet = 15;

/// Höchste Loyalität eines Vertrauten (WdZ S. 124).
const int kVertrautenMaxLoyalitaet = 25;

/// Übertragene AP je Loyalitätspunkt (WdZ S. 124).
const int kVertrautenApJeLoyalitaet = 50;

/// Startwert der Ritualkenntnis Vertrautenmagie (WdZ S. 123).
const int kVertrautenStartRk = 3;

/// Anteil der Abenteuer-AP der Hexe, den der Vertraute erhält: ein Viertel
/// (WdZ S. 125, ohne Abzug bei der Hexe).
const int kVertrautenApAnteilNenner = 4;

/// Reihenfolge der Eigenschaften in der Startwerttabelle.
const List<String> kVertrautenEigenschaftKeys = <String>[
  'mu',
  'kl',
  'inn',
  'ch',
  'ff',
  'ge',
  'ko',
  'kk',
];

// Baut die Eigenschaftsspannen in Tabellenreihenfolge MU … KK.
Map<String, VertrautenWertspanne> _werte(List<(int, int)> spannen) =>
    <String, VertrautenWertspanne>{
      for (var i = 0; i < kVertrautenEigenschaftKeys.length; i++)
        kVertrautenEigenschaftKeys[i]: VertrautenWertspanne(
          spannen[i].$1,
          spannen[i].$2,
        ),
    };

// Ausbildungen, die die ZBA-Tabelle (S. 19) für Hunde nennt („nach Rasse“).
const List<String> _hundeAusbildungen = <String>[
  'vausb_huetetier',
  'vausb_jagdtier',
  'vausb_suchtier',
  'vausb_tragetier',
  'vausb_wachtier',
  'vausb_zirkustier',
  'vausb_zugtier',
];

/// Die üblichen Vertrautenarten (WdZ S. 124, Werte der Tabelle).
///
/// Flieger tragen je einen Boden- und einen Luftangriff; alle Vertrauten
/// kämpfen in DK H.
final List<VertrautenArtDef> kVertrautenArten =
    List<VertrautenArtDef>.unmodifiable(<VertrautenArtDef>[
      VertrautenArtDef(
        id: 'vart_katze',
        name: 'Katze',
        bindungskosten: 80,
        eigenschaften: _werte(const [
          (7, 9),
          (4, 6),
          (5, 10),
          (7, 12),
          (2, 5),
          (11, 16),
          (5, 10),
          (2, 4),
        ]),
        iniBasis: 13,
        iniWuerfel: '1W6',
        lep: 11,
        asp: 5,
        aup: 45,
        rs: 1,
        mr: 4,
        angriffe: const [
          VertrautenAngriffDef(name: 'Prankenhieb', at: 11, pa: 11, tp: '1W6'),
        ],
        geschwindigkeiten: const [VertrautenTempoDef('Boden', 10)],
        kampfregeln: const [
          'Hinterhalt (12)',
          'Anspringen (−8)',
          'Verbeißen',
          'sehr kleiner Gegner (AT +2 / PA +4)',
          'Gezielter Angriff',
          'Doppelangriff (Prankenhieb und Biss)',
        ],
        tiersinne: 'Nachtsicht, Gehör',
        ausbildungIds: const ['vausb_zirkustier'],
      ),
      VertrautenArtDef(
        id: 'vart_wildkatze',
        name: 'Wildkatze',
        bindungskosten: 80,
        eigenschaften: _werte(const [
          (8, 10),
          (2, 4),
          (5, 10),
          (7, 12),
          (2, 5),
          (12, 17),
          (7, 12),
          (3, 9),
        ]),
        iniBasis: 13,
        iniWuerfel: '1W6',
        lep: 10,
        asp: 4,
        aup: 25,
        rs: 1,
        mr: 3,
        angriffe: const [
          VertrautenAngriffDef(
            name: 'Prankenhieb',
            at: 12,
            pa: 11,
            tp: '1W6+1',
          ),
        ],
        geschwindigkeiten: const [VertrautenTempoDef('Boden', 10)],
        kampfregeln: const [
          'Hinterhalt (12)',
          'Anspringen (−8)',
          'Verbeißen',
          'sehr kleiner Gegner (AT +2 / PA +4)',
          'Gezielter Angriff',
          'Doppelangriff (Prankenhieb und Biss)',
        ],
        tiersinne: 'Nachtsicht, Gehör',
        ausbildungIds: const ['vausb_zirkustier'],
      ),
      VertrautenArtDef(
        id: 'vart_hund',
        name: 'Hund',
        bindungskosten: 80,
        eigenschaften: _werte(const [
          (7, 14),
          (3, 8),
          (3, 8),
          (5, 10),
          (2, 5),
          (7, 13),
          (8, 14),
          (8, 14),
        ]),
        iniBasis: 8,
        iniWuerfel: '1W6',
        lep: 24,
        asp: 4,
        aup: 65,
        rs: 2,
        mr: 1,
        angriffe: const [
          VertrautenAngriffDef(name: 'Biss', at: 11, pa: 6, tp: '1W6+3'),
        ],
        geschwindigkeiten: const [VertrautenTempoDef('Boden', 10)],
        kampfregeln: const [
          'Gezielter Angriff',
          'Verbeißen',
          'Niederwerfen (−3)',
        ],
        tiersinne: 'Geruch, Gehör',
        ausbildungIds: _hundeAusbildungen,
      ),
      VertrautenArtDef(
        id: 'vart_eule',
        name: 'Eule',
        bindungskosten: 80,
        eigenschaften: _werte(const [
          (5, 14),
          (4, 9),
          (4, 9),
          (6, 10),
          (4, 10),
          (4, 8),
          (7, 10),
          (2, 4),
        ]),
        iniBasis: 9,
        iniWuerfel: '1W6',
        lep: 8,
        asp: 7,
        aup: 35,
        rs: 2,
        mr: 4,
        angriffe: const [
          VertrautenAngriffDef(
            name: 'Krallen (Boden)',
            at: 1,
            pa: 2,
            tp: '1W6',
          ),
          VertrautenAngriffDef(name: 'Krallen (Luft)', at: 12, pa: 5, tp: '1W6'),
        ],
        geschwindigkeiten: const [
          VertrautenTempoDef('Boden', 1),
          VertrautenTempoDef('Fliegen', 12),
        ],
        kampfregeln: const [
          'Flugangriff',
          'sehr kleiner Gegner (AT +2 / PA +4)',
        ],
        tiersinne: 'Hervorragende Nachtsicht',
        ausbildungIds: const ['vausb_jagdtier'],
        hinweis:
            'Bei Tag alle Werte außer LE, AE und RS halbiert (Schnee-Eule '
            'ausgenommen).',
      ),
      VertrautenArtDef(
        id: 'vart_rabe',
        name: 'Rabe',
        bindungskosten: 80,
        eigenschaften: _werte(const [
          (6, 11),
          (4, 9),
          (3, 8),
          (4, 10),
          (3, 8),
          (5, 9),
          (7, 10),
          (2, 4),
        ]),
        iniBasis: 8,
        iniWuerfel: '1W6',
        lep: 8,
        asp: 6,
        aup: 40,
        rs: 1,
        mr: 2,
        angriffe: const [
          VertrautenAngriffDef(
            name: 'Schnabel (Boden)',
            at: 2,
            pa: 1,
            tp: '1W6+1',
          ),
          VertrautenAngriffDef(
            name: 'Schnabel (Luft)',
            at: 11,
            pa: 7,
            tp: '1W6+1',
          ),
        ],
        geschwindigkeiten: const [
          VertrautenTempoDef('Boden', 1),
          VertrautenTempoDef('Fliegen', 13),
        ],
        kampfregeln: const [
          'Flugangriff',
          'sehr kleiner Gegner (AT +2 / PA +4)',
        ],
        tiersinne: 'Scharfblick bei Tag',
        hinweis:
            'Nach Einbruch der Dunkelheit alle Werte außer LE, AE und RS '
            'halbiert. Elster und Eichelhäher: KO −1, TP −1.',
      ),
      VertrautenArtDef(
        id: 'vart_falke',
        name: 'Falke',
        bindungskosten: 80,
        eigenschaften: _werte(const [
          (6, 16),
          (2, 5),
          (3, 7),
          (4, 8),
          (3, 7),
          (6, 12),
          (5, 10),
          (2, 4),
        ]),
        iniBasis: 12,
        iniWuerfel: '1W6',
        lep: 12,
        asp: 4,
        aup: 90,
        rs: 1,
        mr: 2,
        angriffe: const [
          VertrautenAngriffDef(
            name: 'Krallen (Boden)',
            at: 5,
            pa: 4,
            tp: '1W6+1',
          ),
          VertrautenAngriffDef(
            name: 'Krallen (Luft)',
            at: 15,
            pa: 7,
            tp: '1W6+1',
          ),
        ],
        geschwindigkeiten: const [
          VertrautenTempoDef('Boden', 1),
          VertrautenTempoDef('Fliegen', 30),
        ],
        kampfregeln: const [
          'Flugangriff',
          'sehr kleiner Gegner (AT +2 / PA +4)',
          'Sturzflug',
          'Gezielter Angriff',
          'Verkrallen',
        ],
        tiersinne: 'Hervorragender Scharfblick bei Tag',
        ausbildungIds: const ['vausb_jagdtier'],
        hinweis:
            'Nur bei Dienern Sumus. Bei Nacht alle Werte außer LE, AE und RS '
            'halbiert.',
      ),
      VertrautenArtDef(
        id: 'vart_schlange',
        name: 'Schlange',
        bindungskosten: 80,
        eigenschaften: _werte(const [
          (3, 8),
          (2, 6),
          (3, 7),
          (4, 9),
          (1, 2),
          (9, 15),
          (6, 10),
          (2, 5),
        ]),
        iniBasis: 7,
        iniWuerfel: '2W6',
        lep: 7,
        asp: 8,
        aup: 15,
        rs: 0,
        mr: 6,
        angriffe: const [
          VertrautenAngriffDef(name: 'Biss', at: 12, pa: 3, tp: '1W6+1'),
        ],
        geschwindigkeiten: const [VertrautenTempoDef('Boden', 2)],
        kampfregeln: const [
          'Gezielter Angriff (SP statt TP)',
          'sehr kleiner Gegner (AT +3 / PA +5)',
        ],
        tiersinne: 'Geruch, Magiegespür',
      ),
      VertrautenArtDef(
        id: 'vart_kroete',
        name: 'Kröte',
        bindungskosten: 100,
        eigenschaften: _werte(const [
          (5, 10),
          (4, 9),
          (3, 8),
          (4, 10),
          (1, 2),
          (2, 3),
          (7, 10),
          (1, 2),
        ]),
        iniBasis: 1,
        iniWuerfel: '1W6',
        lep: 4,
        asp: 15,
        aup: 15,
        rs: 0,
        mr: 6,
        angriffe: const [],
        geschwindigkeiten: const [VertrautenTempoDef('Boden', 0)],
        kampfregeln: const ['winziger Gegner (AT +6)'],
        tiersinne: 'Hervorragendes Magiegespür',
        hinweis:
            'GS laut Tabelle 0,3; die App führt nur ganze Geschwindigkeiten. '
            'Hautgift: 1 SP je KR direkter Berührung.',
      ),
      VertrautenArtDef(
        id: 'vart_affe',
        name: 'Affe',
        bindungskosten: 80,
        eigenschaften: _werte(const [
          (4, 10),
          (3, 8),
          (5, 8),
          (6, 9),
          (10, 17),
          (12, 16),
          (7, 11),
          (3, 6),
        ]),
        iniBasis: 9,
        iniWuerfel: '2W6',
        lep: 10,
        asp: 4,
        aup: 15,
        rs: 1,
        mr: 1,
        angriffe: const [
          VertrautenAngriffDef(name: 'Biss', at: 8, pa: 11, tp: '1W3'),
        ],
        geschwindigkeiten: const [VertrautenTempoDef('Boden', 8)],
        kampfregeln: const [
          'Gezielter Biss (SP statt TP)',
          'Gelände (Baum / Wald)',
          'sehr kleiner Gegner (AT +4 / PA +8)',
        ],
        tiersinne: 'Sinnenschärfe +3',
        ausbildungIds: const [
          'vausb_wachtier',
          'vausb_tragetier',
          'vausb_zirkustier',
        ],
      ),
      VertrautenArtDef(
        id: 'vart_spinne',
        name: 'Spinne',
        bindungskosten: 100,
        eigenschaften: _werte(const [
          (7, 14),
          (2, 6),
          (2, 7),
          (5, 6),
          (5, 10),
          (8, 14),
          (10, 14),
          (1, 2),
        ]),
        iniBasis: 4,
        iniWuerfel: '2W6',
        lep: 6,
        asp: 7,
        aup: 25,
        rs: 0,
        mr: 8,
        angriffe: const [
          VertrautenAngriffDef(name: 'Biss', at: 12, pa: 3, tp: '1W3+1'),
        ],
        geschwindigkeiten: const [VertrautenTempoDef('Boden', 2)],
        kampfregeln: const [
          'Gezielter Angriff (SP statt TP)',
          'winziger Gegner (AT +5)',
          'Gift (Stufe 1, 1W6 SP, sofort)',
        ],
        tiersinne: 'Hervorragender Tastsinn',
      ),
      VertrautenArtDef(
        id: 'vart_iltis',
        name: 'Iltis',
        bindungskosten: 80,
        eigenschaften: _werte(const [
          (8, 10),
          (2, 5),
          (4, 9),
          (3, 8),
          (3, 8),
          (9, 13),
          (6, 10),
          (3, 7),
        ]),
        iniBasis: 10,
        iniWuerfel: '1W6',
        lep: 6,
        asp: 4,
        aup: 40,
        rs: 2,
        mr: 0,
        angriffe: const [
          VertrautenAngriffDef(name: 'Biss', at: 11, pa: 8, tp: '1W3'),
        ],
        geschwindigkeiten: const [VertrautenTempoDef('Boden', 8)],
        kampfregeln: const [
          'Gezielter Angriff',
          'Verbeißen (SP statt TP)',
          'sehr kleiner Gegner (AT +2 / PA +5)',
        ],
        tiersinne: 'Geruch, Gehör',
      ),
      VertrautenArtDef(
        id: 'vart_wiesel',
        name: 'Wiesel',
        bindungskosten: 80,
        eigenschaften: _werte(const [
          (8, 14),
          (2, 4),
          (4, 8),
          (4, 10),
          (3, 7),
          (10, 15),
          (4, 9),
          (2, 4),
        ]),
        iniBasis: 13,
        iniWuerfel: '1W6',
        lep: 6,
        asp: 4,
        aup: 20,
        rs: 1,
        mr: 0,
        angriffe: const [
          VertrautenAngriffDef(name: 'Biss', at: 10, pa: 10, tp: '1W3'),
        ],
        geschwindigkeiten: const [VertrautenTempoDef('Boden', 12)],
        kampfregeln: const [
          'Gezielter Angriff (SP statt TP)',
          'sehr kleiner Gegner (AT +3 / PA +6)',
        ],
        tiersinne: 'Geruch, Gehör',
      ),
    ]);

/// Lern- und Zugangsdaten der Vertrautenzauber (WdZ S. 126–128).
const List<VertrautenZauberDef> kVertrautenZauber = <VertrautenZauberDef>[
  VertrautenZauberDef(
    id: 'vzaub_dinge_aufspueren',
    name: 'Dinge aufspüren',
    lernkosten: 10,
  ),
  VertrautenZauberDef(
    id: 'vzaub_erster_unter_gleichen',
    name: 'Erster unter Gleichen',
    lernkosten: 20,
    halbFuerMachtvoll: true,
  ),
  VertrautenZauberDef(
    id: 'vzaub_hexe_finden',
    name: 'Hexe finden',
    lernkosten: 15,
  ),
  VertrautenZauberDef(
    id: 'vzaub_kroetengift',
    name: 'Krötengift',
    lernkosten: 20,
    tierartIds: <String>['vart_kroete'],
  ),
  VertrautenZauberDef(
    id: 'vzaub_kroetenschlag',
    name: 'Krötenschlag',
    lernkosten: 0,
    tierartIds: <String>['vart_kroete'],
    mitBindung: true,
  ),
  VertrautenZauberDef(
    id: 'vzaub_schlaf_rauben',
    name: 'Schlaf rauben',
    lernkosten: 20,
  ),
  VertrautenZauberDef(
    id: 'vzaub_stimmungssinn',
    name: 'Stimmungssinn',
    lernkosten: 15,
  ),
  VertrautenZauberDef(
    id: 'vzaub_tarnung',
    name: 'Tarnung',
    lernkosten: 15,
    tierartIds: <String>['vart_kroete', 'vart_schlange', 'vart_spinne'],
  ),
  VertrautenZauberDef(
    id: 'vzaub_tiersinne',
    name: 'Tiersinne',
    lernkosten: 15,
  ),
  VertrautenZauberDef(
    id: 'vzaub_ungesehener_beobachter',
    name: 'Ungesehener Beobachter',
    lernkosten: 20,
  ),
  VertrautenZauberDef(
    id: 'vzaub_wachsame_augen',
    name: 'Wachsame Augen',
    lernkosten: 15,
    nurMachtvoll: true,
  ),
  VertrautenZauberDef(
    id: 'vzaub_zwiegespraech',
    name: 'Zwiegespräch',
    lernkosten: 0,
    mitBindung: true,
  ),
];

/// Ausbildungsstufen für Tiere außer Pferden (ZBA S. 21).
const List<VertrautenAusbildungDef> kVertrautenAusbildungen =
    <VertrautenAusbildungDef>[
      VertrautenAusbildungDef(
        id: 'vausb_huetetier',
        name: 'Hütetier',
        tapStern: 50,
        erschwernis: 4,
        modifikationen: VertrautenModifikationen(mu: 1, inn: 2, ge: 1),
        hinweis: 'Ablegen, Komm, Laut, Sitz, Treiben',
      ),
      VertrautenAusbildungDef(
        id: 'vausb_jagdtier',
        name: 'Jagdtier',
        tapStern: 40,
        erschwernis: 4,
        modifikationen: VertrautenModifikationen(
          ge: 2,
          ko: 1,
          at: 2,
          pa: 1,
          ini: 2,
          gs: 1,
          lep: 5,
          aup: 10,
        ),
        hinweis: 'Fährtensuchen +5; Apport, Fass I, Laut, Still, Such',
      ),
      VertrautenAusbildungDef(
        id: 'vausb_kampftier',
        name: 'Kampftier',
        tapStern: 50,
        erschwernis: 6,
        modifikationen: VertrautenModifikationen(
          mu: 1,
          kk: 1,
          ko: 2,
          at: 3,
          pa: 2,
          tp: 1,
          ini: 1,
          lep: 7,
          aup: 10,
        ),
        hinweis: 'Fass I und II',
        fuerVertraute: false,
      ),
      VertrautenAusbildungDef(
        id: 'vausb_reittier',
        name: 'Reittier',
        tapStern: 45,
        erschwernis: 4,
        modifikationen: VertrautenModifikationen(
          ge: 1,
          ko: 2,
          kk: 2,
          gs: 1,
          lep: 2,
          aup: 10,
        ),
        hinweis: 'Mit angepasstem Sattel reitbar; Tragkraft 5 × KK Stein',
      ),
      VertrautenAusbildungDef(
        id: 'vausb_renntier',
        name: 'Renntier',
        tapStern: 40,
        erschwernis: 5,
        modifikationen: VertrautenModifikationen(
          ko: 2,
          gs: 2,
          ini: 2,
          lep: 3,
          aup: 15,
        ),
      ),
      VertrautenAusbildungDef(
        id: 'vausb_suchtier',
        name: 'Suchtier',
        tapStern: 35,
        erschwernis: 4,
        modifikationen: VertrautenModifikationen(inn: 1, ge: 1),
        hinweis: 'Fährtensuchen +10; Such',
      ),
      VertrautenAusbildungDef(
        id: 'vausb_tragetier',
        name: 'Tragetier',
        tapStern: 40,
        erschwernis: 3,
        modifikationen: VertrautenModifikationen(
          kk: 2,
          ko: 1,
          lep: 2,
          aup: 10,
        ),
        hinweis: 'Trägt 5 × KK Stein',
      ),
      VertrautenAusbildungDef(
        id: 'vausb_wachtier',
        name: 'Wachtier',
        tapStern: 45,
        erschwernis: 3,
        modifikationen: VertrautenModifikationen(
          mu: 2,
          inn: 1,
          ini: 1,
          at: 2,
          pa: 1,
        ),
        hinweis: 'Ablegen, Komm, Laut, Sitz, Wache',
      ),
      VertrautenAusbildungDef(
        id: 'vausb_zirkustier',
        name: 'Zirkustier',
        tapStern: 45,
        erschwernis: 5,
        modifikationen: VertrautenModifikationen(inn: 1),
        hinweis:
            'GE +2 oder FF +2 nach Wahl (nicht eingerechnet); ein Trick nach '
            'Wahl; Befehle verstehen +4, Trick-Erschwernis nur +2, bis 2 × KL '
            'Tricks',
      ),
      VertrautenAusbildungDef(
        id: 'vausb_zugtier',
        name: 'Zugtier',
        tapStern: 45,
        erschwernis: 3,
        modifikationen: VertrautenModifikationen(
          ko: 2,
          kk: 2,
          lep: 2,
          aup: 15,
        ),
        hinweis: 'Zieht 10 × KK Stein',
      ),
    ];

/// Allgemeine Tierfertigkeiten (ZBA S. 21 f.).
const List<VertrautenFertigkeitDef> kVertrautenFertigkeiten =
    <VertrautenFertigkeitDef>[
      VertrautenFertigkeitDef(
        id: 'vfert_komm',
        name: 'Komm',
        erschwernis: -1,
        hinweis: 'Kommt auf Befehl.',
      ),
      VertrautenFertigkeitDef(
        id: 'vfert_sitz',
        name: 'Sitz',
        erschwernis: 0,
        hinweis: 'Setzt sich auf Befehl.',
      ),
      VertrautenFertigkeitDef(
        id: 'vfert_platz',
        name: 'Platz',
        erschwernis: 1,
        hinweis: 'Legt sich auf Befehl hin.',
      ),
      VertrautenFertigkeitDef(
        id: 'vfert_laut',
        name: 'Laut',
        erschwernis: 1,
        hinweis: 'Schlägt auf Befehl und bei Eindringlingen an.',
      ),
      VertrautenFertigkeitDef(
        id: 'vfert_still',
        name: 'Still',
        erschwernis: 2,
        hinweis: 'Bleibt eine Zeit lang still.',
      ),
      VertrautenFertigkeitDef(
        id: 'vfert_ablegen',
        name: 'Ablegen',
        erschwernis: 3,
        voraussetzungId: 'vfert_sitz',
        hinweis: 'Wartet unbeweglich bis zum Komm-Befehl.',
      ),
      VertrautenFertigkeitDef(
        id: 'vfert_apport',
        name: 'Apport',
        erschwernis: 3,
        hinweis: 'Bringt einen tragbaren Gegenstand.',
      ),
      VertrautenFertigkeitDef(
        id: 'vfert_trick',
        name: 'Trick',
        erschwernis: 7,
        mehrfach: true,
        hinweis: 'Ein Kunststück auf Befehl; höchstens KL Tricks.',
      ),
    ];

/// Vertrautenart zu [id]; `null` für unbekannte IDs.
VertrautenArtDef? vertrautenArt(String id) {
  for (final art in kVertrautenArten) {
    if (art.id == id) return art;
  }
  return null;
}

/// Zugangsdaten des Vertrautenzaubers [name]; `null` für unbekannte Namen.
VertrautenZauberDef? vertrautenZauber(String name) {
  for (final zauber in kVertrautenZauber) {
    if (zauber.name == name) return zauber;
  }
  return null;
}

/// Ausbildungsstufe zu [id]; `null` für unbekannte IDs.
VertrautenAusbildungDef? vertrautenAusbildung(String id) {
  for (final stufe in kVertrautenAusbildungen) {
    if (stufe.id == id) return stufe;
  }
  return null;
}

/// Fertigkeit zu [id]; `null` für unbekannte IDs.
VertrautenFertigkeitDef? vertrautenFertigkeit(String id) {
  for (final fertigkeit in kVertrautenFertigkeiten) {
    if (fertigkeit.id == id) return fertigkeit;
  }
  return null;
}

/// Gesamter Katalog als JSON, wie ihn der Spiegel unter `assets/` enthält.
Map<String, dynamic> vertrautenKatalogJson() => <String, dynamic>{
  'quelle': 'Wege der Zauberei S. 123–128; Zoo-Botanica Aventurica S. 19–21',
  'arten': kVertrautenArten.map((a) => a.toJson()).toList(growable: false),
  'zauber': kVertrautenZauber.map((z) => z.toJson()).toList(growable: false),
  'ausbildungen': kVertrautenAusbildungen
      .map((a) => a.toJson())
      .toList(growable: false),
  'fertigkeiten': kVertrautenFertigkeiten
      .map((f) => f.toJson())
      .toList(growable: false),
};
