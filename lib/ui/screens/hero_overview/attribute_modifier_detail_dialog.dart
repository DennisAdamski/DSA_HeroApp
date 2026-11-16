import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/modifikatoren_dialog.dart';

/// Oeffnet den kombinierten Detail- und Bearbeitungsdialog fuer Eigenschafts-
/// Modifikatoren (gemeinsamer Baustein: [showModifikatorenDialog]).
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
  return showModifikatorenDialog(
    context: context,
    bezeichnung: attributeLabel,
    schluesselPrefix: 'attr',
    modifikatoren: namedModifiers,
    abschnittTitel: 'Eigene Modifikatoren',
    herleitung: herleitung,
    ergebnisBezeichnung: 'Aktuell',
    quellen: parsedSources,
    summenZeilen: [
      (label: 'Wert', value: baseValue, fett: false),
      (label: 'Aktuell', value: effectiveValue, fett: true),
    ],
  );
}
