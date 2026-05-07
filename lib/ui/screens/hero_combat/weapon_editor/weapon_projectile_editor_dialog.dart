import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Bearbeitet einen einzelnen Geschosstyp innerhalb des Waffen-Editors.
class RangedProjectileEditorDialog extends StatefulWidget {
  /// Erstellt den Projektil-Dialog mit bestehendem oder leerem Draft.
  const RangedProjectileEditorDialog({
    super.key,
    required this.initialProjectile,
    required this.isNew,
  });

  final RangedProjectile initialProjectile;
  final bool isNew;

  @override
  State<RangedProjectileEditorDialog> createState() =>
      _RangedProjectileEditorDialogState();
}

class _RangedProjectileEditorDialogState
    extends State<RangedProjectileEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _countController;
  late final TextEditingController _tpModController;
  late final TextEditingController _iniModController;
  late final TextEditingController _atModController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialProjectile.name,
    );
    _countController = TextEditingController(
      text: widget.initialProjectile.count.toString(),
    );
    _tpModController = TextEditingController(
      text: widget.initialProjectile.tpMod.toString(),
    );
    _iniModController = TextEditingController(
      text: widget.initialProjectile.iniMod.toString(),
    );
    _atModController = TextEditingController(
      text: widget.initialProjectile.atMod.toString(),
    );
    _descriptionController = TextEditingController(
      text: widget.initialProjectile.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    _tpModController.dispose();
    _iniModController.dispose();
    _atModController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  int _readInt(TextEditingController controller) {
    return int.tryParse(controller.text.trim()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveInputDialog(
      title: widget.isNew ? 'Geschoss hinzufuegen' : 'Geschoss bearbeiten',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey<String>('combat-projectile-form-name'),
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _projectileNumberField(
                keyName: 'combat-projectile-form-count',
                label: 'Anzahl',
                controller: _countController,
              ),
              _projectileNumberField(
                keyName: 'combat-projectile-form-tp-mod',
                label: 'TP Mod',
                controller: _tpModController,
              ),
              _projectileNumberField(
                keyName: 'combat-projectile-form-ini-mod',
                label: 'INI Mod',
                controller: _iniModController,
              ),
              _projectileNumberField(
                keyName: 'combat-projectile-form-at-mod',
                label: 'AT Mod',
                controller: _atModController,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>(
              'combat-projectile-form-description',
            ),
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('combat-projectile-form-save'),
          onPressed: () {
            Navigator.of(context).pop(
              RangedProjectile(
                name: _nameController.text.trim(),
                count: _readInt(_countController).clamp(0, 9999),
                tpMod: _readInt(_tpModController),
                iniMod: _readInt(_iniModController),
                atMod: _readInt(_atModController),
                description: _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }

  Widget _projectileNumberField({
    required String keyName,
    required String label,
    required TextEditingController controller,
  }) {
    return SizedBox(
      width: 120,
      child: TextField(
        key: ValueKey<String>(keyName),
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
