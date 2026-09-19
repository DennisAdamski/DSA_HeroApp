import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/debug/karto_token_sheet.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Rahmen der neuen Oberflaeche.
///
/// Solange noch kein Bereich fertig ist, zeigt der Rahmen einen Hinweis und
/// den Rueckweg in die bestehende Oberflaeche. Ein leerer Bildschirm waere
/// eine Sackgasse: die App wird produktiv benutzt, und wer hier landet, muss
/// weiterarbeiten koennen.
class KartoShell extends ConsumerWidget {
  /// Erstellt den Rahmen der neuen Oberflaeche.
  const KartoShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = Theme.of(context).textTheme;
    final debugModus = ref.watch(debugModusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Neue Oberfläche')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Abstand.bahn),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breite.lesespalte),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Die neue Oberfläche entsteht', style: s.titelGross),
                const SizedBox(height: Abstand.weit),
                Text(
                  'Hier wächst der Neubau Bereich für Bereich. Bis der erste '
                  'Bereich steht, arbeitest du in der bestehenden Oberfläche '
                  'weiter.',
                  style: s.fliess,
                ),
                const SizedBox(height: Abstand.bahn),
                Wrap(
                  spacing: Abstand.weit,
                  runSpacing: Abstand.weit,
                  children: [
                    FilledButton(
                      key: const ValueKey<String>('karto-shell-zurueck'),
                      onPressed: () => ref
                          .read(settingsActionsProvider)
                          .setOberflaeche(Oberflaeche.codex),
                      child: const Text('Zur bestehenden Oberfläche'),
                    ),
                    if (debugModus)
                      OutlinedButton(
                        key: const ValueKey<String>('karto-shell-tokenblatt'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const KartoTokenSheet(),
                          ),
                        ),
                        child: const Text('Token-Blatt'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
