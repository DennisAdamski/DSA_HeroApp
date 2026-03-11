import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_editor_section_card.dart';

/// Bearbeitet fernkampfspezifische Distanz- und Geschossdaten.
class WeaponRangedSection extends StatelessWidget {
  /// Erstellt die Fernkampf-Sektion des Waffen-Editors.
  const WeaponRangedSection({
    super.key,
    required this.reloadTimeController,
    required this.distanceLabelControllers,
    required this.distanceTpModControllers,
    required this.projectiles,
    required this.onReloadTimeChanged,
    required this.onDistanceChanged,
    required this.onAddProjectile,
    required this.onEditProjectile,
    required this.onRemoveProjectile,
  });

  final TextEditingController reloadTimeController;
  final List<TextEditingController> distanceLabelControllers;
  final List<TextEditingController> distanceTpModControllers;
  final List<RangedProjectile> projectiles;
  final ValueChanged<int> onReloadTimeChanged;
  final VoidCallback onDistanceChanged;
  final VoidCallback onAddProjectile;
  final void Function(int index) onEditProjectile;
  final void Function(int index) onRemoveProjectile;

  @override
  Widget build(BuildContext context) {
    return WeaponEditorSectionCard(
      title: 'Fernkampf',
      subtitle:
          'Verwaltet Ladezeit, Distanzstufen und projektilspezifische Modifikatoren.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _numberField(
            keyName: 'combat-weapon-form-reload-time',
            label: 'Ladezeit',
            controller: reloadTimeController,
            onChanged: onReloadTimeChanged,
          ),
          const SizedBox(height: 12),
          Text('Distanzen', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      key: ValueKey<String>(
                        'combat-weapon-form-distance-label-$i',
                      ),
                      controller: distanceLabelControllers[i],
                      decoration: InputDecoration(
                        labelText: 'Distanz ${i + 1}',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => onDistanceChanged(),
                    ),
                  ),
                  _numberField(
                    keyName: 'combat-weapon-form-distance-tp-mod-$i',
                    label: 'TP Mod',
                    controller: distanceTpModControllers[i],
                    onChanged: (_) => onDistanceChanged(),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text('Geschosse', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey<String>('combat-weapon-form-projectile-add'),
            onPressed: onAddProjectile,
            icon: const Icon(Icons.add),
            label: const Text('Geschoss hinzufuegen'),
          ),
          const SizedBox(height: 10),
          if (projectiles.isEmpty)
            const Text('Keine Geschosse hinterlegt.')
          else
            Column(
              children: [
                for (var i = 0; i < projectiles.length; i++)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        projectiles[i].name.trim().isEmpty
                            ? 'Geschoss ${i + 1}'
                            : projectiles[i].name,
                      ),
                      subtitle: Text(_projectileSummary(projectiles[i])),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            key: ValueKey<String>(
                              'combat-weapon-form-projectile-edit-$i',
                            ),
                            onPressed: () => onEditProjectile(i),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            key: ValueKey<String>(
                              'combat-weapon-form-projectile-remove-$i',
                            ),
                            onPressed: () => onRemoveProjectile(i),
                            icon: const Icon(Icons.delete),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _projectileSummary(RangedProjectile projectile) {
    final tpSign = projectile.tpMod >= 0 ? '+' : '';
    final iniSign = projectile.iniMod >= 0 ? '+' : '';
    final atSign = projectile.atMod >= 0 ? '+' : '';
    return 'Anzahl ${projectile.count}, TP $tpSign${projectile.tpMod}, '
        'INI $iniSign${projectile.iniMod}, AT $atSign${projectile.atMod}';
  }

  Widget _numberField({
    required String keyName,
    required String label,
    required TextEditingController controller,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 132,
      child: TextField(
        key: ValueKey<String>(keyName),
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (raw) {
          final parsed = int.tryParse(raw.trim());
          if (parsed != null) {
            onChanged(parsed);
          }
        },
      ),
    );
  }
}

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
    return AlertDialog(
      title: Text(
        widget.isNew ? 'Geschoss hinzufuegen' : 'Geschoss bearbeiten',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
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
        ),
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
