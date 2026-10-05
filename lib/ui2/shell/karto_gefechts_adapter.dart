import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

/// Gezielt erweiterte Bestandsbrücke für einmalige Proben und Ausrüstung.
abstract interface class KartoGefechtsAdapter {
  /// Liefert Abbruch oder ein eingefrorenes Ergebnis und protokolliert es.
  Future<ProbeResult?> gefechtsProbe({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required ResolvedProbeRequest request,
    void Function(ProbeResult)? onResolved,
  });

  /// Wendet eine gezielte Ausrüstungsänderung auf den frisch geladenen Stand an.
  Future<bool> gefechtsAusruestung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required CombatConfig Function(CombatConfig) aenderung,
  });

  /// Ändert den gespeicherten Laufzeitzustand frisch.
  ///
  /// [aenderung] bekommt den gespeicherten Zustand und ersetzt nur eigene
  /// Felder. Scheitert das Speichern, erscheint die Meldung im nächsten
  /// [gefechtsFehlerBereich] und das Ergebnis ist `null`.
  Future<HeroState?> gefechtsZustand({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required String was,
    required HeroState Function(HeroState aktuell) aenderung,
  });

  /// Bereich, in dem Speicherfehler von [gefechtsZustand] erscheinen.
  ///
  /// [builder] erhält die Fehleranzeige und platziert sie im Inhalt.
  Widget gefechtsFehlerBereich({
    required Widget Function(Widget fehleranzeige) builder,
  });

  /// Erfragt den Armatrutz-RS und seine Wirkungsdauer; `null` bei Abbruch.
  Future<ActiveSpellEffectDetail?> gefechtsArmatrutzWerte(BuildContext context);

  /// Erfragt die Attributo-Boni; `null` bei Abbruch.
  Future<AttributeModifiers?> gefechtsAttributoWerte(BuildContext context);

  /// Öffnet den AsP-/KaP-Dialog mit bestätigten Abschlusskosten.
  ///
  /// [onUebernehmen] erhält den Kontext des Blatts, damit ein Speicherfehler
  /// dort erscheint und nicht im verdeckten Abschlussdialog.
  Future<void> gefechtsWirkkosten({
    required BuildContext context,
    required String heroId,
    required bool karmal,
    required int? kosten,
    required Future<bool> Function(BuildContext blatt) onUebernehmen,
  });
}
