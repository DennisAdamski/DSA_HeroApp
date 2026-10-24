import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Schnellaktionen des Spielbereichs.
///
/// Jede Aktion trägt eine eigene Signalfarbe, damit man sie am Tisch auf einen
/// Blick findet, statt fünf gleich aussehende Knöpfe zu lesen: Gefecht in
/// `messing` (wie die Kante des Kampfabschnitts), Probe in `meer`, Regeln in
/// `kueste` (Tinte), Rast in `moos`, Schaden in `siegel`. Die Farbe steckt in
/// Symbol, Kante und einer leichten Tönung; die Beschriftung bleibt `schrift`,
/// damit sie auf jeder Tönung lesbar ist ([kartoSchnellaktionStil]).
///
/// Die Probensuche öffnet die **vorhandene** vollständige Suche nach
/// Eigenschaften, Kampfwerten, Talenten und Zaubern. Ein nachgezeichnetes
/// Suchfeld gibt es hier nicht, weil es die echte Suche nur vortäuschen würde.
class KartoSpielaktionen extends StatelessWidget {
  /// Erstellt die Schnellaktionen.
  const KartoSpielaktionen({
    super.key,
    required this.onProbeSuchen,
    required this.onRast,
    required this.onSchaden,
    this.onRegeln,
    this.kuerzelHinweis,
    this.gefecht,
  });

  /// Öffnet die Regelwerk-Suche; `null` blendet den Knopf aus (Plattform ohne
  /// Regelindex).
  final VoidCallback? onRegeln;

  /// Einstieg ins Gefecht; steht vor allen übrigen Schnellaktionen.
  final Widget? gefecht;

  /// Öffnet die vorhandene Probensuche.
  final VoidCallback onProbeSuchen;

  /// Öffnet die vorhandene Rastbedienung.
  final VoidCallback onRast;

  /// Öffnet den geführten Ablauf „Schaden erhalten“.
  final VoidCallback onSchaden;

  /// Tastaturkürzel, das dieselbe Suche öffnet, etwa `Strg K`.
  final String? kuerzelHinweis;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;

    return Wrap(
      spacing: Abstand.weit,
      runSpacing: Abstand.normal,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ?gefecht,
        FilledButton.tonalIcon(
          key: const ValueKey<String>('karto-spiel-probe'),
          style: kartoSchnellaktionStil(context, karto.meer),
          onPressed: onProbeSuchen,
          icon: const Icon(Icons.search),
          label: const Text('Probe suchen'),
        ),
        if (onRegeln != null)
          FilledButton.tonalIcon(
            key: const ValueKey<String>('karto-spiel-regeln'),
            style: kartoSchnellaktionStil(context, karto.kueste),
            onPressed: onRegeln,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Regeln'),
          ),
        FilledButton.tonalIcon(
          key: const ValueKey<String>('karto-spiel-rast'),
          style: kartoSchnellaktionStil(context, karto.moos),
          onPressed: onRast,
          icon: const Icon(Icons.hotel_outlined),
          label: const Text('Rast'),
        ),
        FilledButton.tonalIcon(
          key: const ValueKey<String>('karto-spiel-schaden'),
          style: kartoSchnellaktionStil(context, karto.siegel),
          onPressed: onSchaden,
          icon: const Icon(Icons.heart_broken_outlined),
          label: const Text('Schaden erhalten'),
        ),
        if (kuerzelHinweis != null)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: karto.hoehenlinie,
                width: Strich.hoehenlinie,
              ),
              borderRadius: BorderRadius.circular(kKartoRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Abstand.knapp,
                vertical: Abstand.haar,
              ),
              child: Text(
                kuerzelHinweis!,
                style: texte.marke.copyWith(color: karto.schriftLeise),
              ),
            ),
          ),
      ],
    );
  }
}

/// Stil einer Schnellaktion in ihrer eigenen Signalfarbe [farbe].
///
/// Tönung wie die Container-Rollen des Themes (Farbe zu 14 % deckend auf
/// `feld`), Symbol und Kante in der Farbe, Beschriftung in `schrift`. So hält
/// das Symbol in beiden Paletten mindestens 3:1 zur Tönung und die
/// Beschriftung mehr als 10:1. Flach wie jeder Knopf: angehoben wird nur, was
/// schwebt.
ButtonStyle kartoSchnellaktionStil(BuildContext context, Color farbe) {
  final karto = context.karto;
  return FilledButton.styleFrom(
    backgroundColor: Color.alphaBlend(
      farbe.withValues(alpha: 0.14),
      karto.feld,
    ),
    foregroundColor: karto.schrift,
    iconColor: farbe,
    side: BorderSide(color: farbe, width: Strich.grat),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kKartoRadiusKlein),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith<Color?>(
      (zustand) =>
          zustand.contains(WidgetState.pressed) ||
              zustand.contains(WidgetState.hovered) ||
              zustand.contains(WidgetState.focused)
          ? farbe.withValues(alpha: 0.10)
          : null,
    ),
  );
}
