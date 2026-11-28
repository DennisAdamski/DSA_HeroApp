/// Waffen-Großmeister (Hausregel „Epische Stufen“ S. 14–20).
///
/// Rechenbare Vorteile fließen über [computeWaffenmeisterEffects] in die
/// Kampfwerte; situative Regeln bleiben Hinweise für den Spieltisch.
library;

/// Katalog-ID des Großmeisters je Kampftalent.
const Map<String, String> grossmeisterSfIdNachTalent = <String, String>{
  'tal_anderthalbhaender': 'esf_grossmeister_anderthalbhaender',
  'tal_armbrust': 'esf_grossmeister_armbrust',
  'tal_blasrohr': 'esf_grossmeister_blasrohr',
  'tal_bogen': 'esf_grossmeister_bogen',
  'tal_diskus': 'esf_grossmeister_diskus',
  'tal_dolche': 'esf_grossmeister_dolche',
  'tal_fechtwaffen': 'esf_grossmeister_fechtwaffen',
  'tal_hiebwaffen': 'esf_grossmeister_hiebwaffen',
  'tal_infanteriewaffen': 'esf_grossmeister_infanteriewaffen',
  'tal_kettenstaebe': 'esf_grossmeister_kettenstaebe',
  'tal_kettenwaffen': 'esf_grossmeister_kettenwaffen',
  'tal_lanzenreiten': 'esf_grossmeister_lanzenreiten',
  'tal_peitsche': 'esf_grossmeister_peitsche',
  'tal_raufen': 'esf_grossmeister_raufen',
  'tal_ringen': 'esf_grossmeister_ringen',
  'tal_saebel': 'esf_grossmeister_saebel',
  'tal_schleuder': 'esf_grossmeister_schleuder',
  'tal_schwerter': 'esf_grossmeister_schwerter',
  'tal_speere': 'esf_grossmeister_speere',
  'tal_staebe': 'esf_grossmeister_staebe',
  'tal_wurfbeile': 'esf_grossmeister_wurfbeile',
  'tal_wurfmesser': 'esf_grossmeister_wurfmesser',
  'tal_wurfspeere': 'esf_grossmeister_wurfspeere',
  'tal_zweihandflegel': 'esf_grossmeister_zweihandflegel',
  'tal_zweihand_hiebwaffen': 'esf_grossmeister_zweihandhiebwaffen',
  'tal_zweihandschwerter_saebel': 'esf_grossmeister_zweihandschwerter',
};

/// Wuchtartige Säbel laut Großmeister (Säbel).
const List<String> wuchtartigeSaebel = <String>[
  'arbach',
  'entermesser',
  'haumesser',
  'khunchomer',
  'sklaventod',
];

/// Manöver, die der Säbel-Pool aus dem GE/INI-Bonus erleichtert.
const List<String> saebelPoolManoever = <String>[
  'Betäubungsschlag',
  'Entwaffnen',
  'Klingensturm',
  'Klingenwand',
];

/// Anzeigename der vom Großmeister freigeschalteten Manöver.
String grossmeisterManoeverName(String id) => switch (id) {
  'man_hammerschlag' => 'Hammerschlag',
  'man_schildspalter' => 'Schildspalter',
  'man_umreissen' => 'Umreißen',
  _ => id,
};

/// Was die Kampfübersicht zu Waffenmeister und Großmeister der geführten
/// Waffe zeigt; alle Zahlen sind bereits in die Kampfwerte eingerechnet.
class MeisterschaftUebersicht {
  const MeisterschaftUebersicht({
    this.waffenmeisterName = '',
    this.waffenmeisterWirkungen = const <String>[],
    this.grossmeisterName = '',
    this.grossmeisterWirkungen = const <String>[],
    this.hinweise = const <String>[],
    this.poolPunkte,
    this.geStattKkMoeglich = false,
    this.geStattKkAktiv = false,
    this.tpKkMitKk = 0,
    this.tpKkMitGe = 0,
  });

  final String waffenmeisterName;
  final List<String> waffenmeisterWirkungen;
  final String grossmeisterName;

  /// Eingerechnete Großmeister-Wirkungen mit den aktuellen Werten.
  final List<String> grossmeisterWirkungen;

  /// Situative Regeln ohne automatische Wirkung.
  final List<String> hinweise;

  /// Säbel: verteilbare Punkte je KR aus dem GE/INI-Bonus; `null` ohne Pool.
  final int? poolPunkte;

  /// Säbel: Schalter „Bonusschaden aus GE statt KK“ verfügbar.
  final bool geStattKkMoeglich;

  /// Der Schalter ist an und wirkt auf die TP.
  final bool geStattKkAktiv;

  /// TP/KK-Zuschlag mit KK bzw. mit GE (für den Vergleich am Schalter).
  final int tpKkMitKk;
  final int tpKkMitGe;

  static const keine = MeisterschaftUebersicht();

  bool get sichtbar =>
      waffenmeisterName.isNotEmpty || grossmeisterName.isNotEmpty;
}

/// Effekte eines aktiven Waffen-Großmeisters für die geführte Waffe.
class GrossmeisterEffekte {
  const GrossmeisterEffekte({
    this.name = '',
    this.tpKkBasis = 0,
    this.tpKkSchwelle = 0,
    this.tpKkFestBasis,
    this.tpKkFestSchwelle,
    this.geIniSchwelle = 0,
    this.ladezeit = 0,
    this.at = 0,
    this.pa = 0,
    this.zusatzaktionen = 0,
    this.manoever = const <String>[],
    this.manoeverPool = false,
    this.geStattKk = false,
    this.hinweise = const <String>[],
  });

  /// Anzeigename; leer, wenn kein Großmeister greift.
  final String name;

  /// Verschiebung von TP/KK-Basis und -Schwelle.
  final int tpKkBasis;
  final int tpKkSchwelle;

  /// Fester TP/KK-Schlüssel, der den Waffenwert ersetzt.
  final int? tpKkFestBasis;
  final int? tpKkFestSchwelle;

  /// Verschiebung der GE/INI-Schwelle (Säbel: 0/-1).
  final int geIniSchwelle;

  /// Änderung der Ladezeit in Aktionen.
  final int ladezeit;

  /// AT-/PA-Bonus.
  final int at;
  final int pa;

  /// Zusätzliche Aktionen pro KR.
  final int zusatzaktionen;

  /// Freigeschaltete Manöver (Katalog-IDs).
  final List<String> manoever;

  /// Säbel: GE/INI-Bonus als Erleichterungspool je KR.
  final bool manoeverPool;

  /// Säbel: Bonusschaden darf aus GE statt KK kommen.
  final bool geStattKk;

  /// Situative Regeln ohne automatische Wirkung.
  final List<String> hinweise;

  static const none = GrossmeisterEffekte();

  bool get isActive => name.isNotEmpty;
}

/// Ermittelt die Großmeister-Effekte für die geführte Waffe.
///
/// Großmeister wirken für alle Waffen ihrer Gattung (Epische Stufen S. 14).
GrossmeisterEffekte computeGrossmeisterEffekte({
  required Iterable<String> aktiveKampfSfIds,
  required String talentId,
  required String waffenTyp,
}) {
  final sfId = grossmeisterSfIdNachTalent[talentId.trim()];
  final aktiv = aktiveKampfSfIds.toSet();
  if (sfId == null || !aktiv.contains(sfId)) {
    return GrossmeisterEffekte.none;
  }
  final waffe = waffenTyp.trim().toLowerCase();
  bool stil(String id) => aktiv.contains(id);

  switch (talentId.trim()) {
    case 'tal_anderthalbhaender':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Anderthalbhänder)',
        zusatzaktionen: 1,
        hinweise: <String>[
          'Bis zu 3 KR einhändig ohne Abzüge; jede Aktion der freien Hand '
              'kostet die Zusatzaktion.',
        ],
      );
    case 'tal_armbrust':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Armbrust)',
        hinweise: <String>[
          'Zielen baut FK-Erschwernisse ab: 1 Aktion je 2 Punkte '
              '(bewegtes Ziel 1:1); nicht für Ansage und Wunden.',
          'Schadensansage: +3 TP je 2 Punkte Erschwernis.',
        ],
      );
    case 'tal_blasrohr':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Blasrohr)',
        hinweise: <String>[
          'Atem- und Kontaktgifte relativ gefahrlos verschießbar.',
          'Glückliche Attacken ignorieren RS.',
          'Treffer bleibt unbemerkt ohne Sinnesschärfe-Probe '
              '+ Blasrohr-TaW/3.',
        ],
      );
    case 'tal_bogen':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Bogen)',
        ladezeit: -1,
        hinweise: <String>[
          'Ansagen mit dem Kurzbogen kosten keine zusätzliche Aktion.',
          'Projektilgrößen und -spitzen erschweren nicht mehr.',
          'Erschwernisse für mehrere Schüsse pro KR halbiert.',
        ],
      );
    case 'tal_diskus':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Diskus)',
        hinweise: <String>[
          'Mit Spezialhandschuh zwei Diskusse zugleich (je mit Ansage); '
              'Ladezeit +1 Aktion.',
          'Ignoriert 2 weitere Punkte Deckungsaufschlag.',
          'Parade oder Ausweichen gegen den Diskus +4 erschwert.',
        ],
      );
    case 'tal_dolche':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Dolche)',
        hinweise: <String>[
          'Mit zwei Dolchen: zusätzliche Aktion mit der falschen Hand.',
          'Beidhändige Parade hält jede Nahkampfwaffe auf.',
          'Einhändig: Angriff von hinten gilt als Meucheln.',
        ],
      );
    case 'tal_fechtwaffen':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Fechtwaffen)',
        zusatzaktionen: 1,
        hinweise: <String>[
          'Je KR eine DK-Stufe wechseln für 2 freie Aktionen, ohne Probe.',
          'Ohne DK-Wechsel: Gegner-AT +3 (nicht umzingelt, < 4 Gegner).',
        ],
      );
    case 'tal_hiebwaffen':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Hiebwaffen)',
        hinweise: <String>[
          'Treffer auf einen Schild: dessen BF +1.',
          'Schläge gelten für die Parade als zweihändig.',
          'Äxte: Blutung je Wunde; Hämmer: Wunde senkt AT/PA um 1 mehr.',
        ],
      );
    case 'tal_infanteriewaffen':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Infanteriewaffen)',
        hinweise: <String>[
          'Gegenhalten: Ansagen (außer Finte) zählen im Vergleich nur halb.',
        ],
      );
    case 'tal_kettenstaebe':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Kettenstäbe)',
        hinweise: <String>[
          'Würgegriff in DK H (AT+6): KK gegen KO, Sieg = 3 Wunden Kopf.',
        ],
      );
    case 'tal_kettenwaffen':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Kettenwaffen)',
        hinweise: _kettenwaffenHinweise,
      );
    case 'tal_lanzenreiten':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Lanzenreiten)',
        hinweise: <String>[
          'Kein Bruchtest gegen Ziele bis Größe mittel.',
          'Eine zusätzliche Wunde, sobald die Wundschwelle überschritten ist.',
          'Getroffene reiten nur auf halben Reiten-TaW.',
        ],
      );
    case 'tal_peitsche':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Peitsche)',
        hinweise: <String>[
          'Gezielter Schlag AT+4: Arm für SP−KO KR gelähmt.',
          'Gezielter Angriff AT+8: Würgen am Hals (wie Garotte).',
        ],
      );
    case 'tal_raufen':
      return GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Raufen)',
        zusatzaktionen: stil('ksf_hammerfaust') ? 1 : 0,
        hinweise: <String>[
          if (stil('ksf_gladiatorenstil'))
            'Gladiatorenstil: echte TP dürfen zu TP(A) werden.',
          if (stil('ksf_hammerfaust'))
            'Hammerfaust: Zusatzaktion nur beim Kampf mit bloßen Händen.',
          if (stil('ksf_hruruzat')) 'Hruruzat: Tritte richten echte TP an.',
          if (stil('ksf_mercenario'))
            'Mercenario: Paraden in höheren DK ohne TP-Verlust.',
        ],
      );
    case 'tal_ringen':
      final bornlaendisch = stil('ksf_bornlaendisch');
      return GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Ringen)',
        at: bornlaendisch ? 1 : 0,
        pa: bornlaendisch ? 1 : 0,
        hinweise: <String>[
          'Unbewaffnet keine DK-Erschwernis beim Ausweichen.',
          if (stil('ksf_gladiatorenstil'))
            'Gladiatorenstil: echte TP dürfen zu TP(A) werden.',
          if (stil('ksf_unauer_schule'))
            'Unauer Schule: gelungenes Entwinden erlaubt einen Gegenangriff.',
        ],
      );
    case 'tal_saebel':
      if (wuchtartigeSaebel.any(waffe.contains)) {
        return const GrossmeisterEffekte(
          name: 'Waffen-Großmeister (Säbel)',
          tpKkBasis: 1,
          tpKkSchwelle: -1,
          manoever: <String>['man_hammerschlag', 'man_schildspalter'],
        );
      }
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Säbel)',
        geIniSchwelle: -1,
        manoeverPool: true,
        geStattKk: true,
        hinweise: <String>[
          'Ausfall: Gegner-PA +1 je bereits andauernder Ausfall-Aktion.',
        ],
      );
    case 'tal_schleuder':
      final schleuder =
          waffe.contains('schleuder') &&
          !waffe.contains('netz') &&
          !waffe.contains('lasso') &&
          !waffe.contains('haken');
      final zweihaendig = waffe.contains('stab');
      return GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Schleuder)',
        tpKkFestBasis: schleuder ? (zweihaendig ? 11 : 12) : null,
        tpKkFestSchwelle: schleuder ? (zweihaendig ? 2 : 3) : null,
        hinweise: const <String>[
          'Entfesseln aus Wurfnetzen u. Ä. 50 % stärker erschwert.',
        ],
      );
    case 'tal_schwerter':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Schwerter)',
        hinweise: <String>[
          'Anderthalbhänder einhändig ohne Abzüge.',
          'Manöver je 1 erleichtert, sobald ein Manöver final 4+ erschwert '
              'ist (nicht bei WM-Erleichterung über 2).',
        ],
      );
    case 'tal_speere':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Speere)',
        hinweise: <String>[
          'Attacken auch in den angrenzenden DK (kürzer AT+2; länger '
              'zweihändig −2 TP, Gegner kann mit Ringen-AT+4 packen).',
          'Nach einer Wunde Speer stecken lassen: Gegner kontrollieren, '
              'halbe TP je KR als SP.',
        ],
      );
    case 'tal_staebe':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Stäbe)',
        zusatzaktionen: 1,
        hinweise: <String>[
          'Statt dritter Aktion: Ausfall +1 TP je Folgetreffer, dritte '
              'Aktion wird AT −2.',
          'Reaktive Klingenwand ohne Erwerb; mit Erwerb Passierschlag gegen '
              'alle parierten Angreifer.',
        ],
      );
    case 'tal_wurfbeile':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Wurfbeile)',
        tpKkFestBasis: 13,
        tpKkFestSchwelle: 2,
        hinweise: <String>[
          'Keine Mindestreichweite; Reichweite +20 %.',
          'Wundschwelle des Getroffenen −2.',
          'Jedes Wurfbeil wirft wie ein Schneidzahn mit WM (Abwehr +2); '
              'Schneidzahn ohne Erschwernis, Abwehr +2 weitere.',
        ],
      );
    case 'tal_wurfmesser':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Wurfmesser)',
        hinweise: <String>[
          'Normaler Wurf: freie Aktion; mit Ansage: eine Aktion.',
          'Eisenhagel: halbe Zuschläge, Abwehr +1 je Geschoss.',
          'Halbe Entfernungsabzüge; keine Abzüge für mehrere Würfe.',
        ],
      );
    case 'tal_wurfspeere':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Wurfspeere)',
        tpKkFestBasis: 12,
        tpKkFestSchwelle: 2,
        hinweise: <String>[
          'Mit Anlauf: TP/KK 14/1 und eine zusätzliche Wunde.',
          'Schildabwehr: BF-Test + TP/5, sonst halbe TP durch den Schild.',
        ],
      );
    case 'tal_zweihandflegel':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Zweihandflegel)',
        manoever: <String>['man_umreissen'],
        hinweise: _kettenwaffenHinweise,
      );
    case 'tal_zweihand_hiebwaffen':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Zweihandhiebwaffen)',
        hinweise: <String>[
          'Gegner-PA − (eigene KK − Gegner-KK), wenn der Gegner schwächer ist.',
          'Erfolgreiche Paraden ziehen für den Verteidiger einen Bruchtest '
              'nach sich.',
          'Äxte: Blutung je Wunde; Hämmer: Wunde senkt AT/PA um 1 mehr.',
        ],
      );
    case 'tal_zweihandschwerter_saebel':
      return const GrossmeisterEffekte(
        name: 'Waffen-Großmeister (Zweihandschwerter)',
        tpKkBasis: 1,
        tpKkSchwelle: -1,
        hinweise: <String>[
          'TP/KK-Verschiebung nicht im Halbschwert-Kampfstil; dort keine '
              'Strafen für Enge und kein AT/PA-Malus.',
        ],
      );
  }
  return GrossmeisterEffekte.none;
}

const List<String> _kettenwaffenHinweise = <String>[
  'Schläge sind nicht parierbar, nur Ausweichen.',
  'Gewürfelte 19 ist kein Patzer, nur misslungen.',
  'Über 20 TP: steife Rüstung BE +3, RS −1; KO-Probe +1 je 5 SP gegen '
      'Ohnmacht.',
];
