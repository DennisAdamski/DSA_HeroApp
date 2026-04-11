import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_gruppe/gruppe_beitreten_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_gruppe/gruppe_details_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_gruppe/gruppe_erstellen_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_gruppe/gruppe_mitglieder_liste.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_gruppe/manueller_held_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

/// Workspace-Tab für Gruppenverwaltung.
///
/// Zeigt die Gruppen des Helden, deren Mitglieder und bietet Aktionen zum
/// Erstellen, Beitreten und Verwalten von Gruppen.
class HeroGruppeTab extends ConsumerStatefulWidget {
  /// Erstellt den Gruppen-Tab im Workspace.
  const HeroGruppeTab({
    super.key,
    required this.heroId,
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  /// ID des aktuell geöffneten Helden.
  final String heroId;

  /// Meldet Änderungen am Dirty-Status an den Workspace.
  final ValueChanged<bool> onDirtyChanged;

  /// Meldet Änderungen am Editierstatus an den Workspace.
  final ValueChanged<bool> onEditingChanged;

  /// Registriert eine asynchrone Verwerfen-Aktion beim Host.
  final ValueChanged<WorkspaceAsyncAction> onRegisterDiscard;

  /// Registriert die Edit-Aktionen dieses Tabs beim Host.
  final ValueChanged<WorkspaceTabEditActions> onRegisterEditActions;

  @override
  ConsumerState<HeroGruppeTab> createState() => _HeroGruppeTabState();
}

class _HeroGruppeTabState extends ConsumerState<HeroGruppeTab> {
  String? _selectedGruppenCode;

  @override
  void initState() {
    super.initState();
    // Kein Edit-Modus: Aktionen laufen direkt und ohne lokale Drafts.
    widget.onEditingChanged(false);
    widget.onDirtyChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final firebaseBootstrap = ref.watch(firebaseBootstrapProvider);
    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden'));
    }

    final gruppen = hero.gruppen;
    final syncAvailable = firebaseBootstrap.isAvailable;
    final syncMessage =
        firebaseBootstrap.userMessage ??
        'Gruppen-Sync ist derzeit nicht verfügbar.';

    if (gruppen.isEmpty) {
      return _LeereGruppenAnsicht(
        heroId: widget.heroId,
        syncAvailable: syncAvailable,
        syncMessage: syncMessage,
        onGruppeErstellt: (code) => setState(() {
          _selectedGruppenCode = code;
        }),
      );
    }

    final aktiveGruppe = gruppen.firstWhere(
      (g) => g.gruppenCode == _selectedGruppenCode,
      orElse: () => gruppen.first,
    );
    if (_selectedGruppenCode != aktiveGruppe.gruppenCode) {
      _selectedGruppenCode = aktiveGruppe.gruppenCode;
    }

    return Column(
      children: [
        if (!syncAvailable)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _GruppenSyncHinweisCard(message: syncMessage),
          ),
        if (gruppen.length > 1)
          _GruppenChipBar(
            gruppen: gruppen,
            ausgewaehlterCode: aktiveGruppe.gruppenCode,
            onAuswahlGeaendert: (code) => setState(() {
              _selectedGruppenCode = code;
            }),
          ),
        Expanded(
          child: _GruppenDetailAnsicht(
            heroId: widget.heroId,
            mitgliedschaft: aktiveGruppe,
            syncAvailable: syncAvailable,
          ),
        ),
      ],
    );
  }
}

/// Leerzustand, wenn der Held keiner Gruppe angehört.
class _LeereGruppenAnsicht extends ConsumerWidget {
  const _LeereGruppenAnsicht({
    required this.heroId,
    required this.syncAvailable,
    required this.syncMessage,
    required this.onGruppeErstellt,
  });

  final String heroId;
  final bool syncAvailable;
  final String syncMessage;
  final ValueChanged<String> onGruppeErstellt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Noch keiner Gruppe beigetreten',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Erstelle eine neue Gruppe oder tritt einer bestehenden Gruppe bei.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (!syncAvailable) ...[
              const SizedBox(height: 16),
              _GruppenSyncHinweisCard(message: syncMessage),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed:
                  syncAvailable ? () => _erstelleGruppe(context, ref) : null,
              icon: const Icon(Icons.add),
              label: const Text('Gruppe erstellen'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: syncAvailable ? () => _trittBei(context, ref) : null,
              icon: const Icon(Icons.login),
              label: const Text('Gruppe beitreten'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _erstelleGruppe(BuildContext context, WidgetRef ref) async {
    final code = await showGruppeErstellenDialog(
      context: context,
      ref: ref,
      heroId: heroId,
    );
    if (code != null) {
      onGruppeErstellt(code);
    }
  }

  Future<void> _trittBei(BuildContext context, WidgetRef ref) async {
    final code = await showGruppeBeitretenDialog(
      context: context,
      ref: ref,
      heroId: heroId,
    );
    if (code != null) {
      onGruppeErstellt(code);
    }
  }
}

/// Chip-Leiste für die Auswahl bei mehreren Gruppen.
class _GruppenChipBar extends StatelessWidget {
  const _GruppenChipBar({
    required this.gruppen,
    required this.ausgewaehlterCode,
    required this.onAuswahlGeaendert,
  });

  final List<HeroGruppenMitgliedschaft> gruppen;
  final String ausgewaehlterCode;
  final ValueChanged<String> onAuswahlGeaendert;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final gruppe in gruppen)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  gruppe.gruppenName.isEmpty ? 'Gruppe' : gruppe.gruppenName,
                ),
                selected: gruppe.gruppenCode == ausgewaehlterCode,
                onSelected: (_) => onAuswahlGeaendert(gruppe.gruppenCode),
              ),
            ),
        ],
      ),
    );
  }
}

/// Detailansicht einer einzelnen Gruppe mit Mitgliederliste und Aktionen.
class _GruppenDetailAnsicht extends ConsumerWidget {
  const _GruppenDetailAnsicht({
    required this.heroId,
    required this.mitgliedschaft,
    required this.syncAvailable,
  });

  final String heroId;
  final HeroGruppenMitgliedschaft mitgliedschaft;
  final bool syncAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
      children: [
        GruppeDetailsSection(
          heroId: heroId,
          mitgliedschaft: mitgliedschaft,
          syncAvailable: syncAvailable,
        ),
        const SizedBox(height: 16),
        GruppeMitgliederListe(
          heroId: heroId,
          gruppenCode: mitgliedschaft.gruppenCode,
        ),
        const SizedBox(height: 16),
        _AktionsLeiste(
          heroId: heroId,
          gruppenCode: mitgliedschaft.gruppenCode,
          syncAvailable: syncAvailable,
        ),
      ],
    );
  }
}

/// Aktionsbuttons unterhalb der Mitgliederliste.
class _AktionsLeiste extends ConsumerStatefulWidget {
  const _AktionsLeiste({
    required this.heroId,
    required this.gruppenCode,
    required this.syncAvailable,
  });

  final String heroId;
  final String gruppenCode;
  final bool syncAvailable;

  @override
  ConsumerState<_AktionsLeiste> createState() => _AktionsLeisteState();
}

class _AktionsLeisteState extends ConsumerState<_AktionsLeiste> {
  bool _isSyncing = false;

  Future<void> _sync() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(heroActionsProvider).syncGruppen(widget.heroId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synchronisierung abgeschlossen')),
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync fehlgeschlagen: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: widget.syncAvailable && !_isSyncing ? _sync : null,
          icon: _isSyncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: const Text('Synchronisieren'),
        ),
        FilledButton.tonalIcon(
          onPressed: widget.syncAvailable ? () => _addManuell() : null,
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Manuell hinzufügen'),
        ),
        OutlinedButton.icon(
          onPressed: _codeTeilen,
          icon: const Icon(Icons.share_outlined),
          label: const Text('Code teilen'),
        ),
      ],
    );
  }

  Future<void> _addManuell() async {
    await showManuellerHeldDialog(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      gruppenCode: widget.gruppenCode,
    );
  }

  void _codeTeilen() {
    Clipboard.setData(ClipboardData(text: widget.gruppenCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gruppencode kopiert')),
    );
  }
}

/// Zeigt an, dass Cloud-Sync aktuell deaktiviert ist.
class _GruppenSyncHinweisCard extends StatelessWidget {
  const _GruppenSyncHinweisCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
