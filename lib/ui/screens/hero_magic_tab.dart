import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_text_overrides.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ritual_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:uuid/uuid.dart';

part 'hero_magic/magic_active_spells_table.dart';
part 'hero_magic/magic_header_section.dart';
part 'hero_magic/magic_ritual_category_dialog.dart';
part 'hero_magic/magic_ritual_entry_dialog.dart';
part 'hero_magic/magic_rituals_section.dart';
part 'hero_magic/magic_special_abilities_section.dart';
part 'hero_magic/magic_spell_catalog_table.dart';
part 'hero_magic/magic_spell_details_dialog.dart';

/// Magie-Tab mit Sub-Tabs fuer Zauber, Rituale und Magie-Stammdaten.
class HeroMagicTab extends ConsumerStatefulWidget {
  /// Erzeugt den Magie-Tab fuer einen einzelnen Helden.
  const HeroMagicTab({
    super.key,
    required this.heroId,
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  final String heroId;
  final void Function(bool isDirty) onDirtyChanged;
  final void Function(bool isEditing) onEditingChanged;
  final void Function(WorkspaceAsyncAction discardAction) onRegisterDiscard;
  final void Function(WorkspaceTabEditActions actions) onRegisterEditActions;

  @override
  ConsumerState<HeroMagicTab> createState() => _HeroMagicTabState();
}

class _HeroMagicTabState extends ConsumerState<HeroMagicTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final WorkspaceTabEditController _editController;
  late final TabController _innerTabController;
  final ValueNotifier<int> _tableRevision = ValueNotifier<int>(0);
  final Map<String, TextEditingController> _cellControllers =
      <String, TextEditingController>{};

  HeroSheet? _latestHero;

  // Draft-Zustand wird nur im Edit-Modus veraendert.
  Map<String, HeroSpellEntry> _draftSpells = <String, HeroSpellEntry>{};
  List<HeroRitualCategory> _draftRitualCategories = <HeroRitualCategory>[];
  List<String> _draftRepresentationen = <String>[];
  List<String> _draftMerkmalskenntnisse = <String>[];
  List<MagicSpecialAbility> _draftMagicSpecialAbilities =
      <MagicSpecialAbility>[];

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(length: 3, vsync: this);
    _editController = WorkspaceTabEditController(
      onDirtyChanged: widget.onDirtyChanged,
      onEditingChanged: widget.onEditingChanged,
      requestRebuild: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _registerWithParent();
      }
    });
  }

  @override
  void dispose() {
    _innerTabController.dispose();
    for (final controller in _cellControllers.values) {
      controller.dispose();
    }
    _tableRevision.dispose();
    super.dispose();
  }

  void _registerWithParent() {
    _editController.emitCurrentState();
    widget.onRegisterDiscard(_discardChanges);
    widget.onRegisterEditActions(
      WorkspaceTabEditActions(
        startEdit: _startEdit,
        save: _saveChanges,
        cancel: _cancelChanges,
      ),
    );
  }

  void _syncDraftFromHero(HeroSheet hero, {bool force = false}) {
    if (!_editController.shouldSync(hero, force: force)) {
      return;
    }
    _resetCellControllers();
    _draftSpells = Map<String, HeroSpellEntry>.from(hero.spells);
    _draftRitualCategories = List<HeroRitualCategory>.from(
      hero.ritualCategories,
    );
    _draftRepresentationen = List<String>.from(hero.representationen);
    _draftMerkmalskenntnisse = List<String>.from(hero.merkmalskenntnisse);
    _draftMagicSpecialAbilities = List<MagicSpecialAbility>.from(
      hero.magicSpecialAbilities,
    );
  }

  void _resetCellControllers() {
    for (final controller in _cellControllers.values) {
      controller.dispose();
    }
    _cellControllers.clear();
  }

  TextEditingController _controllerFor(
    String spellId,
    String field,
    String initialValue,
  ) {
    final key = '$spellId::$field';
    return _cellControllers.putIfAbsent(
      key,
      () => TextEditingController(text: initialValue),
    );
  }

  Future<void> _startEdit() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    _editController.clearSyncSignature();
    _syncDraftFromHero(hero, force: true);
    _editController.startEdit();
  }

  Future<void> _saveChanges() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    final updatedHero = hero.copyWith(
      spells: Map<String, HeroSpellEntry>.from(_draftSpells),
      ritualCategories: List<HeroRitualCategory>.from(_draftRitualCategories),
      representationen: List<String>.from(_draftRepresentationen),
      merkmalskenntnisse: List<String>.from(_draftMerkmalskenntnisse),
      magicSpecialAbilities: List<MagicSpecialAbility>.from(
        _draftMagicSpecialAbilities,
      ),
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }
    _editController.markSaved();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Magie gespeichert')));
  }

  Future<void> _cancelChanges() async {
    await _discardChanges();
  }

  Future<void> _discardChanges() async {
    final hero = _latestHero;
    if (hero != null) {
      _editController.clearSyncSignature();
      _syncDraftFromHero(hero, force: true);
    }
    _editController.markDiscarded();
  }

  void _markFieldChanged() {
    if (!mounted) {
      return;
    }
    _tableRevision.value++;
    _editController.markFieldChanged();
  }

  void _updateSpellValue(String spellId, String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    final current = _draftSpells[spellId] ?? const HeroSpellEntry();
    _draftSpells[spellId] = current.copyWith(spellValue: parsed);
    _markFieldChanged();
  }

  void _updateSpellModifier(String spellId, String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    final current = _draftSpells[spellId] ?? const HeroSpellEntry();
    _draftSpells[spellId] = current.copyWith(modifier: parsed);
    _markFieldChanged();
  }

  void _updateHauszauber(String spellId, bool value) {
    final current = _draftSpells[spellId] ?? const HeroSpellEntry();
    _draftSpells[spellId] = current.copyWith(hauszauber: value);
    _markFieldChanged();
  }

  void _updateSpellGifted(String spellId, bool value) {
    final current = _draftSpells[spellId] ?? const HeroSpellEntry();
    _draftSpells[spellId] = current.copyWith(gifted: value);
    _markFieldChanged();
  }

  void _updateSpellTextOverrides(
    String spellId,
    HeroSpellTextOverrides? value,
  ) {
    final current = _draftSpells[spellId] ?? const HeroSpellEntry();
    _draftSpells[spellId] = current.copyWith(textOverrides: value);
    _markFieldChanged();
  }

  void _toggleSpell(String spellId, bool activate) {
    if (activate) {
      _draftSpells.putIfAbsent(spellId, () => const HeroSpellEntry());
    } else {
      _draftSpells.remove(spellId);
      _cellControllers.remove('$spellId::spellValue')?.dispose();
      _cellControllers.remove('$spellId::modifier')?.dispose();
    }
    _markFieldChanged();
  }

  void _removeSpell(String spellId) {
    _toggleSpell(spellId, false);
  }

  void _updateRepresentationen(List<String> values) {
    _draftRepresentationen = values;
    _markFieldChanged();
  }

  void _updateRitualCategories(List<HeroRitualCategory> values) {
    _draftRitualCategories = values;
    _markFieldChanged();
  }

  void _updateMerkmalskenntnisse(List<String> values) {
    _draftMerkmalskenntnisse = values;
    _markFieldChanged();
  }

  void _updateMagicSpecialAbilities(List<MagicSpecialAbility> values) {
    _draftMagicSpecialAbilities = values;
    _markFieldChanged();
  }

  void _showZauberKatalog(BuildContext context, List<SpellDef> allSpells) {
    final localActiveIds = _draftSpells.keys.toSet();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final screenHeight = MediaQuery.of(ctx).size.height;
            return SizedBox(
              height: screenHeight * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _MagicSpellCatalogTable(
                      allSpells: allSpells,
                      activeSpellIds: localActiveIds,
                      heroRepresentationen: _draftRepresentationen,
                      onToggleSpell: (id, activate) {
                        _toggleSpell(id, activate);
                        setSheetState(() {
                          if (activate) {
                            localActiveIds.add(id);
                          } else {
                            localActiveIds.remove(id);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    _latestHero = hero;
    _syncDraftFromHero(hero);

    final catalogAsync = ref.watch(rulesCatalogProvider);

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Katalog-Fehler: $error')),
      data: (catalog) {
        final spellDefsById = <String, SpellDef>{};
        for (final spell in catalog.spells) {
          spellDefsById[spell.id] = spell;
        }

        return Column(
          children: [
            TabBar(
              controller: _innerTabController,
              tabs: const [
                Tab(text: 'Zauber'),
                Tab(text: 'Rituale'),
                Tab(text: 'Repr. & SF'),
              ],
            ),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _tableRevision,
                builder: (context, revision, child) {
                  final activeSpellIds = _draftSpells.keys.toList(
                    growable: false,
                  );
                  return TabBarView(
                    controller: _innerTabController,
                    children: [
                      ListView(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                key: const ValueKey<String>(
                                  'magic-active-spells-open',
                                ),
                                onPressed: () {
                                  showActiveSpellEffectsDialog(
                                    context: context,
                                    heroId: widget.heroId,
                                  );
                                },
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: const Text('Zauber aktivieren'),
                              ),
                            ),
                          ),
                          _MagicActiveSpellsTable(
                            activeSpellIds: activeSpellIds,
                            spellEntries: _draftSpells,
                            spellDefs: spellDefsById,
                            merkmalskenntnisse: _draftMerkmalskenntnisse,
                            isEditing: _editController.isEditing,
                            onSpellValueChanged: _updateSpellValue,
                            onModifierChanged: _updateSpellModifier,
                            onHauszauberChanged: _updateHauszauber,
                            onGiftedChanged: _updateSpellGifted,
                            onTextOverridesChanged: _updateSpellTextOverrides,
                            onRemoveSpell: _removeSpell,
                            controllerFor: _controllerFor,
                            onAddSpell: _editController.isEditing
                                ? () => _showZauberKatalog(
                                    context,
                                    catalog.spells,
                                  )
                                : null,
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                        children: [
                          _MagicRitualsSection(
                            ritualCategories: _draftRitualCategories,
                            catalogTalents: catalog.talents,
                            heroTalents: hero.talents,
                            isEditing: _editController.isEditing,
                            onChanged: _updateRitualCategories,
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                        children: [
                          _MagicHeaderSection(
                            representationen: _draftRepresentationen,
                            merkmalskenntnisse: _draftMerkmalskenntnisse,
                            isEditing: _editController.isEditing,
                            onRepresentationenChanged: _updateRepresentationen,
                            onMerkmalskenntnisseChanged:
                                _updateMerkmalskenntnisse,
                          ),
                          _MagicSpecialAbilitiesSection(
                            abilities: _draftMagicSpecialAbilities,
                            isEditing: _editController.isEditing,
                            onChanged: _updateMagicSpecialAbilities,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
