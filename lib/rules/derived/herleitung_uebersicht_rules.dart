/// Alle erklärbaren Werte eines Helden als durchsuchbare Liste (ARCH-04).
///
/// Sammelt die Herleitungen der Regelmodule — Eigenschaften, Basiswerte und
/// Kampfvorschau — in eine flache Liste und filtert sie nach einer Suche.
/// Die Herleitungen selbst bleiben unverändert; hier wird nichts gerechnet.
library;

import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/rules/derived/basiswert_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/eigenschaft_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';

/// Bereich eines erklärbaren Werts, in Anzeigereihenfolge.
enum HerleitungsBereich {
  /// Effektive Eigenschaften.
  eigenschaften('Eigenschaften'),

  /// Basiswerte wie LeP, MR oder AT-Basis.
  basiswerte('Basiswerte'),

  /// Kampfvorschau der Haupthand samt Rüstung.
  kampf('Kampf'),

  /// Kampfvorschau einer Nebenhandwaffe.
  nebenhand('Nebenhand'),

  /// Wirksame Werte der Begleiter (Reittiere, Vertraute, Tiere).
  begleiter('Begleiter');

  const HerleitungsBereich(this.anzeige);

  /// Überschrift des Bereichs.
  final String anzeige;
}

/// Ein erklärbarer Wert mit seiner Herleitung.
class HerleitungsEintrag {
  /// Erzeugt einen Eintrag; [ergebnis] ersetzt die Zahl, wenn der Wert
  /// anders angezeigt wird (etwa der TP-Ausdruck „1W6+4“).
  const HerleitungsEintrag({
    required this.id,
    required this.bereich,
    required this.titel,
    required this.herleitung,
    this.ergebnis,
  });

  /// Stabile Kennung, etwa `kampf-at`.
  final String id;

  /// Bereich für Gruppierung und Suche.
  final HerleitungsBereich bereich;

  /// Anzeigename des Werts.
  final String titel;

  /// Herleitung aus dem Regelmodul.
  final Herleitung herleitung;

  /// Abweichende Ergebnisanzeige; sonst [Herleitung.wert].
  final String? ergebnis;

  /// Angezeigtes Ergebnis.
  String get ergebnisText => ergebnis ?? '${herleitung.wert}';
}

const List<(String, String)> _basiswerte = <(String, String)>[
  ('lep', 'Lebensenergie (LeP)'),
  ('au', 'Ausdauer (Au)'),
  ('asp', 'Astralenergie (AsP)'),
  ('kap', 'Karmaenergie (KaP)'),
  ('mr', 'Magieresistenz (MR)'),
  ('iniBase', 'INI-Basis'),
  ('at', 'AT-Basis'),
  ('pa', 'PA-Basis'),
  ('fk', 'FK-Basis'),
  ('gs', 'Geschwindigkeit (GS)'),
  ('ausweichen', 'Ausweichen (Basiswert)'),
];

/// Sammelt alle vorhandenen Herleitungen eines Helden.
///
/// Fehlende Teile werden übersprungen, ebenso Werte, deren Schritte alle 0
/// sind. AsP und KaP erscheinen nur bei aktivierter Ressource ([astral],
/// [karmal]), wie in der übrigen Oberfläche.
List<HerleitungsEintrag> sammleHerleitungen({
  EigenschaftHerleitungen? eigenschaften,
  BasiswertHerleitungen? basiswerte,
  CombatPreviewStats? kampf,
  List<HeroCompanion> begleiter = const <HeroCompanion>[],
  bool astral = true,
  bool karmal = true,
}) {
  final eintraege = <HerleitungsEintrag>[];
  void neu(
    String id,
    HerleitungsBereich bereich,
    String titel,
    Herleitung? herleitung, {
    String? ergebnis,
  }) {
    if (herleitung == null || herleitung.schritte.every((s) => s.betrag == 0)) {
      return;
    }
    eintraege.add(
      HerleitungsEintrag(
        id: id,
        bereich: bereich,
        titel: titel,
        herleitung: herleitung,
        ergebnis: ergebnis,
      ),
    );
  }

  if (eigenschaften != null) {
    for (final schluessel in kEigenschaftSchluessel) {
      neu(
        'eigenschaft-$schluessel',
        HerleitungsBereich.eigenschaften,
        kEigenschaftKuerzel[schluessel]!,
        eigenschaften.je[schluessel],
      );
    }
  }
  if (basiswerte != null) {
    for (final (schluessel, titel) in _basiswerte) {
      if ((schluessel == 'asp' && !astral) ||
          (schluessel == 'kap' && !karmal)) {
        continue;
      }
      neu(
        'basiswert-$schluessel',
        HerleitungsBereich.basiswerte,
        titel,
        basiswerte.fuer(schluessel),
      );
    }
  }
  final k = kampf?.herleitungen;
  if (kampf != null && k != null) {
    const bereich = HerleitungsBereich.kampf;
    neu(
      'kampf-at',
      bereich,
      kampf.isRangedWeapon ? 'Fernkampf (FK)' : 'Attacke (AT)',
      k.at,
    );
    neu('kampf-pa', bereich, 'Parade (PA)', k.paMitIniParade);
    neu(
      'kampf-schild-pa',
      bereich,
      kampf.offhandName.trim().isEmpty
          ? 'Schild-Parade'
          : 'Schild-Parade – ${kampf.offhandName.trim()}',
      k.schildPa,
    );
    neu(
      'kampf-tp',
      bereich,
      'Trefferpunkte (TP)',
      k.tpZuschlag,
      ergebnis: kampf.tpExpression,
    );
    neu('kampf-ini', bereich, 'Kampf-Initiative', k.kampfIni);
    if (!kampf.isRangedWeapon) {
      neu('kampf-ausweichen', bereich, 'Ausweichen (Kampf)', k.ausweichen);
    }
    neu('kampf-rs', bereich, 'Rüstungsschutz (RS)', k.rs);
    neu('kampf-be', bereich, 'Behinderung (BE)', k.beKampf);
    neu('kampf-ebe', bereich, 'Effektive Behinderung (eBE)', k.ebe);
  }
  final neben = kampf?.offhandPreview;
  final nh = neben?.herleitungen;
  if (neben != null && nh != null) {
    const bereich = HerleitungsBereich.nebenhand;
    final name = neben.displayName;
    neu(
      'nebenhand-at',
      bereich,
      '${neben.isRangedWeapon ? 'Fernkampf (FK)' : 'Attacke (AT)'} – $name',
      nh.at,
    );
    neu('nebenhand-pa', bereich, 'Parade (PA) – $name', nh.paMitIniParade);
    neu(
      'nebenhand-tp',
      bereich,
      'Trefferpunkte (TP) – $name',
      nh.tpZuschlag,
      ergebnis: neben.tpExpression,
    );
  }
  for (final c in begleiter) {
    final h = begleiterHerleitungen(c);
    const bereich = HerleitungsBereich.begleiter;
    for (final (label, key) in [...kBegleiterWerte, ...kBegleiterPools]) {
      neu(
        'begleiter-${h.id}-$key',
        bereich,
        '${h.name} – $label',
        h.werte[key] ?? h.pools[key],
      );
    }
    for (final (i, angriff) in h.angriffe.indexed) {
      neu(
        'begleiter-${h.id}-angriff$i-at',
        bereich,
        '${h.name} – AT ${angriff.name}',
        angriff.at,
      );
      neu(
        'begleiter-${h.id}-angriff$i-pa',
        bereich,
        '${h.name} – PA ${angriff.name}',
        angriff.pa,
      );
    }
  }
  return eintraege;
}

/// Filtert [eintraege] nach [suche].
///
/// Die Suche zerfällt an Leerzeichen in Begriffe; ein Eintrag passt, wenn
/// jeder Begriff im Titel, im Bereich oder in Bezeichnung, Formel, Quelle
/// oder Bedingung eines Schritts vorkommt. Groß-/Kleinschreibung zählt nicht.
/// Eine leere Suche liefert alle Einträge.
List<HerleitungsEintrag> filtereHerleitungen(
  List<HerleitungsEintrag> eintraege,
  String suche,
) {
  final begriffe = _normalisiere(suche)
      .split(' ')
      .where((b) => b.isNotEmpty)
      .toList(growable: false);
  if (begriffe.isEmpty) {
    return eintraege;
  }
  return eintraege
      .where((eintrag) {
        final text = _suchtext(eintrag);
        return begriffe.every(text.contains);
      })
      .toList(growable: false);
}

String _suchtext(HerleitungsEintrag eintrag) {
  final teile = <String>[
    eintrag.titel,
    eintrag.bereich.anzeige,
    eintrag.herleitung.bezeichnung,
    for (final schritt in eintrag.herleitung.sichtbareSchritte)
      _schrittText(schritt),
  ];
  return _normalisiere(teile.join(' '));
}

String _schrittText(HerleitungsSchritt schritt) => <String>[
  schritt.bezeichnung,
  ?schritt.formel,
  ?schritt.quelle,
  ?schritt.bedingung,
].join(' ');

String _normalisiere(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
