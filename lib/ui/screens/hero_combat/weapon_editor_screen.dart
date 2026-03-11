import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/validation/weapon_validation.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_basic_info_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_damage_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_editor_helpers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_modifiers_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_preview_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_ranged_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_navigation_guard.dart';

/// Vollwertiger Waffen-Editor, nutzbar als Screen oder Inline-Panel.
class WeaponEditorScreen extends ConsumerStatefulWidget {
  /// Erstellt den Waffen-Editor fuer neue oder bestehende Slots.
  const WeaponEditorScreen({
    super.key,
    required this.combatTalents,
    required this.effectiveAttributes,
    required this.catalogWeapons,
    required this.previewBuilder,
    this.isNew = false,
    this.initialWeapon,
    this.catalogWeaponName,
    this.onSaved,
    this.onCancel,
    this.showAppBar = true,
  });

  final MainWeaponSlot? initialWeapon;
  final bool isNew;
  final List<TalentDef> combatTalents;
  final Attributes effectiveAttributes;
  final List<WeaponDef> catalogWeapons;
  final CombatPreviewStats Function(MainWeaponSlot slot) previewBuilder;
  final String? catalogWeaponName;
  final ValueChanged<MainWeaponSlot>? onSaved;
  final VoidCallback? onCancel;
  final bool showAppBar;

  @override
  WeaponEditorScreenState createState() => WeaponEditorScreenState();
}

/// Oeffnet Save/Discard-Interaktionen auch fuer den umgebenden Panel-Host.
class WeaponEditorScreenState extends ConsumerState<WeaponEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _distanceClassController;
  late final TextEditingController _breakFactorController;
  late final TextEditingController _kkBaseController;
  late final TextEditingController _kkThresholdController;
  late final TextEditingController _iniModController;
  late final TextEditingController _wmAtController;
  late final TextEditingController _wmPaController;
  late final TextEditingController _beTalentModController;
  late final TextEditingController _tpDiceCountController;
  late final TextEditingController _tpFlatController;
  late final TextEditingController _artifactDescriptionController;
  late final TextEditingController _reloadTimeController;
  late final List<TextEditingController> _distanceLabelControllers;
  late final List<TextEditingController> _distanceTpModControllers;
  late MainWeaponSlot _draftWeapon;
  List<String> _validationErrors = const <String>[];
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _draftWeapon = normalizeWeaponEditorSlot(
      widget.initialWeapon ?? const MainWeaponSlot(),
    );
    _nameController = TextEditingController(text: _draftWeapon.name);
    _distanceClassController = TextEditingController(
      text: _draftWeapon.distanceClass,
    );
    _breakFactorController = TextEditingController(
      text: _draftWeapon.breakFactor.toString(),
    );
    _kkBaseController = TextEditingController(
      text: _draftWeapon.kkBase.toString(),
    );
    _kkThresholdController = TextEditingController(
      text: _draftWeapon.kkThreshold.toString(),
    );
    _iniModController = TextEditingController(
      text: _draftWeapon.iniMod.toString(),
    );
    _wmAtController = TextEditingController(text: _draftWeapon.wmAt.toString());
    _wmPaController = TextEditingController(text: _draftWeapon.wmPa.toString());
    _beTalentModController = TextEditingController(
      text: _draftWeapon.beTalentMod.toString(),
    );
    _tpDiceCountController = TextEditingController(
      text: _draftWeapon.tpDiceCount.toString(),
    );
    _tpFlatController = TextEditingController(
      text: _draftWeapon.tpFlat.toString(),
    );
    _artifactDescriptionController = TextEditingController(
      text: _draftWeapon.artifactDescription,
    );
    _reloadTimeController = TextEditingController(
      text: _draftWeapon.rangedProfile.reloadTime.toString(),
    );
    _distanceLabelControllers = _draftWeapon.rangedProfile.distanceBands
        .map((entry) => TextEditingController(text: entry.label))
        .toList(growable: false);
    _distanceTpModControllers = _draftWeapon.rangedProfile.distanceBands
        .map((entry) => TextEditingController(text: entry.tpMod.toString()))
        .toList(growable: false);
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
    _beTalentModController.dispose();
    _tpDiceCountController.dispose();
    _tpFlatController.dispose();
    _artifactDescriptionController.dispose();
    _reloadTimeController.dispose();
    for (final controller in _distanceLabelControllers) {
      controller.dispose();
    }
    for (final controller in _distanceTpModControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Fragt den Nutzer bei ungespeicherten Aenderungen vor dem Schliessen.
  Future<bool> requestClose() async {
    if (!_hasUnsavedChanges) {
      _closeWithoutSaving();
      return true;
    }

    final result = await showWorkspaceDiscardDialog(context);
    if (!mounted || result == AdaptiveConfirmResult.cancel) {
      return false;
    }
    if (result == AdaptiveConfirmResult.save) {
      return _save();
    }
    _closeWithoutSaving();
    return true;
  }

  int _readInt(TextEditingController controller, int fallback) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  RangedWeaponProfile _rangedProfileFromControllers() {
    final fallback = _draftWeapon.rangedProfile.copyWith().distanceBands;
    return _draftWeapon.rangedProfile.copyWith(
      reloadTime: _readInt(
        _reloadTimeController,
        _draftWeapon.rangedProfile.reloadTime,
      ),
      distanceBands: <RangedDistanceBand>[
        for (var i = 0; i < 5; i++)
          RangedDistanceBand(
            label: _distanceLabelControllers[i].text.trim().isEmpty
                ? fallback[i].label
                : _distanceLabelControllers[i].text.trim(),
            tpMod: _readInt(_distanceTpModControllers[i], fallback[i].tpMod),
          ),
      ],
    );
  }

  void _setDraftWeapon(MainWeaponSlot next) {
    setState(() {
      _draftWeapon = next;
      _hasUnsavedChanges = true;
      _validationErrors = const <String>[];
    });
  }

  Future<void> _openProjectileEditor({int? projectileIndex}) async {
    final projectiles = _draftWeapon.rangedProfile.projectiles;
    final source = projectileIndex == null
        ? const RangedProjectile()
        : projectiles[projectileIndex];
    final result = await showDialog<RangedProjectile>(
      context: context,
      builder: (context) => RangedProjectileEditorDialog(
        initialProjectile: source,
        isNew: projectileIndex == null,
      ),
    );
    if (result == null) {
      return;
    }
    final updated = List<RangedProjectile>.from(projectiles);
    if (projectileIndex == null) {
      updated.add(result);
    } else {
      updated[projectileIndex] = result;
    }
    _setDraftWeapon(
      _draftWeapon.copyWith(
        rangedProfile: _rangedProfileFromControllers().copyWith(
          projectiles: updated,
          selectedProjectileIndex: updated.isEmpty
              ? -1
              : (projectileIndex ?? updated.length - 1),
        ),
      ),
    );
  }

  void _removeProjectile(int index) {
    final updated = List<RangedProjectile>.from(
      _draftWeapon.rangedProfile.projectiles,
    );
    if (index < 0 || index >= updated.length) {
      return;
    }
    updated.removeAt(index);
    _setDraftWeapon(
      _draftWeapon.copyWith(
        rangedProfile: _rangedProfileFromControllers().copyWith(
          projectiles: updated,
          selectedProjectileIndex: updated.isEmpty ? -1 : 0,
        ),
      ),
    );
  }

  MainWeaponSlot _normalizedWeapon() {
    final weaponType = _draftWeapon.weaponType.trim();
    final normalizedTalentId =
        isTalentValidForWeaponType(
          talentId: _draftWeapon.talentId,
          weaponType: weaponType,
          draftWeapon: _draftWeapon,
          combatTalents: widget.combatTalents,
          catalogWeapons: widget.catalogWeapons,
        )
        ? _draftWeapon.talentId.trim()
        : '';
    return _draftWeapon.copyWith(
      name: _nameController.text.trim(),
      weaponType: weaponType,
      talentId: normalizedTalentId,
      distanceClass: _distanceClassController.text.trim(),
      breakFactor: _readInt(
        _breakFactorController,
        _draftWeapon.breakFactor,
      ).clamp(0, 9999),
      kkBase: _readInt(_kkBaseController, _draftWeapon.kkBase),
      kkThreshold:
          _readInt(_kkThresholdController, _draftWeapon.kkThreshold) < 1
          ? 1
          : _readInt(_kkThresholdController, _draftWeapon.kkThreshold),
      iniMod: _readInt(_iniModController, _draftWeapon.iniMod),
      wmAt: _readInt(_wmAtController, _draftWeapon.wmAt),
      wmPa: _readInt(_wmPaController, _draftWeapon.wmPa),
      beTalentMod: _readInt(_beTalentModController, _draftWeapon.beTalentMod),
      tpDiceCount:
          _readInt(_tpDiceCountController, _draftWeapon.tpDiceCount) < 1
          ? 1
          : _readInt(_tpDiceCountController, _draftWeapon.tpDiceCount),
      tpFlat: _readInt(_tpFlatController, _draftWeapon.tpFlat),
      artifactDescription: _artifactDescriptionController.text.trim(),
      rangedProfile: _rangedProfileFromControllers(),
    );
  }

  Future<bool> _save() async {
    final normalized = _normalizedWeapon();
    final errors = validateWeaponSlot(normalized);
    if (errors.isNotEmpty) {
      setState(() {
        _validationErrors = errors;
      });
      return false;
    }
    if (widget.onSaved != null) {
      widget.onSaved!(normalized);
    } else if (mounted) {
      Navigator.of(context).pop(normalized);
    }
    _hasUnsavedChanges = false;
    return true;
  }

  void _closeWithoutSaving() {
    if (widget.onCancel != null) {
      widget.onCancel!();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final weaponTypeOptions = weaponTypeOptionsForCatalogWeapons(
      widget.catalogWeapons,
      _draftWeapon,
    );
    final currentWeaponType = _draftWeapon.weaponType.trim();
    final talentOptions = talentOptionsForWeaponType(
      weaponType: currentWeaponType,
      draftWeapon: _draftWeapon,
      combatTalents: widget.combatTalents,
      catalogWeapons: widget.catalogWeapons,
    );
    final selectedTalentId =
        isTalentValidForWeaponType(
          talentId: _draftWeapon.talentId,
          weaponType: currentWeaponType,
          draftWeapon: _draftWeapon,
          combatTalents: widget.combatTalents,
          catalogWeapons: widget.catalogWeapons,
        )
        ? _draftWeapon.talentId.trim()
        : '';
    final previewWeapon = selectedTalentId == _draftWeapon.talentId.trim()
        ? _draftWeapon.copyWith(rangedProfile: _rangedProfileFromControllers())
        : _draftWeapon.copyWith(
            talentId: '',
            rangedProfile: _rangedProfileFromControllers(),
          );
    final preview = widget.previewBuilder(previewWeapon);
    final content = Column(
      children: [
        if (!widget.showAppBar) _header(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_validationErrors.isNotEmpty) _errorBox(context),
                WeaponBasicInfoSection(
                  nameController: _nameController,
                  artifactDescriptionController: _artifactDescriptionController,
                  distanceClassController: _distanceClassController,
                  combatType: _draftWeapon.combatType,
                  weaponType: currentWeaponType,
                  isOneHanded: _draftWeapon.isOneHanded,
                  isArtifact: _draftWeapon.isArtifact,
                  weaponTypeOptions: weaponTypeOptions,
                  talentOptions: talentOptions,
                  selectedTalentId: selectedTalentId,
                  onNameChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(name: value)),
                  onCombatTypeChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(
                      combatType: value,
                      talentId: '',
                      weaponType: '',
                    ),
                  ),
                  onWeaponTypeChanged: (value) {
                    final nextTalentId =
                        isTalentValidForWeaponType(
                          talentId: _draftWeapon.talentId,
                          weaponType: value,
                          draftWeapon: _draftWeapon,
                          combatTalents: widget.combatTalents,
                          catalogWeapons: widget.catalogWeapons,
                        )
                        ? _draftWeapon.talentId
                        : '';
                    final nextName =
                        _draftWeapon.name.trim().isEmpty && value.isNotEmpty
                        ? value
                        : _draftWeapon.name;
                    if (_draftWeapon.name.trim().isEmpty &&
                        nextName.isNotEmpty &&
                        _nameController.text.trim().isEmpty) {
                      _nameController.text = nextName;
                    }
                    _setDraftWeapon(
                      _draftWeapon.copyWith(
                        weaponType: value,
                        talentId: nextTalentId,
                        name: nextName,
                      ),
                    );
                  },
                  onDistanceClassChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(distanceClass: value),
                  ),
                  onTalentChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(talentId: value)),
                  onOneHandedChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(isOneHanded: value),
                  ),
                  onArtifactChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(isArtifact: value)),
                  onArtifactDescriptionChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(artifactDescription: value),
                  ),
                ),
                const SizedBox(height: 12),
                WeaponDamageSection(
                  tpDiceCountController: _tpDiceCountController,
                  tpFlatController: _tpFlatController,
                  kkBaseController: _kkBaseController,
                  kkThresholdController: _kkThresholdController,
                  onTpDiceCountChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(tpDiceCount: value < 1 ? 1 : value),
                  ),
                  onTpFlatChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(tpFlat: value)),
                  onKkBaseChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(kkBase: value)),
                  onKkThresholdChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(kkThreshold: value < 1 ? 1 : value),
                  ),
                ),
                const SizedBox(height: 12),
                WeaponModifiersSection(
                  combatType: _draftWeapon.combatType,
                  breakFactorController: _breakFactorController,
                  iniModController: _iniModController,
                  wmAtController: _wmAtController,
                  wmPaController: _wmPaController,
                  beTalentModController: _beTalentModController,
                  onBreakFactorChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(breakFactor: value < 0 ? 0 : value),
                  ),
                  onIniModChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(iniMod: value)),
                  onWmAtChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(wmAt: value)),
                  onWmPaChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(wmPa: value)),
                  onBeTalentModChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(beTalentMod: value),
                  ),
                ),
                if (_draftWeapon.isRanged) ...[
                  const SizedBox(height: 12),
                  WeaponRangedSection(
                    reloadTimeController: _reloadTimeController,
                    distanceLabelControllers: _distanceLabelControllers,
                    distanceTpModControllers: _distanceTpModControllers,
                    projectiles: _draftWeapon.rangedProfile.projectiles,
                    onReloadTimeChanged: (value) => _setDraftWeapon(
                      _draftWeapon.copyWith(
                        rangedProfile: _rangedProfileFromControllers().copyWith(
                          reloadTime: value < 0 ? 0 : value,
                        ),
                      ),
                    ),
                    onDistanceChanged: () => _setDraftWeapon(
                      _draftWeapon.copyWith(
                        rangedProfile: _rangedProfileFromControllers(),
                      ),
                    ),
                    onAddProjectile: _openProjectileEditor,
                    onEditProjectile: (index) =>
                        _openProjectileEditor(projectileIndex: index),
                    onRemoveProjectile: _removeProjectile,
                  ),
                ],
                const SizedBox(height: 12),
                WeaponPreviewSection(preview: preview),
              ],
            ),
          ),
        ),
        _actions(),
      ],
    );

    if (!widget.showAppBar) {
      return Material(child: content);
    }
    return PopScope<MainWeaponSlot>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? 'Waffe hinzufuegen' : 'Waffe bearbeiten'),
        ),
        body: content,
      ),
    );
  }

  Widget _header(BuildContext context) {
    final title = widget.isNew ? 'Waffe hinzufuegen' : 'Waffe bearbeiten';
    final template = widget.catalogWeaponName?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (template.isNotEmpty)
                  Text(
                    'Vorlage: $template',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey<String>('combat-weapon-panel-close'),
            onPressed: () {
              requestClose();
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                requestClose();
              },
              child: const Text('Abbrechen'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey<String>('combat-weapon-form-save'),
              onPressed: _save,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _validationErrors
            .map(
              (error) =>
                  Text(error, style: Theme.of(context).textTheme.bodyMedium),
            )
            .toList(growable: false),
      ),
    );
  }
}
