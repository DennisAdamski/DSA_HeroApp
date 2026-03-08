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
    _kkBaseController = TextEditingController(
      text: _draftSlot.kkBase.toString(),
    );
    _kkThresholdController = TextEditingController(
      text: _draftSlot.kkThreshold.toString(),
    );
    _iniModController = TextEditingController(
      text: _draftSlot.iniMod.toString(),
    );
    _wmAtController = TextEditingController(text: _draftSlot.wmAt.toString());
    _wmPaController = TextEditingController(text: _draftSlot.wmPa.toString());
    _tpDiceCountController = TextEditingController(
      text: _draftSlot.tpDiceCount.toString(),
    );
    _tpFlatController = TextEditingController(
      text: _draftSlot.tpFlat.toString(),
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
    _artifactDescriptionController.dispose();
    super.dispose();
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

  List<String> _allWeaponTypeOptions() {
    final seen = <String>{};
    final options = <String>[];
    for (final weapon in widget.catalog.weapons) {
      if (weapon.type.trim().toLowerCase() != 'nahkampf') {
        continue;
      }
      final name = weapon.name.trim();
      if (name.isEmpty || seen.contains(name)) {
        continue;
      }
      seen.add(name);
      options.add(name);
    }
    final current = _draftSlot.weaponType.trim();
    if (current.isNotEmpty && !seen.contains(current)) {
      options.add(current);
    }
    options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  List<TalentDef> _talentOptionsForWeaponType(String weaponType) {
    final token = _normalizeToken(weaponType);
    if (token.isEmpty) {
      return widget.meleeTalents;
    }

    final allowedById = <String>{};
    for (final weapon in widget.catalog.weapons) {
      if (weapon.type.trim().toLowerCase() != 'nahkampf') {
        continue;
      }
      if (_normalizeToken(weapon.name) != token) {
        continue;
      }
      final skillToken = _normalizeToken(weapon.combatSkill);
      for (final talent in widget.meleeTalents) {
        if (_normalizeToken(talent.name) == skillToken) {
          allowedById.add(talent.id);
        }
      }
    }

    for (final talent in widget.meleeTalents) {
      final categories = talent.weaponCategory.split(RegExp(r'[\n,;]+'));
      for (final category in categories) {
        if (_normalizeToken(category) == token) {
          allowedById.add(talent.id);
          break;
        }
      }
    }

    return widget.meleeTalents
        .where((talent) => allowedById.contains(talent.id))
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  bool _isTalentValidForWeaponType({
    required String talentId,
    required String weaponType,
  }) {
    if (talentId.trim().isEmpty) {
      return true;
    }
    return _talentOptionsForWeaponType(
      weaponType,
    ).any((talent) => talent.id == talentId.trim());
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
      width: 132,
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

  Widget _readOnlyField(String label, String value, {String? keyName}) {
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
          key: keyName == null ? null : ValueKey<String>(keyName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.isNew ? 'Waffe hinzufuegen' : 'Waffe bearbeiten';
    final currentWeaponType = _draftSlot.weaponType.trim();
    final talentOptions = _talentOptionsForWeaponType(currentWeaponType);
    final currentTalentId =
        _isTalentValidForWeaponType(
          talentId: _draftSlot.talentId,
          weaponType: currentWeaponType,
        )
        ? _draftSlot.talentId.trim()
        : '';
    final preview = widget.previewBuilder(
      currentTalentId == _draftSlot.talentId.trim()
          ? _draftSlot
          : _draftSlot.copyWith(talentId: ''),
    );

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
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionCard(
                title: 'Stammdaten',
                child: Column(
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
                    DropdownButtonFormField<String>(
                      key: const ValueKey<String>(
                        'combat-weapon-form-weapon-type',
                      ),
                      initialValue:
                          _allWeaponTypeOptions().contains(currentWeaponType)
                          ? currentWeaponType
                          : '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Waffenart',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('-'),
                        ),
                        ..._allWeaponTypeOptions().map(
                          (weaponType) => DropdownMenuItem<String>(
                            value: weaponType,
                            child: Text(
                              weaponType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        final nextWeaponType = value ?? '';
                        final nextTalentId =
                            _isTalentValidForWeaponType(
                              talentId: _draftSlot.talentId,
                              weaponType: nextWeaponType,
                            )
                            ? _draftSlot.talentId
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
                            weaponType: nextWeaponType,
                            talentId: nextTalentId,
                            name: nextName,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Waffenwerte',
                subtitle:
                    'Das Waffentalent wird nach der gewaehlten Waffenart gefiltert.',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
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
                    SizedBox(
                      width: 132,
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
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        key: const ValueKey<String>(
                          'combat-weapon-form-talent',
                        ),
                        initialValue:
                            talentOptions.any(
                              (talent) => talent.id == currentTalentId,
                            )
                            ? currentTalentId
                            : '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Waffentalent',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('-'),
                          ),
                          ...talentOptions.map(
                            (talent) => DropdownMenuItem<String>(
                              value: talent.id,
                              child: Text(
                                talent.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          _setDraftSlot(
                            _draftSlot.copyWith(talentId: value ?? ''),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: SwitchListTile(
                        key: const ValueKey<String>(
                          'combat-weapon-form-one-handed',
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Einhaendig'),
                        value: _draftSlot.isOneHanded,
                        onChanged: (value) {
                          _setDraftSlot(
                            _draftSlot.copyWith(isOneHanded: value),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Errechnete Werte',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _readOnlyField(
                      'AT',
                      preview.at.toString(),
                      keyName: 'combat-weapon-form-preview-at',
                    ),
                    _readOnlyField(
                      'PA',
                      preview.paMitIniParadeMod.toString(),
                      keyName: 'combat-weapon-form-preview-pa',
                    ),
                    _readOnlyField(
                      'TP',
                      preview.tpExpression,
                      keyName: 'combat-weapon-form-preview-tp',
                    ),
                    _readOnlyField(
                      'INI',
                      preview.kombinierteHeldenWaffenIni.toString(),
                      keyName: 'combat-weapon-form-preview-ini',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Waffenmodifikatoren',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
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
                      keyName: 'combat-weapon-form-ini-mod',
                      label: 'WM Ini',
                      controller: _iniModController,
                      onChanged: (parsed) {
                        _setDraftSlot(_draftSlot.copyWith(iniMod: parsed));
                      },
                    ),
                    _numberField(
                      keyName: 'combat-weapon-form-dice-count',
                      label: 'Wuerfel',
                      controller: _tpDiceCountController,
                      onChanged: (parsed) {
                        _setDraftSlot(
                          _draftSlot.copyWith(
                            tpDiceCount: parsed < 1 ? 1 : parsed,
                          ),
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
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'TP-Modifikatoren',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
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
                          _draftSlot.copyWith(
                            kkThreshold: parsed < 1 ? 1 : parsed,
                          ),
                        );
                      },
                    ),
                    _readOnlyField(
                      'TP/KK',
                      preview.tpKk.toString(),
                      keyName: 'combat-weapon-form-preview-tpkk',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'INI-Modifikatoren',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _readOnlyField(
                      'GE-Basis',
                      preview.geBase.toString(),
                      keyName: 'combat-weapon-form-preview-ge-base',
                    ),
                    _readOnlyField(
                      'GE-Schwelle',
                      preview.geThreshold.toString(),
                      keyName: 'combat-weapon-form-preview-ge-threshold',
                    ),
                    _readOnlyField(
                      'INI/GE',
                      preview.iniGe.toString(),
                      keyName: 'combat-weapon-form-preview-ini-ge',
                    ),
                    _readOnlyField(
                      'BE-Mod',
                      preview.beMod.toString(),
                      keyName: 'combat-weapon-form-preview-be-mod',
                    ),
                    _readOnlyField(
                      'eBE',
                      preview.ebe.toString(),
                      keyName: 'combat-weapon-form-preview-ebe',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Artefakt',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      key: const ValueKey<String>(
                        'combat-weapon-form-artifact',
                      ),
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
                          _draftSlot.copyWith(
                            artifactDescription: value.trim(),
                          ),
                        );
                      },
                    ),
                  ],
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
          key: const ValueKey<String>('combat-weapon-form-save'),
          onPressed: () {
            final normalizedWeaponType = _draftSlot.weaponType.trim();
            final normalizedTalentId =
                _isTalentValidForWeaponType(
                  talentId: _draftSlot.talentId,
                  weaponType: normalizedWeaponType,
                )
                ? _draftSlot.talentId.trim()
                : '';
            final normalized = _draftSlot.copyWith(
              name: _nameController.text.trim(),
              weaponType: normalizedWeaponType,
              talentId: normalizedTalentId,
              distanceClass: _distanceClassController.text.trim(),
              breakFactor: _readInt(
                _breakFactorController,
                _draftSlot.breakFactor,
              ).clamp(0, 9999).toInt(),
              kkBase: _readInt(_kkBaseController, _draftSlot.kkBase),
              kkThreshold:
                  _readInt(_kkThresholdController, _draftSlot.kkThreshold) < 1
                  ? 1
                  : _readInt(_kkThresholdController, _draftSlot.kkThreshold),
              iniMod: _readInt(_iniModController, _draftSlot.iniMod),
              wmAt: _readInt(_wmAtController, _draftSlot.wmAt),
              wmPa: _readInt(_wmPaController, _draftSlot.wmPa),
              tpDiceCount:
                  _readInt(_tpDiceCountController, _draftSlot.tpDiceCount) < 1
                  ? 1
                  : _readInt(_tpDiceCountController, _draftSlot.tpDiceCount),
              tpFlat: _readInt(_tpFlatController, _draftSlot.tpFlat),
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
