import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/modifikatoren_dialog.dart';

export 'package:dsa_heldenverwaltung/ui/screens/shared/modifikatoren_dialog.dart'
    show ModifierSourceEntry;

/// Oeffnet den kombinierten Detail- und Bearbeitungsdialog fuer Basiswert-
/// Modifikatoren (gemeinsamer Baustein: [showModifikatorenDialog]).
///
/// [statLabel]: Anzeigename des Basiswerts (z.B. "LeP", "MR").
/// [namedModifiers]: Vom Benutzer gepflegte benannte Modifikatoren.
/// [parsedSources]: Read-only Quellen, wenn keine [herleitung] vorliegt.
/// [total]: Aktueller Gesamtmodifikator (fuer Anzeige).
/// [herleitung]: Herleitung des Regelmoduls (ARCH-04); ersetzt die Quellen
/// und zeigt Rechenweg und Ergebnis des gespeicherten Stands.
///
/// Gibt die bearbeitete Liste zurueck, oder `null` bei Abbruch.
Future<List<HeroTalentModifier>?> showStatModifierDetailDialog({
  required BuildContext context,
  required String statLabel,
  required List<HeroTalentModifier> namedModifiers,
  List<ModifierSourceEntry> parsedSources = const <ModifierSourceEntry>[],
  required int total,
  Herleitung? herleitung,
}) {
  return showModifikatorenDialog(
    context: context,
    bezeichnung: statLabel,
    schluesselPrefix: 'stat',
    modifikatoren: namedModifiers,
    abschnittTitel: 'Eigene Modifikatoren',
    herleitung: herleitung,
    ergebnisBezeichnung: statLabel,
    quellen: parsedSources,
    summenZeilen: [(label: 'Gesamt', value: total, fett: true)],
  );
}
