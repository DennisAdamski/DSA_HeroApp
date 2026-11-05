import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_held_schreiben.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_reiseroute_dialog.dart';

/// Gemeinsamer Schreibweg für Reiseroute-Kachel und Reiseroute-Blatt.
///
/// Ändert nur die Stationsliste über die Regeln in `reiseroute_rules.dart`;
/// geschrieben wird über [KartoHeldSchreiben.schreibeHeld].
mixin KartoReiserouteSchreiben<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, KartoHeldSchreiben<T> {
  @override
  String get planungsSperre =>
      'Während einer Planung ist die Reiseroute gesperrt.';

  // Zeitstempel für „Zuletzt bearbeitet“; UTC wie alle Zeitpunkte im Modell.
  DateTime _jetzt() => DateTime.now().toUtc();

  /// Legt eine Station über den Dialog an, vorbelegt mit Standort, Datum und
  /// laufendem Abenteuer.
  ///
  /// Gelesen wird beim Aufruf, nicht beim Bauen, damit der Stand von jetzt
  /// gilt.
  Future<void> stationAnlegen() async {
    final werte = ref.read(heroComputedProvider(heroId)).asData?.value;
    if (werte == null) return;
    final vorschlag = reiseStationVorschlag(
      held: werte.hero,
      standort: werte.state.standort,
      id: const Uuid().v4(),
    );
    final eingabe = await showDialog<KartoReiseStationEingabe>(
      context: context,
      builder: (_) => KartoReiseStationDialog(
        station: vorschlag,
        abenteuer: werte.hero.adventures,
      ),
    );
    if (eingabe == null || eingabe.loeschen) return;
    final station = vorschlag.copyWith(
      ort: eingabe.ort,
      datum: eingabe.datum,
      notiz: eingabe.notiz,
      adventureId: eingabe.adventureId,
      lastModified: _jetzt(),
    );
    await schreibeHeld((held) => fuegeReiseStationHinzu(held, station));
  }

  /// Bearbeitet oder löscht [station].
  Future<void> stationBearbeiten(HeroReiseStation station) async {
    final werte = ref.read(heroComputedProvider(heroId)).asData?.value;
    if (werte == null) return;
    final eingabe = await showDialog<KartoReiseStationEingabe>(
      context: context,
      builder: (_) => KartoReiseStationDialog(
        station: station,
        abenteuer: werte.hero.adventures,
        bearbeitet: true,
      ),
    );
    // Unverändert gespeichert: kein neuer Zeitstempel, kein Schreiben.
    if (eingabe == null || eingabe.gleichWie(station)) return;
    if (eingabe.loeschen) {
      if (!await _bestaetigeLoeschen()) return;
      await schreibeHeld((held) => entferneReiseStation(held, station.id));
      return;
    }
    await schreibeHeld(
      (held) => ersetzeReiseStation(
        held,
        station.id,
        // Per `copyWith`, damit unbekannte Felder bleiben. Ein neuer Ortsname
        // löst die Kartenposition des alten Orts.
        (s) => s.ort == eingabe.ort
            ? s.copyWith(
                datum: eingabe.datum,
                notiz: eingabe.notiz,
                adventureId: eingabe.adventureId,
                lastModified: _jetzt(),
              )
            : s.copyWith(
                ort: eingabe.ort,
                ortId: '',
                kartenX: null,
                kartenY: null,
                datum: eingabe.datum,
                notiz: eingabe.notiz,
                adventureId: eingabe.adventureId,
                lastModified: _jetzt(),
              ),
      ),
    );
  }

  Future<bool> _bestaetigeLoeschen() async {
    final ja = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Station löschen?'),
        content: const Text('Das lässt sich nicht rückgängig machen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    return ja ?? false;
  }
}
