import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_ansage_rules.dart';
import 'gefecht_kampfmittel_rules.dart';

/// Hält offene Treffer unabhängig von späteren Treffern oder Fehlschlägen.
Gefechtszustand ergaenzeGefechtsAngriffsergebnis(
  Gefechtszustand s,
  Gefechtsangriffsergebnis? ergebnis,
) {
  if (ergebnis == null ||
      s.angriffsergebnisse.any((e) => e.auftragId == ergebnis.auftragId)) {
    return s;
  }
  return s.copyWith(
    angriffsergebnisse: List.unmodifiable([...s.angriffsergebnisse, ergebnis]),
  );
}

/// Entfernt ausschließlich den abgewickelten Treffer, auch bei Doppelcallback.
Gefechtszustand entferneGefechtsAngriffsergebnis(
  Gefechtszustand s,
  String id,
) => s.copyWith(
  angriffsergebnisse: List.unmodifiable(
    s.angriffsergebnisse.where((e) => e.auftragId != id),
  ),
);

/// Nur erfolgreich gebuchte Treffer erzeugen ein eigenes eingefrorenes Profil.
Gefechtsangriffsergebnis? gefechtsAngriffsergebnisNachBuchung({
  required String auftragId,
  required bool buchungErfolgreich,
  required bool erfolg,
  required HeroComputedSnapshot snapshot,
  required RulesCatalog katalog,
  required GefechtAuftrag auftrag,
  required Gefechtspruefung pruefung,
}) {
  final angreifen =
      pruefung.aktion == Gefechtsaktion.angriff ||
      pruefung.aktion == Gefechtsaktion.zusatzaktion && !auftrag.zusatzParade;
  if (!buchungErfolgreich ||
      !erfolg ||
      !angreifen ||
      auftrag.distanzSchritte != 0) {
    return null;
  }
  final profil = gefechtsKampfmittelFuer(snapshot, pruefung.kampfmittel);
  if (profil == null || profil.waffe == null) return null;
  final neben = profil.wahl.art == GefechtsKampfmittelArt.nebenwaffe;
  final dice = neben
      ? snapshot.combatPreviewStats.offhandPreview?.damageDiceSpec
      : snapshot.combatPreviewStats.damageDiceSpec;
  if (dice == null) return null;
  final wirkung = gefechtsAnsagewirkung(snapshot, katalog, auftrag);
  return Gefechtsangriffsergebnis(
    auftragId: auftragId,
    kampfmittel: profil.wahl,
    waffenname: profil.name,
    schaden: DiceSpec(
      count: dice.count,
      sides: dice.sides,
      modifier: dice.modifier + wirkung.tpBonus,
    ),
    abwehrmalus: wirkung.abwehrmalus,
    tpBonus: wirkung.tpBonus,
    hinweis: auftrag.manoever?.id == 'man_hammerschlag'
        ? 'Hammerschlag: die gesamte gewürfelte TP-Summe einschließlich TP-Ansage am Tisch verdreifachen. Gegnerische Abwehr und Bruchtest beachten.'
        : 'Gegnerische Abwehr, RS, Wunden und weitere Manöverfolgen am Tisch abwickeln.',
  );
}

/// Baut ausschließlich den Schadenswurf des angegebenen Angriffsergebnisses.
ResolvedProbeRequest gefechtsSchadenFuerAngriff(Gefechtsangriffsergebnis e) =>
    ResolvedProbeRequest(
      type: ProbeType.damage,
      title: 'Angriffsschaden',
      subtitle: '${e.waffenname} · ${e.schaden.label}',
      ruleHint: e.hinweis,
      diceSpec: e.schaden,
      targets: const [],
    );
