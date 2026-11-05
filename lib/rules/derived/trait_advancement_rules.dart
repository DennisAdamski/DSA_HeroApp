/// Nachträglicher Erwerb von Vorteilen und Abbau von Nachteilen mit AP.
///
/// Regelquelle: Wege des Schwerts S. 170 („Abbau von Nachteilen“,
/// „Späterer Erwerb von Vor- und Nachteilen“), per dsa-rules-MCP belegt:
///
/// - Nur die dort genannten Vorteile lassen sich später erwerben, zum
///   50-fachen GP-Wert in AP ([kNachtraeglichErwerbbareVorteile]).
/// - Körperliche und geistige Nachteile werden zum 100-fachen GP-Wert
///   abgebaut; ob überhaupt, entscheidet der Meister. Gesellschaftliche
///   Nachteile werden im Spiel abgebaut, nie mit AP
///   ([kGesellschaftlicheNachteile]).
/// - Schlechte Eigenschaften sinken stückweise: je Punkt 50 × GP als
///   Spezielle Erfahrung, 75 × GP im Selbststudium.
///
/// Hausregel „Epische Stufen“ S. 5: Epische Helden erwerben keine Vorteile
/// mehr nachträglich und bauen Nachteile nur noch über Spezielle Erfahrungen
/// ab.
///
/// Abbaubar ist nach Nutzerentscheidung (11. Oktober 2026) jeder Nachteil, für
/// den sich aus dem Katalog ein GP-Wert ergibt ([merkmalGpTarif]).
library;

import 'package:dsa_heldenverwaltung/catalog/hero_trait_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_acquisition_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/trait_ap_cost_rules.dart';

/// Vorteile, die laut WdS S. 170 nachträglich erworben werden dürfen.
const Set<String> kNachtraeglichErwerbbareVorteile = <String>{
  'adv_astrale_regeneration',
  'adv_ausdauernder_zauberer',
  'adv_eisenaffine_aura',
  'adv_eisern',
  'adv_entfernungssinn',
  'adv_feste_matrix',
  'adv_guter_ruf',
  'adv_gutes_gedaechtnis',
  'adv_immunitaet_einzelnes_gift',
  'adv_immunitaet_einzelne_krankheit',
  'adv_resistenz_einzelnes_gift',
  'adv_soziale_anpassungsfaehigkeit',
  'adv_verbindungen',
  'adv_wohlklang',
  'adv_zaeher_hund',
};

/// Voraussetzungen für den späteren Erwerb mit AP (Hausregel „Erweiterung und
/// Überarbeitung des Regelwerks“, Abschnitt 4). Sie gelten nur für den
/// Nachkauf, nicht für die Generierung. Offene Punkte sperren den Erwerb nicht,
/// verlangen aber einen ausdrücklichen Meisterentscheid.
const Map<String, List<SpecialAbilityRequirement>>
kNachtraeglicheVorteilVoraussetzungen =
    <String, List<SpecialAbilityRequirement>>{
      'adv_ausdauernder_zauberer': <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'KO',
          min: 15,
        ),
      ],
      'adv_eisenaffine_aura': <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Rüstungsgewöhnung',
          stufe: 2,
        ),
      ],
      'adv_eisern': <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'KO',
          min: 15,
        ),
      ],
      'adv_entfernungssinn': <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.talent,
          name: 'Sinnesschärfe',
          min: 16,
        ),
        SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'IN',
          min: 16,
        ),
      ],
      'adv_feste_matrix': <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.oderGruppe,
          bedingungen: <SpecialAbilityRequirement>[
            SpecialAbilityRequirement(
              art: RequirementArt.leiteigenschaft,
              min: 16,
            ),
            SpecialAbilityRequirement(
              art: RequirementArt.eigenschaft,
              code: 'KL',
              min: 16,
            ),
          ],
        ),
      ],
      'adv_gutes_gedaechtnis': <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'KL',
          min: 15,
        ),
      ],
      'adv_soziale_anpassungsfaehigkeit': <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'CH',
          min: 15,
        ),
        SpecialAbilityRequirement(
          art: RequirementArt.talent,
          name: 'Menschenkenntnis',
          min: 18,
        ),
      ],
      'adv_wohlklang': <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'CH',
          min: 15,
        ),
        SpecialAbilityRequirement(
          art: RequirementArt.oderGruppe,
          bedingungen: <SpecialAbilityRequirement>[
            SpecialAbilityRequirement(
              art: RequirementArt.talent,
              name: 'Singen',
              min: 15,
            ),
            SpecialAbilityRequirement(
              art: RequirementArt.talent,
              name: 'Stimmen Imitieren',
              min: 15,
            ),
          ],
        ),
      ],
      'adv_zaeher_hund': <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'KO',
          min: 15,
        ),
      ],
    };

/// Gesellschaftliche Nachteile; sie werden im Spiel abgebaut, nicht mit AP
/// (WdS S. 170 nennt „Gesucht oder Schulden“ als Beispiele).
const Set<String> kGesellschaftlicheNachteile = <String>{
  'dis_gesucht',
  'dis_schulden',
  'dis_feind',
  'dis_verpflichtungen',
  'dis_schlechter_ruf',
  'dis_randgruppe',
  'dis_unfrei',
  'dis_sippenlosigkeit',
};

/// Quellenangabe für Hinweise und Kostentexte.
const String kMerkmalSteigerungQuelle = 'Wege des Schwerts S. 170';

/// Lernweg beim Senken einer Schlechten Eigenschaft.
enum SchlechteEigenschaftLernweg {
  /// Einschneidende Konfrontation, 50 × GP je Punkt.
  spezielleErfahrung('Spezielle Erfahrung'),

  /// Anderthalbfacher Aufwand, 75 × GP je Punkt.
  selbststudium('Selbststudium');

  const SchlechteEigenschaftLernweg(this.label);

  /// Anzeigename.
  final String label;

  /// AP je GP.
  int get faktor => switch (this) {
    spezielleErfahrung => kSchlechteEigenschaftSpezErfahrungFaktor,
    selbststudium => kSchlechteEigenschaftSelbststudiumFaktor,
  };

  /// Liest den gespeicherten Optionswert; unbekannt heißt Spezielle Erfahrung.
  static SchlechteEigenschaftLernweg lies(String? name) =>
      SchlechteEigenschaftLernweg.values
          .where((weg) => weg.name == name)
          .firstOrNull ??
      spezielleErfahrung;
}

/// Ob ein Nachteil eine Schlechte Eigenschaft ist (Katalogmarker `SE`).
bool istSchlechteEigenschaft(HeroTraitDef def) => def.markers.contains('SE');

/// Ob ein Merkmal einen Zahlenwert trägt (Stufe, Punkte, `{value}`).
bool merkmalTraegtWert(HeroTraitDef def) =>
    def.selectionTemplate.contains('{value}') ||
    def.valueKind == 'level' ||
    def.valueKind == 'points';

/// GP-Wert eines Vor- oder Nachteils abhängig von Wert und Auswahl.
class MerkmalGpTarif {
  const MerkmalGpTarif._(this._rechne, {required this.wertAbhaengig});

  final double? Function(int? wert, String auswahl) _rechne;

  /// Ob der GP-Wert mit dem Zahlenwert wächst; dann lässt sich der Wert
  /// stufenweise senken bzw. steigern.
  final bool wertAbhaengig;

  /// GP-Betrag (ohne Vorzeichen) für [wert] und [auswahl]; `null`, wenn er
  /// sich daraus nicht bestimmen lässt.
  double? gp({int? wert, String auswahl = ''}) => _rechne(wert, auswahl);
}

final RegExp _staffel = RegExp(
  r'^-?\s*(\d+)(?:\s*gp)?((?:\s*/\s*-?\s*\d+(?:\s*gp)?)+)\s*gp\b',
);
final RegExp _rate = RegExp(
  r'^(?:je\s+)?-?\s*(\d+)\s*gp(?:\s*(?:pro|für|fuer|je|/)\s*(\d+)?\s*[a-zäöü]*.*)?$',
);

/// Liest den GP-Tarif aus [HeroTraitDef.costText]; `null`, wenn der
/// Katalog keinen bestimmbaren Wert nennt („unterschiedliche Kosten“,
/// Spannen wie „-3 bis -12 GP“ ohne Wert, „systemisch“).
MerkmalGpTarif? merkmalGpTarif(HeroTraitDef def) {
  // Merkmale mit der Einheit GP tragen ihren GP-Wert als Zahl
  // (Guter Ruf, Verbindungen, Moralkodex, Prinzipientreue, Stigma, Sucht).
  if (def.unit.trim().toUpperCase() == 'GP') {
    return MerkmalGpTarif._(
      (wert, _) => wert == null || wert <= 0 ? null : wert.toDouble(),
      wertAbhaengig: true,
    );
  }
  final text = def.costText
      .trim()
      .toLowerCase()
      .replaceAll('−', '-')
      .replaceFirst(RegExp(r'^idr\s+'), '');
  final staffel = _staffel.firstMatch(text);
  if (staffel != null) {
    final werte = <double>[
      double.parse(staffel.group(1)!),
      for (final teil in RegExp(r'\d+').allMatches(staffel.group(2)!))
        double.parse(teil.group(0)!),
    ];
    if (def.valueKind == 'level') {
      return MerkmalGpTarif._((wert, _) {
        if (wert == null || wert < 1 || wert > werte.length) return null;
        return werte[wert - 1];
      }, wertAbhaengig: true);
    }
    if (def.choices.length == werte.length) {
      return MerkmalGpTarif._((_, auswahl) {
        final index = def.choices.indexWhere(
          (choice) => choice.toLowerCase() == auswahl.trim().toLowerCase(),
        );
        return index < 0 ? null : werte[index];
      }, wertAbhaengig: false);
    }
    // „-2 / -3 / -4 GP je nach Merkmal“: Klassifikation I/II/III.
    if (def.choiceSource == 'merkmale' && werte.length == 3) {
      return MerkmalGpTarif._((_, auswahl) {
        if (auswahl.trim().isEmpty) return null;
        return werte[merkmalsklassifikation(auswahl) - 1];
      }, wertAbhaengig: false);
    }
    return null;
  }
  final rate = _rate.firstMatch(text);
  if (rate == null) return null;
  final betrag = double.parse(rate.group(1)!);
  final teiler = double.tryParse(rate.group(2) ?? '') ?? 1;
  final jeEinheit = betrag / teiler;
  if (merkmalTraegtWert(def)) {
    return MerkmalGpTarif._(
      (wert, _) => wert == null || wert <= 0 ? null : jeEinheit * wert,
      wertAbhaengig: true,
    );
  }
  return MerkmalGpTarif._((_, _) => jeEinheit, wertAbhaengig: false);
}

/// AP-Kosten für eine GP-Differenz, kaufmännisch gerundet.
int merkmalApKosten({required double gpDifferenz, required int faktor}) =>
    (gpDifferenz.abs() * faktor).round();

/// AP-Faktor je GP für den Abbau eines Nachteils.
int nachteilAbbauFaktor(
  HeroTraitDef def, {
  SchlechteEigenschaftLernweg lernweg =
      SchlechteEigenschaftLernweg.spezielleErfahrung,
}) => istSchlechteEigenschaft(def) ? lernweg.faktor : kNachteilAbbauFaktor;

/// Kleinster gespeicherter Wert eines Merkmals; darunter ist es abgebaut.
int merkmalMindestwert(HeroTraitDef def) =>
    (def.minValue ?? 1) < 1 ? 1 : (def.minValue ?? 1);
