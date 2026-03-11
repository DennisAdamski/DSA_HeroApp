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
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_projectile_editor_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_preview_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_ranged_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_navigation_guard.dart';

part 'weapon_editor/weapon_editor_state_helpers.dart';
part 'weapon_editor/weapon_editor_content.dart';

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
    _draftWeapon = _normalizedInitialWeapon();
    _nameController = TextEditingController();
    _distanceClassController = TextEditingController();
    _breakFactorController = TextEditingController();
    _kkBaseController = TextEditingController();
    _kkThresholdController = TextEditingController();
    _iniModController = TextEditingController();
    _wmAtController = TextEditingController();
    _wmPaController = TextEditingController();
    _beTalentModController = TextEditingController();
    _tpDiceCountController = TextEditingController();
    _tpFlatController = TextEditingController();
    _artifactDescriptionController = TextEditingController();
    _reloadTimeController = TextEditingController();
    _distanceLabelControllers = List<TextEditingController>.generate(
      5,
      (_) => TextEditingController(),
      growable: false,
    );
    _distanceTpModControllers = List<TextEditingController>.generate(
      5,
      (_) => TextEditingController(),
      growable: false,
    );
    _syncControllersFromDraft();
  }

  @override
  void didUpdateWidget(covariant WeaponEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextInitialWeapon = _normalizedInitialWeapon();
    final oldInitialWeapon = normalizeWeaponEditorSlot(
      oldWidget.initialWeapon ?? const MainWeaponSlot(),
    );
    final sourceChanged =
        widget.isNew != oldWidget.isNew ||
        widget.catalogWeaponName != oldWidget.catalogWeaponName ||
        nextInitialWeapon != oldInitialWeapon;
    if (!sourceChanged) {
      return;
    }
    _draftWeapon = nextInitialWeapon;
    _validationErrors = const <String>[];
    _hasUnsavedChanges = false;
    _syncControllersFromDraft();
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

  void _setDraftWeapon(MainWeaponSlot next) {
    setState(() {
      _draftWeapon = next;
      _hasUnsavedChanges = true;
      _validationErrors = const <String>[];
    });
  }

  void _setValidationErrors(List<String> errors) {
    setState(() {
      _validationErrors = errors;
    });
  }

  Future<bool> requestClose() => _requestClose();

  MainWeaponSlot _normalizedInitialWeapon() {
    return normalizeWeaponEditorSlot(
      widget.initialWeapon ?? const MainWeaponSlot(),
    );
  }

  void _syncControllersFromDraft() {
    _nameController.text = _draftWeapon.name;
    _distanceClassController.text = _draftWeapon.distanceClass;
    _breakFactorController.text = _draftWeapon.breakFactor.toString();
    _kkBaseController.text = _draftWeapon.kkBase.toString();
    _kkThresholdController.text = _draftWeapon.kkThreshold.toString();
    _iniModController.text = _draftWeapon.iniMod.toString();
    _wmAtController.text = _draftWeapon.wmAt.toString();
    _wmPaController.text = _draftWeapon.wmPa.toString();
    _beTalentModController.text = _draftWeapon.beTalentMod.toString();
    _tpDiceCountController.text = _draftWeapon.tpDiceCount.toString();
    _tpFlatController.text = _draftWeapon.tpFlat.toString();
    _artifactDescriptionController.text = _draftWeapon.artifactDescription;
    _reloadTimeController.text = _draftWeapon.rangedProfile.reloadTime
        .toString();
    final distanceBands = _draftWeapon.rangedProfile.distanceBands;
    for (var i = 0; i < _distanceLabelControllers.length; i++) {
      _distanceLabelControllers[i].text = distanceBands[i].label;
      _distanceTpModControllers[i].text = distanceBands[i].tpMod.toString();
    }
  }

  @override
  Widget build(BuildContext context) => _buildScreen(context);
}
