import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';

/// Reaktive Auswahl aus dem gemeinsamen Heldenspeicher ohne eigene Selektion.
class KartoHeldenwahl extends ConsumerWidget {
  /// Überlässt die Auswahl dem Host, der Fehler und Navigation koordiniert.
  const KartoHeldenwahl({
    super.key,
    required this.onAuswahl,
    required this.onVerwalten,
    this.fehlendeAuswahl = false,
  });

  /// Speichert die ausgewählte ID über die bestehende Schreib-API.
  final ValueChanged<String> onAuswahl;

  /// Öffnet die Bestandsliste zum Anlegen und Importieren.
  final VoidCallback onVerwalten;

  /// Erklärt eine gespeicherte, inzwischen nicht mehr vorhandene ID.
  final bool fehlendeAuswahl;

  /// Zeigt Lade-, Fehler- und Leerzustand samt nutzbaren Rückwegen.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helden = ref.watch(heroListProvider);
    if (helden.hasError) {
      return _liste(context, ref, const [], fehler: helden.error);
    }
    if (!helden.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    return _liste(context, ref, helden.requireValue);
  }

  // Auch Fehler und leere Speicher behalten den Einstieg zur Bestandsliste.
  Widget _liste(
    BuildContext context,
    WidgetRef ref,
    List<HeroSheet> helden, {
    Object? fehler,
  }) {
    return ListView(
      padding: const EdgeInsets.all(Abstand.bahn),
      children: [
        Text('Deine Helden', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: Abstand.weit),
        Wrap(
          children: [
            FilledButton.icon(
              onPressed: onVerwalten,
              icon: const Icon(Icons.people_outline),
              label: const Text('Helden verwalten'),
            ),
          ],
        ),
        const SizedBox(height: Abstand.bahn),
        if (fehlendeAuswahl)
          const Text(
            'Der zuletzt gewählte Held ist nicht mehr verfügbar. '
            'Bitte wähle einen vorhandenen Helden.',
          ),
        if (fehler != null) ...[
          Text('Helden konnten nicht geladen werden: $fehler'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref.invalidate(heroListProvider),
              child: const Text('Wiederholen'),
            ),
          ),
        ] else if (helden.isEmpty)
          const Text('Noch keine Helden vorhanden.'),
        for (final held in helden)
          ListTile(
            title: Text(held.name),
            subtitle: Text(held.background.profession),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onAuswahl(held.id),
          ),
      ],
    );
  }
}
