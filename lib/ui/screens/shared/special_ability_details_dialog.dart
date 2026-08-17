import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/protected_content_helpers.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/requirement_checklist.dart';

/// Detaildialog fuer eine katalogbasierte allgemeine, karmale oder magische
/// Sonderfertigkeit.
///
/// Zeigt neben dem Regeltext die geprueften Erwerbsvoraussetzungen, sofern der
/// Aufrufer sie mitgibt. Der Freitext aus dem Katalog bleibt daneben stehen:
/// Er ist die Regelquelle, die Checkliste nur ihre maschinelle Auswertung.
class SpecialAbilityDetailsDialog extends StatelessWidget {
  /// Erzeugt den Detaildialog.
  const SpecialAbilityDetailsDialog({
    super.key,
    required this.ability,
    this.voraussetzungen = const <RequirementCheckResult>[],
  });

  /// Der angezeigte Katalogeintrag.
  final SpecialAbilityDef ability;

  /// Gepruefte Voraussetzungen; leer laesst die Checkliste weg.
  final List<RequirementCheckResult> voraussetzungen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(ability.name),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (ability.gruppe.trim().isNotEmpty)
                    Chip(label: Text('Gruppe: ${ability.gruppe.trim()}')),
                  if (ability.kategorie.trim().isNotEmpty)
                    Chip(label: Text('Kategorie: ${ability.kategorie.trim()}')),
                  if (ability.seite.trim().isNotEmpty)
                    Chip(label: Text('S. ${ability.seite.trim()}')),
                ],
              ),
              if (ability.nurInformation) ...[
                const SizedBox(height: 16),
                Text(
                  'Diese Kenntnis wird nicht als Sonderfertigkeit geführt, '
                  'sondern an ihrer eigenen Stelle im Heldenbogen gepflegt.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (voraussetzungen.isNotEmpty) ...[
                const SizedBox(height: 16),
                RequirementChecklist(
                  key: const ValueKey<String>('sf-details-voraussetzungen'),
                  ergebnisse: voraussetzungen,
                ),
              ],
              if (ability.beschreibung.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Beschreibung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.beschreibung.trim()),
              ],
              if (ability.erklarungLang.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Lange Erklärung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Consumer(
                  builder: (context, ref, _) {
                    final visible = ref.watch(catalogContentVisibleProvider);
                    final password = ref
                        .watch(appSettingsProvider)
                        .valueOrNull
                        ?.catalogContentPassword;
                    final resolved = resolveProtectedValue(
                      raw: ability.erklarungLang.trim(),
                      unlocked: visible,
                      password: password,
                    );
                    if (resolved == null) {
                      return Text(
                        lockedContentHint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    }
                    return Text(resolved);
                  },
                ),
              ],
              if (ability.voraussetzungen.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Voraussetzungen laut Regelwerk',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(ability.voraussetzungen.trim()),
              ],
              if (ability.verbreitung.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Verbreitung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.verbreitung.trim()),
              ],
              if (ability.kosten.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Kosten', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.kosten.trim()),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
