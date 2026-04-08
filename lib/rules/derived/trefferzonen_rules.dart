import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/trefferzonen.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';

// ---------------------------------------------------------------------------
// Standard-Humanoid-Trefferzonen-Tabelle (DSA 4.1)
// ---------------------------------------------------------------------------

/// Subzonen-Aufloesung fuer Arme: ungerade = Schildarm, gerade = Schwertarm.
TrefferSubZone _resolveArm(int roll) {
  if (roll.isOdd) {
    return const TrefferSubZone(zone: WundZone.linkerArm, label: 'Schildarm');
  }
  return const TrefferSubZone(zone: WundZone.rechterArm, label: 'Schwertarm');
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
      wundEffektBeschreibung: 'MU, KL, IN, INI-Basis -2, INI -2W6',
      dritteWundeBeschreibung: '+2W6 SP, bewusstlos, Blutverlust',
      zusatzwuerfeErsteBisDritteWunde: <TrefferzonenZusatzwurf>[
        TrefferzonenZusatzwurf(
          label: 'INI-Malus',
          diceCount: 2,
          multipliziertMitWunden: true,
        ),
      ],
      zusatzwuerfeDritteWunde: <TrefferzonenZusatzwurf>[
        TrefferzonenZusatzwurf(label: 'Extraschaden', diceCount: 2),
      ],
    ),
    TrefferzonenEintrag(
      zone: WundZone.brust,
      label: 'Brust',
      gezielterSchlagMod: 6,
      rollMin: 15,
      rollMax: 18,
      wundEffektBeschreibung: 'AT, PA, KO, KK -1; +1W6 SP',
      dritteWundeBeschreibung: 'Bewusstlos, Blutverlust',
      zusatzwuerfeErsteBisDritteWunde: <TrefferzonenZusatzwurf>[
        TrefferzonenZusatzwurf(
          label: 'Extraschaden',
          diceCount: 1,
          multipliziertMitWunden: true,
        ),
      ],
    ),
    TrefferzonenEintrag(
      zone: WundZone.linkerArm,
      label: 'Arme',
      gezielterSchlagMod: 4,
      rollMin: 9,
      rollMax: 14,
      wundEffektBeschreibung: 'AT, PA, KK, FF -2 mit diesem Arm',
      dritteWundeBeschreibung: 'Arm handlungsunfähig',
      subZoneResolver: _resolveArm,
    ),
    TrefferzonenEintrag(
      zone: WundZone.bauch,
      label: 'Bauch',
      gezielterSchlagMod: 4,
      rollMin: 7,
      rollMax: 8,
      wundEffektBeschreibung: 'AT, PA, KO, KK, GS, INI-Basis -1; +1W6 SP',
      dritteWundeBeschreibung: 'Bewusstlos, Blutverlust',
      zusatzwuerfeErsteBisDritteWunde: <TrefferzonenZusatzwurf>[
        TrefferzonenZusatzwurf(
          label: 'Extraschaden',
          diceCount: 1,
          multipliziertMitWunden: true,
        ),
      ],
    ),
    TrefferzonenEintrag(
      zone: WundZone.linkesBein,
      label: 'Beine',
      gezielterSchlagMod: 2,
      rollMin: 1,
      rollMax: 6,
      wundEffektBeschreibung: 'AT, PA, GE, INI-Basis -2; GS -1',
      dritteWundeBeschreibung: 'Sturz, kampfunfähig',
      subZoneResolver: _resolveBein,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Aufloesung
// ---------------------------------------------------------------------------

/// Aufgeloester Zusatzwurf fuer die Trefferzonen-UI.
class TrefferzonenZusatzwurfErgebnis {
  const TrefferzonenZusatzwurfErgebnis({
    required this.label,
    required this.detailText,
    required this.diceSpec,
  });

  /// Anzeigename des gewuerfelten Effekts.
  final String label;

  /// Erlaeuternder Untertitel fuer die aktuelle Wundenanzahl.
  final String detailText;

  /// Effektiv zu wuerfelnde Wuerfelmenge.
  final DiceSpec diceSpec;
}

/// Loest einen W20-Wurf gegen eine [TrefferzonenTabelle] auf.
///
/// Wendet [tabelle.rollModifier] an und clampt das Ergebnis auf 1-20.
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

/// Leitet alle separat zu wuerfelnden Trefferzonen-Effekte fuer [wunden] ab.
///
/// Die Grundeffekte gelten in diesem Projekt pro erlittener Wunde.
/// Zusatzwuerfe aus der 3. Wunde kommen nur bei drei Wunden hinzu.
List<TrefferzonenZusatzwurfErgebnis> resolveTrefferzonenZusatzwuerfe({
  required TrefferzonenEintrag eintrag,
  required int wunden,
}) {
  final clampedWunden = wunden.clamp(1, maxWundenProZone);
  final ergebnisse = <TrefferzonenZusatzwurfErgebnis>[];

  for (final zusatzwurf in eintrag.zusatzwuerfeErsteBisDritteWunde) {
    final multiplikator = zusatzwurf.multipliziertMitWunden ? clampedWunden : 1;
    final diceSpec = DiceSpec(
      count: zusatzwurf.diceCount * multiplikator,
      sides: zusatzwurf.diceSides,
      modifier: zusatzwurf.modifier * multiplikator,
    );
    ergebnisse.add(
      TrefferzonenZusatzwurfErgebnis(
        label: zusatzwurf.label,
        detailText: _buildZusatzwurfDetailText(
          basiswurf: zusatzwurf,
          diceSpec: diceSpec,
          wunden: clampedWunden,
        ),
        diceSpec: diceSpec,
      ),
    );
  }

  if (clampedWunden >= maxWundenProZone) {
    for (final zusatzwurf in eintrag.zusatzwuerfeDritteWunde) {
      final diceSpec = DiceSpec(
        count: zusatzwurf.diceCount,
        sides: zusatzwurf.diceSides,
        modifier: zusatzwurf.modifier,
      );
      ergebnisse.add(
        TrefferzonenZusatzwurfErgebnis(
          label: '3. Wunde: ${zusatzwurf.label}',
          detailText: diceSpec.label,
          diceSpec: diceSpec,
        ),
      );
    }
  }

  return ergebnisse;
}

String _buildZusatzwurfDetailText({
  required TrefferzonenZusatzwurf basiswurf,
  required DiceSpec diceSpec,
  required int wunden,
}) {
  if (!basiswurf.multipliziertMitWunden) {
    return diceSpec.label;
  }

  final wundenLabel = wunden == 1 ? '1 Wunde' : '$wunden Wunden';
  final basisSpec = DiceSpec(
    count: basiswurf.diceCount,
    sides: basiswurf.diceSides,
    modifier: basiswurf.modifier,
  );
  return '${basisSpec.label} je Wunde • ${diceSpec.label} bei $wundenLabel';
}
