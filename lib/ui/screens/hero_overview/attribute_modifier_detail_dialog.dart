import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/stat_modifier_detail_dialog.dart';

/// Oeffnet den kombinierten Detail- und Bearbeitungsdialog fuer Eigenschafts-
/// Modifikatoren.
///
/// [attributeLabel]: Anzeigename der Eigenschaft (z.B. "MU", "KL").
/// [baseValue]: Aktueller Basiswert der Eigenschaft.
/// [namedModifiers]: Vom Benutzer gepflegte benannte Modifikatoren.
/// [parsedSources]: Read-only Quellen, wenn keine [herleitung] vorliegt.
/// [effectiveValue]: Berechneter Endwert.
/// [herleitung]: Herleitung des Regelmoduls (ARCH-04); ersetzt Quellen und
/// Wert-/Aktuell-Zeilen.
///
/// Gibt die bearbeitete Liste zurueck, oder `null` bei Abbruch.
Future<List<HeroTalentModifier>?> showAttributeModifierDetailDialog({
  required BuildContext context,
  required String attributeLabel,
  required int baseValue,
  required List<HeroTalentModifier> namedModifiers,
  List<ModifierSourceEntry> parsedSources = const <ModifierSourceEntry>[],
  required int effectiveValue,
  Herleitung? herleitung,
}) {
  return showAdaptiveDetailSheet<List<HeroTalentModifier>>(
    context: context,
    builder: (_) => ModifierDetailDialog(
      label: attributeLabel,
      keyPrefix: 'attr',
      ergebnisBezeichnung: 'Aktuell',
      zusammenfassung: [
        (label: 'Wert', value: baseValue, fett: false),
        (label: 'Aktuell', value: effectiveValue, fett: true),
      ],
      namedModifiers: namedModifiers,
      parsedSources: parsedSources,
      herleitung: herleitung,
    ),
  );
}
