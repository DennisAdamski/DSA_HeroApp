import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prüft das Verlassen eines Editors; false erhält Ansicht und Entwurf.
typedef KartoVerlassenPruefung = Future<bool> Function();

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

  /// Zeigt gespeicherte Spielwerte unabhängig von einer offenen Planung.
  Widget spielDetails(String heroId);

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
}
