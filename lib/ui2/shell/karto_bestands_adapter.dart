import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prüft das Verlassen eines Editors; false erhält Ansicht und Entwurf.
typedef KartoVerlassenPruefung = Future<bool> Function();

/// Ressourcen, die der Spielbereich über den Bestandsweg bearbeiten lässt.
///
/// Eigener Aufzählungstyp, weil `ResourceType` und `VitalKind` in `lib/ui/`
/// liegen und UI2 von dort nichts importiert. Die Zuordnung auf den
/// Bestandstyp macht ausschließlich die Brücke.
enum KartoRessource {
  /// Lebensenergie (LeP).
  lebensenergie,

  /// Ausdauer (AuP).
  ausdauer,

  /// Astralenergie (AsP); nur bei aktivierter Magie.
  astralenergie,

  /// Karmaenergie (KaP); nur bei aktivierten göttlichen Ressourcen.
  karma,
}

/// Begrenzte Übergangsbrücke zu bestehenden Fachansichten und Dialogen.
abstract interface class KartoBestandsAdapter {
  /// Baut die gemeinsame Verwaltung und registriert ihren Leave-Guard.
  Widget verwaltung({
    required String heroId,
    required bool korrekturenGesperrt,
    required ValueChanged<KartoVerlassenPruefung?> onVerlassenRegistriert,
  });

  /// Zeigt den Katalog der vorhandenen Steigerungssitzung.
  Widget planKatalog(String heroId);

  /// Zeigt Vorschau und Historie derselben Sitzung.
  Widget planHistorie(String heroId);

  /// Öffnet Anlegen, Import und weitere Aktionen der bisherigen Heldenliste.
  Future<void> heldenVerwalten(BuildContext context);

  /// Öffnet die vorhandenen Einstellungen im gemeinsamen ProviderScope.
  Future<void> einstellungen(BuildContext context);

  /// Öffnet die gemeinsame Probensuche mit bestehenden Würfelaktionen.
  Future<void> probeSuchen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
  });

  /// Öffnet die vorhandene Rastbedienung.
  Future<void> rast({required BuildContext context, required String heroId});

  /// Öffnet die vorhandene Verwaltung laufender Effekte.
  Future<void> effekte({required BuildContext context, required String heroId});

  /// Öffnet die vorhandene Bedienung einer einzelnen Ressource.
  ///
  /// Der Spielbereich zeigt Ressourcen nur an; Schrittweiten, Überheilung und
  /// Untergrenze bleiben beim Bestandswidget, damit es keine zweite
  /// Plus-/Minus-Logik gibt.
  Future<void> ressourceBearbeiten({
    required BuildContext context,
    required String heroId,
    required KartoRessource ressource,
  });
}
