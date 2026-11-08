import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Gemeinsamer Schreibweg der Kartograph-Oberflächen für den Heldenbogen.
///
/// Jede Änderung läuft frisch (ARCH-05): `updateHero` lädt den gespeicherten
/// Helden, die [schreibeHeld] übergebene Änderung ersetzt nur die eigenen
/// Felder, gespeichert wird hinter anderen Änderungen desselben Helden. Eine
/// offene Planung sperrt jeden Weg ([gesperrt], [planungsSperre]); jede
/// Heldenänderung bräche sonst den Runden-Hash.
///
/// Die Editorprüfung der Arbeitsfläche (`vorHeldenbearbeitung`) ist keine
/// Datensicherung: Ein offener Verwaltungsentwurf gleicht beim Speichern je
/// Schlüssel frisch ab und fragt bei Überschneidung nach. Sie bleibt den
/// Stellen vorbehalten, die einen eigenen Bearbeitungsmodus beginnen
/// (Anordnen, ein Blatt öffnen), und gehört nicht in diesen Schreibweg.
mixin KartoHeldSchreiben<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// ID im gemeinsam genutzten Heldenspeicher.
  String get heroId;

  /// Satz, den die Oberfläche während einer Planung zeigt und den ein
  /// Schreibversuch dann als Fehler meldet, z. B. `Während einer Planung ist
  /// die Reiseroute gesperrt.`
  String get planungsSperre;

  /// Ob gerade ein Schreibvorgang mit `einzeln: true` läuft.
  bool schreibt = false;

  /// Letzter Schreibfehler für die Anzeige, oder `null`.
  String? fehler;

  /// Ob eine offene Planung den Bogen schreibschützt (beobachtend).
  bool get gesperrt => ref.watch(advancementSessionProvider(heroId)) != null;

  /// Einziger Schreibweg: frisch laden, nur [aenderung] anwenden, speichern.
  ///
  /// Mit [einzeln] wird ein zweiter Aufruf verworfen, solange einer läuft
  /// ([schreibt]); ohne zählt jeder Klick (Schritte, die vom gespeicherten
  /// Wert aus rechnen). Ein Fehler steht danach mit [fehlerPraefix] in
  /// [fehler]. Liefert, ob gespeichert wurde.
  Future<bool> schreibeHeld(
    HeroSheet Function(HeroSheet held) aenderung, {
    bool einzeln = true,
    String fehlerPraefix = 'Speichern fehlgeschlagen: ',
  }) async {
    if (einzeln && schreibt) return false;
    setState(() {
      if (einzeln) schreibt = true;
      fehler = null;
    });
    try {
      await aendereHeldAusserhalbPlanung(
        ref,
        heroId,
        aenderung,
        sperre: planungsSperre,
      );
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => fehler = '$fehlerPraefix${schreibFehlerText(error)}');
      }
      return false;
    } finally {
      if (einzeln && mounted) setState(() => schreibt = false);
    }
  }
}

/// Schreibt den Bogen frisch, solange keine Planung offen ist.
///
/// Kern von [KartoHeldSchreiben.schreibeHeld] für Kartograph-Wege ohne
/// eigenen Zustand (etwa das Abbuchen im Gefecht): Bei offener Planung
/// endet der Aufruf mit einem [StateError] mit [sperre], sonst lädt
/// `updateHero` den gespeicherten Helden und wendet nur [aenderung] an.
Future<HeroSheet> aendereHeldAusserhalbPlanung(
  WidgetRef ref,
  String heroId,
  HeroSheet Function(HeroSheet held) aenderung, {
  required String sperre,
}) {
  if (ref.read(advancementSessionProvider(heroId)) != null) {
    return Future<HeroSheet>.error(StateError(sperre));
  }
  return ref.read(heroActionsProvider).updateHero(heroId, aenderung);
}

/// Lesbarer Text eines Schreibfehlers: die Meldung eines [StateError], sonst
/// die Textform des Fehlers.
String schreibFehlerText(Object error) =>
    error is StateError ? error.message : error.toString();
