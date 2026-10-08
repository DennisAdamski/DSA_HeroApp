// Vertrautenzauber würfeln und Tierproben (WdZ S. 124–128).
//
// Die Zauber werden auf die Eigenschaften der Hexe, aber mit der
// Ritualkenntnis des Vertrauten ausgeführt, wenn die Hexe mit ihm in
// körperlichem Kontakt steht; zaubert er allein, würfelt er auf seine eigenen
// Eigenschaften, alle Proben sind aber um 15 Punkte erleichtert. Die
// Astralenergie trägt in beiden Fällen der Vertraute. Die Kosten stehen im
// Preset als Text; sie werden nur gelesen, wo sie eindeutig sind.

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_wirkwert_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/companion_steigerung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_request_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_probe_rules.dart';

/// Erleichterung aller Proben, wenn der Vertraute allein zaubert (WdZ S. 126).
const int kVertrautenAlleinErleichterung = 15;

/// Name des Zaubers, der alle AsP auf einmal umsetzt.
const String kKroetenschlagName = 'Krötenschlag';

/// Ritualkosten eines Vertrautenzaubers.
class VertrautenRitualKosten {
  /// Erstellt die Kosten.
  const VertrautenRitualKosten({
    this.grund = 0,
    this.jeSpielrunde = 0,
    this.alleAsp = false,
  });

  /// Einmalige Kosten in AsP.
  final int grund;

  /// Kosten je Spielrunde der Wirkung in AsP.
  final int jeSpielrunde;

  /// Der Zauber setzt die gesamte vorhandene Astralenergie um.
  final bool alleAsp;

  /// Gesamtkosten für [spielrunden] Spielrunden; bei [alleAsp] der Vorrat
  /// [vorrat].
  int gesamt({int spielrunden = 0, int vorrat = 0}) =>
      alleAsp ? vorrat : grund + jeSpielrunde * spielrunden;

  /// Der Zauber hat eine Dauer, die zusätzlich kostet.
  bool get hatDauerkosten => jeSpielrunde > 0;
}

final RegExp _kostenTeil = RegExp(
  r'(\d+)\s*asp(\s*pro\s*spielrunde)?',
  caseSensitive: false,
);

/// Liest die Ritualkosten aus dem Presettext, zum Beispiel „3 AsP“, „2 AsP pro
/// Spielrunde“, „3 AsP + 2 AsP pro Spielrunde“ oder „Alle AsP“.
///
/// Liefert `null`, wenn sich nichts Eindeutiges lesen lässt; dann fragt der
/// Dialog.
VertrautenRitualKosten? parseRitualKosten(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  if (RegExp(r'\balle\s+asp\b', caseSensitive: false).hasMatch(t)) {
    return const VertrautenRitualKosten(alleAsp: true);
  }
  var grund = 0;
  var jeRunde = 0;
  var gefunden = false;
  for (final m in _kostenTeil.allMatches(t)) {
    gefunden = true;
    final zahl = int.parse(m.group(1)!);
    if (m.group(2) != null) {
      jeRunde += zahl;
    } else {
      grund += zahl;
    }
  }
  if (!gefunden) return null;
  return VertrautenRitualKosten(grund: grund, jeSpielrunde: jeRunde);
}

/// Eigenschaften des Vertrauten als [Attributes] (wirksame Werte, fehlende
/// als 0).
Attributes vertrautenEigenschaften(HeroCompanion c) {
  int w(String key) => begleiterWirksamerWert(c, key) ?? 0;
  return Attributes(
    mu: w('mu'),
    kl: w('kl'),
    inn: w('inn'),
    ch: w('ch'),
    ff: w('ff'),
    ge: w('ge'),
    ko: w('ko'),
    kk: w('kk'),
  );
}

/// Ritualkenntnis (RK) des Vertrauten: Basis der Kategorie + Steigerung.
int vertrautenRk(HeroCompanion c, HeroRitualCategory kategorie) =>
    companionEffektiverRk(c, kategorie.ownKnowledge?.value ?? 0);

/// Die drei Eigenschaftskürzel der Ritualprobe von [ritual], leer wenn sie
/// nicht genau drei beträgt.
List<String> vertrautenRitualProbeCodes(HeroRitualEntry ritual) {
  final feld = ritual.additionalFieldValues
      .where((f) => f.fieldDefId == 'ritualprobe')
      .firstOrNull;
  final codes = feld?.attributeCodes ?? const <String>[];
  return codes.length == 3 ? codes : const <String>[];
}

/// Baut die RK-Probe von [ritual].
///
/// Mit [koerperkontakt] gelten die Eigenschaften der Hexe
/// ([hexeProbenEigenschaften], also nach Wunden), sonst die des Vertrauten mit
/// [kVertrautenAlleinErleichterung]. `null`, wenn das Ritual keine
/// Ritualprobe mit drei Eigenschaften trägt.
ResolvedProbeRequest? vertrautenRitualProbe({
  required HeroCompanion vertrauter,
  required HeroRitualCategory kategorie,
  required HeroRitualEntry ritual,
  required Attributes hexeProbenEigenschaften,
  required bool koerperkontakt,
}) {
  final codes = vertrautenRitualProbeCodes(ritual);
  if (codes.isEmpty) return null;
  final werte = koerperkontakt
      ? hexeProbenEigenschaften
      : vertrautenEigenschaften(vertrauter);
  final ziele = probenzieleFuer(werte, codes);
  if (ziele.length != 3) return null;
  final rk = vertrautenRk(vertrauter, kategorie);
  final anfrage = buildSpellProbeRequest(
    title: ritual.name,
    targets: ziele,
    basePool: rk,
    initialSituationalModifier: koerperkontakt
        ? 0
        : kVertrautenAlleinErleichterung,
  );
  return ResolvedProbeRequest(
    type: anfrage.type,
    title: 'Vertrautenzauber: ${ritual.name}',
    subtitle:
        '${anfrage.subtitle} · RK $rk · '
        '${koerperkontakt ? 'in Kontakt (Eigenschaften der Hexe)' : 'allein (+$kVertrautenAlleinErleichterung)'}',
    ruleHint: koerperkontakt
        ? 'Eigenschaften der Hexe, RK des Vertrauten; die AsP trägt der '
              'Vertraute (WdZ S. 126).'
        : 'Eigenschaften des Vertrauten, alle Proben um '
              '$kVertrautenAlleinErleichterung erleichtert; die AsP trägt der '
              'Vertraute (WdZ S. 126).',
    diceSpec: anfrage.diceSpec,
    targets: anfrage.targets,
    basePool: anfrage.basePool,
    initialSituationalModifier: anfrage.initialSituationalModifier,
  );
}

/// KL-Probe: das Tier versteht einen Auftrag (WdZ S. 125; der Meister
/// entscheidet, die Probe hilft dabei).
ResolvedProbeRequest vertrautenKlProbe(HeroCompanion c) =>
    buildAttributeProbeRequest(
      label: 'KL (Auftrag verstehen)',
      effectiveValue: begleiterWirksamerWert(c, 'kl') ?? 0,
    );

/// LO-Probe: das Tier folgt einem lebensgefährlichen Auftrag (WdZ S. 124).
ResolvedProbeRequest vertrautenLoProbe(HeroCompanion c) =>
    buildAttributeProbeRequest(
      label: 'LO (lebensgefährlicher Auftrag)',
      effectiveValue: begleiterWirksamerWert(c, 'loyalitaet') ?? 0,
    );

/// CH-Probe der Hexe für die Loyalität nach einem Jahr Vereinigungen
/// (WdZ S. 125).
ResolvedProbeRequest vertrautenChProbe(Attributes hexeProbenEigenschaften) =>
    buildAttributeProbeRequest(
      label: 'CH (Loyalität des Vertrauten)',
      effectiveValue: hexeProbenEigenschaften.ch,
    );
