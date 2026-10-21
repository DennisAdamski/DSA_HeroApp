import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_dialoge.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_laufendes_abenteuer.dart';

/// Gemeinsamer Schreibweg für Abenteuerblatt und Abenteuerabschnitt.
///
/// Beide Oberflächen ändern **ein** Abenteuer gezielt: frisch laden, nur dieses
/// Abenteuer per `copyWith` ersetzen ([ersetzeAbenteuer]), speichern. Der
/// Verwaltungseditor dagegen legt seinen ganzen Entwurf über den Helden; deshalb
/// kennt dieser Weg weder Abschluss noch Belohnungen.
///
/// Gespeichert wird hier selbst und nicht über die Laufzeitaktion des
/// Workspace: das Öffnen des Blatts läuft bereits in deren Re-Entrancy-Guard,
/// jede weitere Aktion darin würde still verworfen. Doppelte Auslösung
/// verhindert [schreibt]; während einer Planung ist alles gesperrt.
mixin KartoAbenteuerSchreiben<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// ID im gemeinsam genutzten Heldenspeicher.
  String get heroId;

  /// Stabile ID des bearbeiteten Abenteuers.
  String get abenteuerId;

  /// Ob gerade ein Schreibvorgang läuft.
  bool schreibt = false;

  /// Letzter Schreibfehler für die Anzeige, oder `null`.
  String? fehler;

  /// Ob eine offene Planung das Abenteuer schreibschützt.
  bool get gesperrt => ref.watch(advancementSessionProvider(heroId)) != null;

  /// Einziger Schreibweg: frisch laden, nur dieses Abenteuer ersetzen.
  Future<void> schreibe(
    HeroAdventureEntry Function(HeroAdventureEntry abenteuer) aenderung,
  ) async {
    if (schreibt) return;
    setState(() {
      schreibt = true;
      fehler = null;
    });
    try {
      if (ref.read(advancementSessionProvider(heroId)) != null) {
        throw StateError('Während einer Planung ist das Abenteuer gesperrt.');
      }
      await ref
          .read(heroActionsProvider)
          .updateHero(
            heroId,
            (held) => ersetzeAbenteuer(held, abenteuerId, aenderung),
          );
    } catch (error) {
      if (mounted) {
        setState(() => fehler = 'Speichern fehlgeschlagen: ${_text(error)}');
      }
    } finally {
      if (mounted) setState(() => schreibt = false);
    }
  }

  // Zeitstempel für „Zuletzt bearbeitet“; UTC wie alle Zeitpunkte im Modell.
  DateTime _jetzt() => DateTime.now().toUtc();

  String _text(Object error) =>
      error is StateError ? error.message : error.toString();

  /// Fragt das aktuelle Datum ab und speichert es.
  Future<void> datumAendern(HeroAdventureEntry abenteuer) async {
    final datum = await showDialog<HeroAdventureDateValue>(
      context: context,
      builder: (_) =>
          KartoDatumDialog(initial: abenteuer.currentAventurianDate),
    );
    if (datum == null) return;
    await schreibe((a) => a.copyWith(currentAventurianDate: datum));
  }

  /// Fragt die Zusammenfassung ab und speichert sie.
  Future<void> zusammenfassungAendern(HeroAdventureEntry abenteuer) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => KartoTextDialog(initial: abenteuer.summary),
    );
    if (text == null) return;
    await schreibe((a) => a.copyWith(summary: text.trim()));
  }

  /// Legt eine Notiz über den Dialog an.
  Future<void> notizAnlegen() async {
    final ergebnis = await showDialog<KartoZweiFelder>(
      context: context,
      builder: (_) => const KartoZweiFelderDialog.notiz(),
    );
    if (ergebnis == null || ergebnis.loeschen) return;
    await _notizHinzufuegen(ergebnis.erstes, ergebnis.zweites);
  }

  /// Hält eine Notiz aus einer einzelnen Zeile fest (Schnell-Erfassung).
  ///
  /// Leere Eingaben werden verworfen. Der Text wird der Titel; die Beschreibung
  /// bleibt leer und lässt sich später über die Karte ergänzen.
  Future<void> notizSchnell(String text) async {
    final titel = text.trim();
    if (titel.isEmpty) return;
    await _notizHinzufuegen(titel, '');
  }

  Future<void> _notizHinzufuegen(String titel, String beschreibung) {
    final notiz = HeroNoteEntry(
      title: titel,
      description: beschreibung,
      lastModified: _jetzt(),
    );
    return schreibe((a) => a.copyWith(notes: [...a.notes, notiz]));
  }

  /// Bearbeitet oder löscht die Notiz an [index].
  Future<void> notizBearbeiten(int index, HeroNoteEntry notiz) async {
    final ergebnis = await showDialog<KartoZweiFelder>(
      context: context,
      builder: (_) => KartoZweiFelderDialog.notiz(
        erstes: notiz.title,
        zweites: notiz.description,
      ),
    );
    if (ergebnis == null) return;
    // Unverändert gespeichert: kein neuer Zeitstempel, kein Schreiben.
    if (!ergebnis.loeschen &&
        ergebnis.erstes == notiz.title &&
        ergebnis.zweites == notiz.description) {
      return;
    }
    if (ergebnis.loeschen && !await _bestaetigeLoeschen('Notiz')) return;
    await schreibe((a) {
      // Der Index stammt aus der Anzeige; stimmt er nicht mehr mit dem
      // frisch geladenen Stand überein, wird nichts Falsches überschrieben.
      if (index >= a.notes.length ||
          a.notes[index].title != notiz.title ||
          a.notes[index].description != notiz.description) {
        throw StateError('Die Notiz wurde inzwischen geändert.');
      }
      final notizen = List<HeroNoteEntry>.of(a.notes);
      if (ergebnis.loeschen) {
        notizen.removeAt(index);
      } else {
        // Per `copyWith`, damit unbekannte Felder erhalten bleiben.
        notizen[index] = notizen[index].copyWith(
          title: ergebnis.erstes,
          description: ergebnis.zweites,
          lastModified: _jetzt(),
        );
      }
      return a.copyWith(notes: notizen);
    });
  }

  /// Legt eine Person über den Dialog an.
  Future<void> personAnlegen() async {
    final ergebnis = await showDialog<KartoZweiFelder>(
      context: context,
      builder: (_) => const KartoZweiFelderDialog.person(),
    );
    if (ergebnis == null || ergebnis.loeschen) return;
    final person = HeroAdventurePersonEntry(
      id: const Uuid().v4(),
      name: ergebnis.erstes,
      description: ergebnis.zweites,
      lastModified: _jetzt(),
    );
    await schreibe((a) => a.copyWith(people: [...a.people, person]));
  }

  /// Bearbeitet oder löscht [person].
  Future<void> personBearbeiten(HeroAdventurePersonEntry person) async {
    final ergebnis = await showDialog<KartoZweiFelder>(
      context: context,
      builder: (_) => KartoZweiFelderDialog.person(
        erstes: person.name,
        zweites: person.description,
      ),
    );
    if (ergebnis == null) return;
    if (!ergebnis.loeschen &&
        ergebnis.erstes == person.name &&
        ergebnis.zweites == person.description) {
      return;
    }
    if (ergebnis.loeschen && !await _bestaetigeLoeschen('Person')) return;
    await schreibe((a) {
      if (!a.people.any((p) => p.id == person.id)) {
        throw StateError('Die Person wurde inzwischen entfernt.');
      }
      return a.copyWith(
        people: [
          for (final p in a.people)
            if (p.id != person.id)
              p
            else if (!ergebnis.loeschen)
              p.copyWith(
                name: ergebnis.erstes,
                description: ergebnis.zweites,
                lastModified: _jetzt(),
              ),
        ],
      );
    });
  }

  Future<bool> _bestaetigeLoeschen(String was) async {
    final ja = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$was löschen?'),
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
