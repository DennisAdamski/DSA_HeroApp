import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_outcome_rules.dart';

/// Baut die Würfelprotokolleinträge einer Rast.
///
/// Protokolliert werden die bei dieser Rast geltenden Würfe
/// ([applicableRestRollSlots]) in derselben Reihenfolge; Würfe ohne Wert
/// fehlen. [manuelleWuerfe] kennzeichnet von Hand eingetragene Werte im
/// Untertitel. Alle Einträge tragen [zeitpunkt].
List<DiceLogEntry> baueRastProtokoll({
  required RestOutcomeInput eingabe,
  Set<RestRollSlot> manuelleWuerfe = const <RestRollSlot>{},
  required DateTime zeitpunkt,
}) {
  final eintraege = <DiceLogEntry>[];
  for (final slot in applicableRestRollSlots(eingabe)) {
    final wert = eingabe.rolls[slot];
    if (wert == null) {
      continue;
    }
    final manuell = manuelleWuerfe.contains(slot);
    final beschreibung = _beschreibe(slot);
    final ziel = _zielwert(slot, eingabe);
    if (ziel == null) {
      eintraege.add(
        diceLogEntryFromRoll(
          title: beschreibung.titel,
          subtitle: manuell
              ? '${beschreibung.wuerfel} manuell'
              : '${beschreibung.wuerfel} (Summe)',
          diceValues: <int>[wert],
          total: wert,
          timestamp: zeitpunkt,
        ),
      );
    } else {
      eintraege.add(
        diceLogEntryFromSimpleCheck(
          title: beschreibung.titel,
          subtitle: manuell ? 'Zielwert $ziel, manuell' : 'Zielwert $ziel',
          roll: wert,
          targetValue: ziel,
          timestamp: zeitpunkt,
        ),
      );
    }
  }
  return eintraege;
}

// Titel und Würfelangabe eines Wurfs; bei Proben ist die Würfelangabe leer.
({String titel, String wuerfel}) _beschreibe(RestRollSlot slot) {
  switch (slot) {
    case RestRollSlot.auRoll:
      return (titel: 'Rast: Ausdauerwurf', wuerfel: '3W6');
    case RestRollSlot.auKoProbe:
      return (titel: 'Rast: KO-Probe (Ausruhen)', wuerfel: '');
    case RestRollSlot.phase1Lep:
      return (titel: 'Regeneration Phase 1: LeP-Wurf', wuerfel: '1W6');
    case RestRollSlot.phase1KoProbe:
      return (titel: 'Regeneration Phase 1: KO-Probe', wuerfel: '');
    case RestRollSlot.phase1Asp:
      return (titel: 'Regeneration Phase 1: AsP-Wurf', wuerfel: '1W6');
    case RestRollSlot.phase1InProbe:
      return (titel: 'Regeneration Phase 1: IN-Probe', wuerfel: '');
    case RestRollSlot.phase2Lep:
      return (titel: 'Regeneration Phase 2: LeP-Wurf', wuerfel: '1W6');
    case RestRollSlot.phase2KoProbe:
      return (titel: 'Regeneration Phase 2: KO-Probe', wuerfel: '');
    case RestRollSlot.phase2Asp:
      return (titel: 'Regeneration Phase 2: AsP-Wurf', wuerfel: '1W6');
    case RestRollSlot.phase2InProbe:
      return (titel: 'Regeneration Phase 2: IN-Probe', wuerfel: '');
  }
}

// Zielwert einer Probe; `null` kennzeichnet einen reinen Summenwurf.
int? _zielwert(RestRollSlot slot, RestOutcomeInput eingabe) {
  switch (slot) {
    case RestRollSlot.auKoProbe:
    case RestRollSlot.phase1KoProbe:
    case RestRollSlot.phase2KoProbe:
      return eingabe.koTarget;
    case RestRollSlot.phase1InProbe:
    case RestRollSlot.phase2InProbe:
      return eingabe.inTarget;
    case RestRollSlot.auRoll:
    case RestRollSlot.phase1Lep:
    case RestRollSlot.phase1Asp:
    case RestRollSlot.phase2Lep:
    case RestRollSlot.phase2Asp:
      return null;
  }
}
