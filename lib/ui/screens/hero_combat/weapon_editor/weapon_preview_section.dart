import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_editor_section_card.dart';

/// Zeigt die berechnete Kampfvorschau fuer den aktuellen Draft.
class WeaponPreviewSection extends StatelessWidget {
  /// Erstellt die read-only Vorschau-Sektion des Waffen-Editors.
  const WeaponPreviewSection({super.key, required this.preview});

  final CombatPreviewStats preview;

  @override
  Widget build(BuildContext context) {
    return WeaponEditorSectionCard(
      title: 'Vorschau',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _readOnlyField(
            context,
            'AT',
            preview.at.toString(),
            keyName: 'combat-weapon-form-preview-at',
          ),
          _readOnlyField(
            context,
            'PA',
            preview.isRangedWeapon ? '-' : preview.paMitIniParadeMod.toString(),
            keyName: 'combat-weapon-form-preview-pa',
          ),
          _readOnlyField(
            context,
            'TP',
            preview.tpExpression,
            keyName: 'combat-weapon-form-preview-tp',
          ),
          _readOnlyField(
            context,
            'INI',
            preview.kombinierteHeldenWaffenIni.toString(),
            keyName: 'combat-weapon-form-preview-ini',
          ),
          if (preview.isRangedWeapon)
            _readOnlyField(
              context,
              'Ladezeit',
              preview.reloadTimeDisplay,
              keyName: 'combat-weapon-form-preview-reload-time',
            ),
          _readOnlyField(
            context,
            'TP/KK',
            preview.tpKk.toString(),
            keyName: 'combat-weapon-form-preview-tpkk',
          ),
          _readOnlyField(
            context,
            'GE-Basis',
            preview.geBase.toString(),
            keyName: 'combat-weapon-form-preview-ge-base',
          ),
          _readOnlyField(
            context,
            'GE-Schwelle',
            preview.geThreshold.toString(),
            keyName: 'combat-weapon-form-preview-ge-threshold',
          ),
          _readOnlyField(
            context,
            'INI/GE',
            preview.iniGe.toString(),
            keyName: 'combat-weapon-form-preview-ini-ge',
          ),
          _readOnlyField(
            context,
            'BE-Mod',
            preview.beMod.toString(),
            keyName: 'combat-weapon-form-preview-be-mod',
          ),
          _readOnlyField(
            context,
            'eBE',
            preview.ebe.toString(),
            keyName: 'combat-weapon-form-preview-ebe',
          ),
        ],
      ),
    );
  }

  Widget _readOnlyField(
    BuildContext context,
    String label,
    String value, {
    required String keyName,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 132,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
        ),
        child: Text(
          value,
          key: ValueKey<String>(keyName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}
