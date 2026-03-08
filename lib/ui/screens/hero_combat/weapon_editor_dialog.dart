part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Dialog zum Anlegen und Bearbeiten einer einzelnen Waffe.
class _WeaponEditorDialog extends StatefulWidget {
  const _WeaponEditorDialog({
    required this.isNew,
    required this.initialSlot,
    required this.meleeTalents,
    required this.catalog,
    required this.previewBuilder,
    this.catalogWeaponName,
  });

  final bool isNew;
  final MainWeaponSlot initialSlot;
  final List<TalentDef> meleeTalents;
  final RulesCatalog catalog;
  final CombatPreviewStats Function(MainWeaponSlot slot) previewBuilder;
  final String? catalogWeaponName;

  @override
  State<_WeaponEditorDialog> createState() => _WeaponEditorDialogState();
}

class _WeaponEditorDialogState extends State<_WeaponEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _distanceClassController;
  late final TextEditingController _breakFactorController;
  late final TextEditingController _kkBaseController;
  late final TextEditingController _kkThresholdController;
  late final TextEditingController _iniModController;
  late final TextEditingController _wmAtController;
  late final TextEditingController _wmPaController;
  late final TextEditingController _tpDiceCountController;
  late final TextEditingController _tpFlatController;
  late final TextEditingController _beTalentModController;
  late final TextEditingController _artifactDescriptionController;

  late MainWeaponSlot _draftSlot;

  @override
  void initState() {
    super.initState();
    _draftSlot = widget.initialSlot;
    _nameController = TextEditingController(text: _draftSlot.name);
    _distanceClassController = TextEditingController(
      text: _draftSlot.distanceClass,
    );
    _breakFactorController = TextEditingController(
      text: _draftSlot.breakFactor.toString(),
    );
    _kkBaseController = TextEditingController(text: _draftSlot.kkBase.toString());
    _kkThresholdController = TextEditingController(
      text: _draftSlot.kkThreshold.toString(),
    );
    _iniModController = TextEditingController(text: _draftSlot.iniMod.toString());
    _wmAtController = TextEditingController(text: _draftSlot.wmAt.toString());
    _wmPaController = TextEditingController(text: _draftSlot.wmPa.toString());
    _tpDiceCountController = TextEditingController(
      text: _draftSlot.tpDiceCount.toString(),
    );
    _tpFlatController = TextEditingController(text: _draftSlot.tpFlat.toString());
    _beTalentModController = TextEditingController(
      text: _draftSlot.beTalentMod.toString(),
    );
    _artifactDescriptionController = TextEditingController(
      text: _draftSlot.artifactDescription,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _distanceClassController.dispose();
    _breakFactorController.dispose();
    _kkBaseController.dispose();
    _kkThresholdController.dispose();
    _iniModController.dispose();
    _wmAtController.dispose();
    _wmPaController.dispose();
    _tpDiceCountController.dispose();
    _tpFlatController.dispose();
    _beTalentModController.dispose();
    _artifactDescriptionController.dispose();
    super.dispose();
  }

  List<String> _weaponTypeOptionsForTalent(TalentDef? talent) {
    if (talent == null) {
      return const <String>[];
    }
    final seen = <String>{};
    final options = <String>[];
    final talentNameToken = _normalizeToken(talent.name);
    for (final weapon in widget.catalog.weapons) {
      if (weapon.type.trim().toLowerCase() != 'nahkampf') {
        continue;
      }
      if (_normalizeToken(weapon.combatSkill) != talentNameToken) {
        continue;
      }
      final name = weapon.name.trim();
      if (name.isEmpty || seen.contains(name)) {
        continue;
      }
      seen.add(name);
      options.add(name);
    }
    for (final raw in talent.weaponCategory.split(RegExp(r'[\n,;]+'))) {
      final value = raw.trim();
      if (value.isEmpty || seen.contains(value)) {
        continue;
      }
      seen.add(value);
      options.add(value);
    }
    options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  String _normalizeToken(String raw) {
    var value = raw.trim().toLowerCase();
    value = value
        .replaceAll(String.fromCharCode(228), 'ae')
        .replaceAll(String.fromCharCode(246), 'oe')
        .replaceAll(String.fromCharCode(252), 'ue')
        .replaceAll(String.fromCharCode(223), 'ss');
    return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  TalentDef? _selectedTalent() {
    final talentId = _draftSlot.talentId.trim();
    if (talentId.isEmpty) {
      return null;
    }
    for (final talent in widget.meleeTalents) {
      if (talent.id == talentId) {
        return talent;
      }
    }
    return null;
  }

  void _setDraftSlot(MainWeaponSlot next) {
    setState(() {
      _draftSlot = next;
    });
  }

  int _readInt(TextEditingController controller, int fallback) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  Widget _numberField({
    required String keyName,
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    required void Function(int parsed) onChanged,
  }) {
    return SizedBox(
      width: 130,
      child: TextField(
        key: ValueKey<String>(keyName),
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: enabled
            ? (raw) {
                final parsed = int.tryParse(raw.trim());
                if (parsed != null) {
                  onChanged(parsed);
                }
              }
            : null,
      ),
    );
  }

  Widget _previewValue(String label, String value, {String? keyName}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            key: keyName == null ? null : ValueKey<String>(keyName),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTalent = _selectedTalent();
    final weaponTypeOptions = _weaponTypeOptionsForTalent(
      selectedTalent,
    ).toList(growable: true)..remove(_draftSlot.weaponType.trim());
    if (_draftSlot.weaponType.trim().isNotEmpty) {
      weaponTypeOptions.add(_draftSlot.weaponType.trim());
      weaponTypeOptions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    final preview = widget.previewBuilder(_draftSlot);
    final title = widget.isNew ? 'Waffe hinzufuegen' : 'Waffe bearbeiten';

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          if ((widget.catalogWeaponName ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Vorlage: ${widget.catalogWeaponName!.trim()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey<String>('combat-weapon-form-name'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _setDraftSlot(_draftSlot.copyWith(name: value.trim()));
                },
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey<String>('combat-weapon-form-talent'),
                      initialValue: widget.meleeTalents.any(
                            (talent) => talent.id == _draftSlot.talentId.trim(),
                          )
                          ? _draftSlot.talentId.trim()
                          : '',
                      decoration: const InputDecoration(
                        labelText: 'Waffentalent',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('-'),
                        ),
                        ...widget.meleeTalents.map(
                          (talent) => DropdownMenuItem<String>(
                            value: talent.id,
                            child: Text(talent.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        final nextTalentId = value ?? '';
                        final nextTalent = widget.meleeTalents.where(
                          (talent) => talent.id == nextTalentId,
                        );
                        final selected = nextTalent.isEmpty ? null : nextTalent.first;
                        final allowedTypes = _weaponTypeOptionsForTalent(selected);
                        final nextWeaponType = allowedTypes.contains(
                              _draftSlot.weaponType.trim(),
                            )
                            ? _draftSlot.weaponType.trim()
                            : '';
                        final nextName =
                            _draftSlot.name.trim().isEmpty &&
                                nextWeaponType.isNotEmpty
                            ? nextWeaponType
                            : _draftSlot.name;
                        if (_draftSlot.name.trim().isEmpty &&
                            nextName.isNotEmpty &&
                            _nameController.text.trim().isEmpty) {
                          _nameController.text = nextName;
                        }
                        _setDraftSlot(
                          _draftSlot.copyWith(
                            talentId: nextTalentId,
                            weaponType: nextWeaponType,
                            name: nextName,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey<String>('combat-weapon-form-weapon-type'),
                      initialValue: weaponTypeOptions.contains(
                            _draftSlot.weaponType.trim(),
                          )
                          ? _draftSlot.weaponType.trim()
                          : '',
                      decoration: const InputDecoration(
                        labelText: 'Waffenart',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('-'),
                        ),
                        ...weaponTypeOptions.map(
                          (weaponType) => DropdownMenuItem<String>(
                            value: weaponType,
                            child: Text(weaponType),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        final nextWeaponType = value ?? '';
                        final nextName =
                            _draftSlot.name.trim().isEmpty &&
                                nextWeaponType.isNotEmpty
                            ? nextWeaponType
                            : _draftSlot.name;
                        if (_draftSlot.name.trim().isEmpty &&
                            nextName.isNotEmpty &&
                            _nameController.text.trim().isEmpty) {
                          _nameController.text = nextName;
                        }
                        _setDraftSlot(
                          _draftSlot.copyWith(
                            weaponType: nextWeaponType,
                            name: nextName,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 160,
                    child: TextField(
                      key: const ValueKey<String>('combat-weapon-form-dk'),
                      controller: _distanceClassController,
                      decoration: const InputDecoration(
                        labelText: 'DK',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        _setDraftSlot(
                          _draftSlot.copyWith(distanceClass: value.trim()),
                        );
                      },
                    ),
                  ),
                  _numberField(
                    keyName: 'combat-weapon-form-bf',
                    label: 'BF',
                    controller: _breakFactorController,
                    onChanged: (parsed) {
                      _setDraftSlot(
                        _draftSlot.copyWith(
                          breakFactor: parsed < 0 ? 0 : parsed,
                        ),
                      );
                    },
                  ),
                  _numberField(
                    keyName: 'combat-weapon-form-kk-base',
                    label: 'KK-Basis',
                    controller: _kkBaseController,
                    onChanged: (parsed) {
                      _setDraftSlot(_draftSlot.copyWith(kkBase: parsed));
                    },
                  ),
                  _numberField(
                    keyName: 'combat-weapon-form-kk-threshold',
                    label: 'KK-Schwelle',
                    controller: _kkThresholdController,
                    onChanged: (parsed) {
                      _setDraftSlot(
                        _draftSlot.copyWith(kkThreshold: parsed < 1 ? 1 : parsed),
                      );
                    },
                  ),
                  _numberField(
                    keyName: 'combat-weapon-form-ini-mod',
                    label: 'INI Mod',
                    controller: _iniModController,
                    onChanged: (parsed) {
                      _setDraftSlot(_draftSlot.copyWith(iniMod: parsed));
                    },
                  ),
                  _numberField(
                    keyName: 'combat-weapon-form-wm-at',
                    label: 'WM AT',
                    controller: _wmAtController,
                    onChanged: (parsed) {
                      _setDraftSlot(_draftSlot.copyWith(wmAt: parsed));
                    },
                  ),
                  _numberField(
                    keyName: 'combat-weapon-form-wm-pa',
                    label: 'WM PA',
                    controller: _wmPaController,
                    onChanged: (parsed) {
                      _setDraftSlot(_draftSlot.copyWith(wmPa: parsed));
                    },
                  ),
                  _numberField(
                    keyName: 'combat-weapon-form-dice-count',
                    label: 'Wuerfel',
                    controller: _tpDiceCountController,
                    onChanged: (parsed) {
                      _setDraftSlot(
                        _draftSlot.copyWith(tpDiceCount: parsed < 1 ? 1 : parsed),
                      );
                    },
                  ),
                  _numberField(
                    keyName: 'combat-weapon-form-tp-flat',
                    label: 'TP Wert',
                    controller: _tpFlatController,
                    onChanged: (parsed) {
                      _setDraftSlot(_draftSlot.copyWith(tpFlat: parsed));
                    },
                  ),
                  _numberField(
                    keyName: 'combat-weapon-form-be-mod',
                    label: 'BE Mod',
                    controller: _beTalentModController,
                    onChanged: (parsed) {
                      _setDraftSlot(_draftSlot.copyWith(beTalentMod: parsed));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                key: const ValueKey<String>('combat-weapon-form-one-handed'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Einhaendig gefuehrt'),
                value: _draftSlot.isOneHanded,
                onChanged: (value) {
                  _setDraftSlot(_draftSlot.copyWith(isOneHanded: value));
                },
              ),
              SwitchListTile(
                key: const ValueKey<String>('combat-weapon-form-artifact'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Artefakt'),
                value: _draftSlot.isArtifact,
                onChanged: (value) {
                  _setDraftSlot(_draftSlot.copyWith(isArtifact: value));
                },
              ),
              TextField(
                key: const ValueKey<String>(
                  'combat-weapon-form-artifact-description',
                ),
                controller: _artifactDescriptionController,
                enabled: _draftSlot.isArtifact,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Artefaktbeschreibung',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _setDraftSlot(
                    _draftSlot.copyWith(artifactDescription: value.trim()),
                  );
                },
              ),
              const SizedBox(height: 14),
              Text(
                'Vorschau',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _previewValue(
                    'AT',
                    preview.at.toString(),
                    keyName: 'combat-weapon-form-preview-at',
                  ),
                  _previewValue(
                    'PA',
                    preview.pa.toString(),
                    keyName: 'combat-weapon-form-preview-pa',
                  ),
                  _previewValue(
                    'TP',
                    preview.tpExpression,
                    keyName: 'combat-weapon-form-preview-tp',
                  ),
                  _previewValue(
                    'INI',
                    preview.kombinierteHeldenWaffenIni.toString(),
                    keyName: 'combat-weapon-form-preview-ini',
                  ),
                  _previewValue(
                    'eBE',
                    preview.ebe.toString(),
                    keyName: 'combat-weapon-form-preview-ebe',
                  ),
                ],
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
          key: const ValueKey<String>('combat-weapon-form-save'),
          onPressed: () {
            final normalized = _draftSlot.copyWith(
              name: _nameController.text.trim(),
              distanceClass: _distanceClassController.text.trim(),
              breakFactor: _readInt(
                _breakFactorController,
                _draftSlot.breakFactor,
              ).clamp(0, 9999).toInt(),
              kkBase: _readInt(_kkBaseController, _draftSlot.kkBase),
              kkThreshold: _readInt(
                _kkThresholdController,
                _draftSlot.kkThreshold,
              ) < 1
                  ? 1
                  : _readInt(_kkThresholdController, _draftSlot.kkThreshold),
              iniMod: _readInt(_iniModController, _draftSlot.iniMod),
              wmAt: _readInt(_wmAtController, _draftSlot.wmAt),
              wmPa: _readInt(_wmPaController, _draftSlot.wmPa),
              tpDiceCount: _readInt(
                _tpDiceCountController,
                _draftSlot.tpDiceCount,
              ) < 1
                  ? 1
                  : _readInt(_tpDiceCountController, _draftSlot.tpDiceCount),
              tpFlat: _readInt(_tpFlatController, _draftSlot.tpFlat),
              beTalentMod: _readInt(
                _beTalentModController,
                _draftSlot.beTalentMod,
              ),
              artifactDescription: _artifactDescriptionController.text.trim(),
            );
            Navigator.of(context).pop(normalized);
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
