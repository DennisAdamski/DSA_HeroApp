import 'package:dsa_heldenverwaltung/domain/trefferzonen.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';

// ---------------------------------------------------------------------------
// Standard-Humanoid-Trefferzonen-Tabelle (DSA 4.1)
// ---------------------------------------------------------------------------

/// Subzonen-Aufloesung fuer Arme: ungerade = Schildarm, gerade = Schwertarm.
TrefferSubZone _resolveArm(int roll) {
  if (roll.isOdd) {
    return const TrefferSubZone(
      zone: WundZone.linkerArm,
      label: 'Schildarm',
    );
  }
  return const TrefferSubZone(
    zone: WundZone.rechterArm,
    label: 'Schwertarm',
  );
}

/// Subzonen-Aufloesung fuer Beine: ungerade = links, gerade = rechts.
TrefferSubZone _resolveBein(int roll) {
  if (roll.isOdd) {
    return const TrefferSubZone(
      zone: WundZone.linkesBein,
      label: 'Linkes Bein',
    );
  }
  return const TrefferSubZone(
    zone: WundZone.rechtesBein,
    label: 'Rechtes Bein',
  );
}

/// Standard-Trefferzonen-Tabelle fuer humanoide Gegner.
final TrefferzonenTabelle humanoidTrefferzonenTabelle = TrefferzonenTabelle(
  name: 'Humanoid',
  eintraege: [
    TrefferzonenEintrag(
      zone: WundZone.kopf,
      label: 'Kopf',
      gezielterSchlagMod: 4,
      rollMin: 19,
      rollMax: 20,
      wundEffektBeschreibung:
          'MU, KL, IN, INI-Basis −2, INI −2W6',
      dritteWundeBeschreibung:
          '+2W6 SP, bewusstlos, Blutverlust',
    ),
    TrefferzonenEintrag(
      zone: WundZone.brust,
      label: 'Brust',
      gezielterSchlagMod: 6,
      rollMin: 15,
      rollMax: 18,
      wundEffektBeschreibung: 'AT, PA, KO, KK −1; +1W6 SP',
      dritteWundeBeschreibung: 'Bewusstlos, Blutverlust',
    ),
    TrefferzonenEintrag(
      zone: WundZone.linkerArm,
      label: 'Arme',
      gezielterSchlagMod: 4,
      rollMin: 9,
      rollMax: 14,
      wundEffektBeschreibung:
          'AT, PA, KK, FF −2 mit diesem Arm',
      dritteWundeBeschreibung: 'Arm handlungsunfähig',
      subZoneResolver: _resolveArm,
    ),
    TrefferzonenEintrag(
      zone: WundZone.bauch,
      label: 'Bauch',
      gezielterSchlagMod: 4,
      rollMin: 7,
      rollMax: 8,
      wundEffektBeschreibung:
          'AT, PA, KO, KK, GS, INI-Basis −1; +1W6 SP',
      dritteWundeBeschreibung: 'Bewusstlos, Blutverlust',
    ),
    TrefferzonenEintrag(
      zone: WundZone.linkesBein,
      label: 'Beine',
      gezielterSchlagMod: 2,
      rollMin: 1,
      rollMax: 6,
      wundEffektBeschreibung:
          'AT, PA, GE, INI-Basis −2; GS −1',
      dritteWundeBeschreibung: 'Sturz, kampfunfähig',
      subZoneResolver: _resolveBein,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Aufloesung
// ---------------------------------------------------------------------------

/// Loest einen W20-Wurf gegen eine [TrefferzonenTabelle] auf.
///
/// Wendet [tabelle.rollModifier] an und clampt das Ergebnis auf 1–20.
/// Gibt `null` zurueck, falls kein Eintrag den effektiven Wurf abdeckt
/// (sollte bei korrekten Tabellen nicht vorkommen).
TrefferzonenErgebnis? resolveTrefferzone({
  required int roll,
  required TrefferzonenTabelle tabelle,
}) {
  final effektiv = (roll + tabelle.rollModifier).clamp(1, 20);

  for (final eintrag in tabelle.eintraege) {
    if (!eintrag.matchesRoll(effektiv)) continue;

    final sub = eintrag.subZoneResolver?.call(effektiv);
    return TrefferzonenErgebnis(
      roll: roll,
      effektiverRoll: effektiv,
      eintrag: eintrag,
      zone: sub?.zone ?? eintrag.zone,
      label: sub?.label ?? eintrag.label,
    );
  }

  return null;
}
