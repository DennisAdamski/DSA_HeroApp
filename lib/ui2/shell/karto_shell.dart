import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/debug/karto_token_sheet.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_heldenwahl.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_workspace.dart';

/// Zeigt echte Heldenauswahl oder Workspace im vorhandenen ProviderScope.
class KartoShell extends ConsumerStatefulWidget {
  /// Erfordert die explizit am App-Einstieg verdrahtete Bestandsbrücke.
  const KartoShell({super.key, required this.bestand});

  /// Wiederverwendete Fachansichten und Dialoge.
  final KartoBestandsAdapter bestand;

  /// Hält nur eine lokale Bedienungssperre, keine zweite Heldenauswahl.
  @override
  ConsumerState<KartoShell> createState() => _KartoShellState();
}

class _KartoShellState extends ConsumerState<KartoShell> {
  bool _beschaeftigt = false;

  // Fehler beim Speichern der Auswahl oder beim Öffnen bleiben sichtbar.
  Future<void> _aktion(Future<void> Function() aktion) async {
    if (_beschaeftigt) return;
    _beschaeftigt = true;
    try {
      await aktion();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aktion fehlgeschlagen: $error')),
        );
      }
    } finally {
      _beschaeftigt = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(selectedHeroIdProvider);
    final helden = ref.watch(heroListProvider);
    final vorhanden =
        helden.asData?.value.any((held) => held.id == id) ?? false;
    if (id != null && vorhanden) {
      return KartoWorkspace(
        // Gleiche IDs in zwei Konten dürfen keinen lokalen Editor teilen.
        key: ValueKey((id, ObjectKey(ref.watch(heroRepositoryProvider)))),
        heroId: id,
        bestand: widget.bestand,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heldenauswahl'),
        actions: [
          IconButton(
            tooltip: 'Einstellungen',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                _aktion(() => widget.bestand.einstellungen(context)),
          ),
          if (ref.watch(debugModusProvider))
            IconButton(
              key: const ValueKey('karto-shell-tokenblatt'),
              tooltip: 'Token-Blatt',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const KartoTokenSheet(),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: KartoHeldenwahl(
              fehlendeAuswahl: id != null && helden.hasValue && !vorhanden,
              onAuswahl: (id) => _aktion(
                () => ref
                    .read(selectedHeroSelectionActionsProvider)
                    .selectHero(id),
              ),
              onVerwalten: () =>
                  _aktion(() => widget.bestand.heldenVerwalten(context)),
            ),
          ),
          SafeArea(
            top: false,
            child: TextButton(
              key: const ValueKey('karto-shell-zurueck'),
              onPressed: () => _aktion(
                () => ref
                    .read(settingsActionsProvider)
                    .setOberflaeche(Oberflaeche.codex),
              ),
              child: const Text('Zur bestehenden Oberfläche'),
            ),
          ),
        ],
      ),
    );
  }
}
