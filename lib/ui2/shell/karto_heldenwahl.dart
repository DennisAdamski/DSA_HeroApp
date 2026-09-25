import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Reaktive Auswahl aus dem gemeinsamen Heldenspeicher ohne eigene Selektion.
class KartoHeldenwahl extends ConsumerWidget {
  /// Überlässt die Auswahl dem Host, der Fehler und Navigation koordiniert.
  const KartoHeldenwahl({
    super.key,
    required this.onAuswahl,
    required this.onVerwalten,
    this.onAnmelden,
    this.fehlendeAuswahl = false,
  });

  /// Speichert die ausgewählte ID über die bestehende Schreib-API.
  final ValueChanged<String> onAuswahl;

  /// Öffnet die Bestandsliste zum Anlegen und Importieren.
  final VoidCallback onVerwalten;

  /// Öffnet Login (`false`) oder Registrierung (`true`).
  ///
  /// Ohne Callback entfällt die Konto-Karte im leeren Zustand.
  final ValueChanged<bool>? onAnmelden;

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
    // Ohne Helden und ohne Konto liegen die Helden oft schon online.
    final kontoKarte =
        fehler == null &&
        helden.isEmpty &&
        onAnmelden != null &&
        ref.watch(authServiceProvider) != null &&
        ref.watch(authUserProvider).asData?.value == null;
    return ListView(
      padding: const EdgeInsets.all(Abstand.bahn),
      children: [
        Text('Deine Helden', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: Abstand.weit),
        if (kontoKarte) ...[
          _KontoKarte(onAnmelden: onAnmelden!),
          const SizedBox(height: Abstand.bahn),
        ],
        Wrap(
          children: [
            if (kontoKarte)
              OutlinedButton.icon(
                onPressed: onVerwalten,
                icon: const Icon(Icons.people_outline),
                label: const Text('Helden verwalten'),
              )
            else
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

/// Hervorgehobener Einstieg in Login und Registrierung.
class _KontoKarte extends StatelessWidget {
  const _KontoKarte({required this.onAnmelden});

  final ValueChanged<bool> onAnmelden;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return KartoFlaeche(
      key: const ValueKey('karto-heldenwahl-konto'),
      innen: Abstand.blockInnen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_sync_outlined, color: context.karto.meer, size: 32),
          const SizedBox(width: Abstand.block),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Helden schon in einem Konto?', style: text.abschnitt),
                const SizedBox(height: Abstand.eng),
                Text(
                  'Melde dich an, um deine Helden von anderen Geräten zu laden '
                  'und künftig zu synchronisieren. Ohne Konto bleibt alles '
                  'lokal.',
                  style: text.fliess,
                ),
                const SizedBox(height: Abstand.weit),
                Wrap(
                  spacing: Abstand.normal,
                  runSpacing: Abstand.normal,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('home-sign-in'),
                      onPressed: () => onAnmelden(false),
                      icon: const Icon(Icons.login),
                      label: const Text('Anmelden'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('home-register'),
                      onPressed: () => onAnmelden(true),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Konto anlegen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
