import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ui/screens/shared/planung_bearbeiten_guard.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Zeigt Gruppenname, Beitrittscode und Aktionen wie Teilen oder Verlassen.
class GruppeDetailsSection extends ConsumerWidget {
  /// Erstellt die kompakte Detailkarte einer Gruppenmitgliedschaft.
  const GruppeDetailsSection({
    super.key,
    required this.heroId,
    required this.mitgliedschaft,
    required this.syncAvailable,
  });

  /// ID des lokalen Helden.
  final String heroId;

  /// Aktuell geöffnete Gruppenmitgliedschaft.
  final HeroGruppenMitgliedschaft mitgliedschaft;

  /// Gibt an, ob Cloud-Sync-Aktionen derzeit erlaubt sind.
  final bool syncAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final istKontoGruppe = mitgliedschaft.kontoGruppe;
    final ansicht = istKontoGruppe
        ? ref.watch(gruppenAnsichtProvider(mitgliedschaft.gruppenCode))
        : null;
    final istBesitzer = ansicht?.valueOrNull?.istBesitzer ?? false;
    final zugriffVerloren = ansicht?.hasError ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mitgliedschaft.gruppenName.isEmpty
                        ? 'Unbenannte Gruppe'
                        : mitgliedschaft.gruppenName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<_GruppeAktion>(
                  onSelected: (aktion) => _handleAktion(context, ref, aktion),
                  itemBuilder: (_) => [
                    if (istKontoGruppe)
                      PopupMenuItem(
                        value: _GruppeAktion.codeKopieren,
                        enabled: syncAvailable,
                        child: const ListTile(
                          leading: Icon(Icons.copy),
                          title: Text('Beitrittscode kopieren'),
                          dense: true,
                        ),
                      ),
                    if (istKontoGruppe && istBesitzer)
                      PopupMenuItem(
                        value: _GruppeAktion.codeErneuern,
                        enabled: syncAvailable,
                        child: const ListTile(
                          leading: Icon(Icons.autorenew),
                          title: Text('Beitrittscode erneuern'),
                          dense: true,
                        ),
                      ),
                    if (istKontoGruppe && istBesitzer)
                      PopupMenuItem(
                        value: _GruppeAktion.loeschen,
                        enabled: syncAvailable,
                        child: const ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Gruppe für alle löschen'),
                          dense: true,
                        ),
                      )
                    else
                      PopupMenuItem(
                        value: _GruppeAktion.verlassen,
                        enabled: syncAvailable || !istKontoGruppe,
                        child: ListTile(
                          leading: const Icon(Icons.logout),
                          title: Text(
                            istKontoGruppe
                                ? 'Gruppe verlassen'
                                : 'Aus dem Helden entfernen',
                          ),
                          dense: true,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!istKontoGruppe)
              _Hinweis(
                icon: Icons.lock_outline,
                text:
                    'Diese Gruppe stammt aus dem alten, gesperrten Format und '
                    'wird nicht mehr synchronisiert. Erstelle eine neue '
                    'Gruppe und lade die Mitglieder mit dem neuen '
                    'Beitrittscode ein.',
              )
            else if (zugriffVerloren)
              const _Hinweis(
                icon: Icons.block,
                text:
                    'Kein Zugriff auf diese Gruppe. Du bist nicht mehr '
                    'Mitglied oder die Gruppe wurde gelöscht. Du kannst sie '
                    'über das Menü aus dem Helden entfernen.',
              )
            else
              InkWell(
                onTap: syncAvailable ? () => _codeKopieren(context, ref) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.key,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Beitrittscode kopieren',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.copy,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleAktion(
    BuildContext context,
    WidgetRef ref,
    _GruppeAktion aktion,
  ) {
    switch (aktion) {
      case _GruppeAktion.codeKopieren:
        _codeKopieren(context, ref);
      case _GruppeAktion.codeErneuern:
        _codeErneuern(context, ref);
      case _GruppeAktion.verlassen:
        _gruppeVerlassen(context, ref, loeschen: false);
      case _GruppeAktion.loeschen:
        _gruppeVerlassen(context, ref, loeschen: true);
    }
  }

  Future<void> _codeKopieren(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final code = await ref
          .read(heroActionsProvider)
          .ladeBeitrittscode(mitgliedschaft.gruppenCode);
      await Clipboard.setData(ClipboardData(text: code));
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Beitrittscode kopiert. Wer ihn kennt, kann der Gruppe beitreten.',
          ),
        ),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $error')));
    }
  }

  Future<void> _codeErneuern(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beitrittscode erneuern?'),
        content: const Text(
          'Der bisherige Code wird ungültig. Wer ihn kennt, kann der Gruppe '
          'danach nicht mehr beitreten. Bestehende Mitglieder bleiben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erneuern'),
          ),
        ],
      ),
    );
    if (bestaetigt != true) {
      return;
    }
    try {
      final code = await ref
          .read(heroActionsProvider)
          .erneuereBeitrittscode(mitgliedschaft.gruppenCode);
      await Clipboard.setData(ClipboardData(text: code));
      ref.invalidate(gruppenAnsichtProvider(mitgliedschaft.gruppenCode));
      messenger.showSnackBar(
        const SnackBar(content: Text('Neuer Beitrittscode kopiert.')),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $error')));
    }
  }

  Future<void> _gruppeVerlassen(
    BuildContext context,
    WidgetRef ref, {
    required bool loeschen,
  }) async {
    final darfBearbeiten = await bestaetigeBearbeitungBeiPlanung(
      context: context,
      heroId: heroId,
    );
    if (!darfBearbeiten || !context.mounted) {
      return;
    }
    final name = mitgliedschaft.gruppenName;
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loeschen ? 'Gruppe löschen?' : 'Gruppe verlassen?'),
        content: Text(
          loeschen
              ? 'Die Gruppe „$name" wird mit allen gemeinsamen Einträgen und '
                    'Notizen für alle Mitglieder gelöscht.'
              : 'Möchtest du die Gruppe „$name" wirklich verlassen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(loeschen ? 'Löschen' : 'Verlassen'),
          ),
        ],
      ),
    );
    if (bestaetigt != true || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final actions = ref.read(heroActionsProvider);
      if (loeschen) {
        await actions.loescheGruppe(
          heroId: heroId,
          gruppenCode: mitgliedschaft.gruppenCode,
        );
      } else {
        await actions.verlasseGruppe(
          heroId: heroId,
          gruppenCode: mitgliedschaft.gruppenCode,
        );
      }
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $error')));
    }
  }
}

class _Hinweis extends StatelessWidget {
  const _Hinweis({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

enum _GruppeAktion { codeKopieren, codeErneuern, verlassen, loeschen }
