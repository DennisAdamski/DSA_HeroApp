import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/waffen_katalog_abgleich_rules.dart';

/// Meldet Waffen, deren TP/KK-Grundwerte vom Katalog abweichen.
///
/// Reine Anzeige: Die Befunde liefert `pruefeWaffenGegenKatalog`, die
/// Aktionen schreiben über den Aufrufer. Je Waffe stehen drei Wege offen:
/// den Unterschied als Verbesserung der Waffe übernehmen, die Waffe im Editor
/// bearbeiten oder die Abweichung als gewollt akzeptieren.
class WaffenKatalogAbgleichKarte extends StatelessWidget {
  /// Erstellt die Karte für [abweichungen]; leer zeigt sie nichts.
  const WaffenKatalogAbgleichKarte({
    super.key,
    required this.abweichungen,
    required this.onUebernehmen,
    required this.onBearbeiten,
    required this.onAkzeptieren,
  });

  /// Befunde in Reihenfolge der Waffenliste.
  final List<WaffenKatalogAbweichung> abweichungen;

  /// Trägt den Unterschied als Verbesserung der Waffe ein.
  final ValueChanged<WaffenKatalogAbweichung> onUebernehmen;

  /// Öffnet die Waffe im Editor.
  final ValueChanged<WaffenKatalogAbweichung> onBearbeiten;

  /// Bestätigt die Abweichung als gewollt.
  final ValueChanged<WaffenKatalogAbweichung> onAkzeptieren;

  @override
  Widget build(BuildContext context) {
    if (abweichungen.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final farben = theme.colorScheme;
    return Card(
      key: const ValueKey<String>('combat-weapon-katalog-abgleich'),
      color: farben.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: farben.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TP/KK weicht vom Waffenkatalog ab',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: farben.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            for (final abweichung in abweichungen)
              _AbweichungZeile(
                abweichung: abweichung,
                onUebernehmen: () => onUebernehmen(abweichung),
                onBearbeiten: () => onBearbeiten(abweichung),
                onAkzeptieren: () => onAkzeptieren(abweichung),
              ),
          ],
        ),
      ),
    );
  }
}

// Meldung und Aktionen einer einzelnen Waffe.
class _AbweichungZeile extends StatelessWidget {
  const _AbweichungZeile({
    required this.abweichung,
    required this.onUebernehmen,
    required this.onBearbeiten,
    required this.onAkzeptieren,
  });

  final WaffenKatalogAbweichung abweichung;
  final VoidCallback onUebernehmen;
  final VoidCallback onBearbeiten;
  final VoidCallback onAkzeptieren;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textFarbe = theme.colorScheme.onTertiaryContainer;
    final index = abweichung.slotIndex;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            abweichung.meldung,
            key: ValueKey<String>('combat-weapon-katalog-meldung-$index'),
            style: theme.textTheme.bodyMedium?.copyWith(color: textFarbe),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.tonal(
                key: ValueKey<String>('combat-weapon-katalog-mod-$index'),
                onPressed: onUebernehmen,
                child: Text('Als Modifikation: ${abweichung.vorschlag}'),
              ),
              OutlinedButton(
                key: ValueKey<String>('combat-weapon-katalog-edit-$index'),
                onPressed: onBearbeiten,
                child: const Text('Waffe bearbeiten'),
              ),
              TextButton(
                key: ValueKey<String>('combat-weapon-katalog-ok-$index'),
                onPressed: onAkzeptieren,
                child: const Text('Akzeptieren'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
