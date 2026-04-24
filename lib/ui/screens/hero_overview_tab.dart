import 'dart:io' as io;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_se_pools.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';

import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_main_attribute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_source_breakdown.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_feature_flags.dart';
import 'package:dsa_heldenverwaltung/ui/debug/ui_rebuild_observer.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_request_factory.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/edit_aware_field.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/attribute_modifier_detail_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/stat_modifier_detail_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/edit_aware_table_cell.dart';
import 'package:file_picker/file_picker.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/avatar_generation_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/steigerungs_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/epic_activation_dialog.dart';

part 'hero_overview/hero_avatar_section.dart';
part 'hero_overview/hero_overview_base_info_section.dart';
part 'hero_overview/hero_overview_ap_resources_section.dart';
part 'hero_overview/hero_overview_stats_section.dart';
part 'hero_overview/hero_overview_form_fields.dart';
part 'hero_overview/hero_overview_raise_actions.dart';
part 'hero_overview/hero_overview_epic_section.dart';

const double _pagePadding = 16;
const double _sectionSpacing = 16;
const double _gridSpacing = 12;
const double _standardTwoColumnBreakpoint = 560;
const double _largeTwoColumnBreakpoint = 760;

class HeroOverviewTab extends ConsumerStatefulWidget {
  const HeroOverviewTab({
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
  ConsumerState<HeroOverviewTab> createState() => _HeroOverviewTabState();
}

class _HeroOverviewTabState extends ConsumerState<HeroOverviewTab>
    with AutomaticKeepAliveClientMixin {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final ValueNotifier<int> _viewRevision = ValueNotifier<int>(0);

  static const List<(String, String)> _attributeEntries = [
    ('Mut', 'mu'),
    ('Klugheit', 'kl'),
    ('Intuition', 'inn'),
    ('Charisma', 'ch'),
    ('Fingerfertigkeit', 'ff'),
    ('Gewandtheit', 'ge'),
    ('Konstitution', 'ko'),
    ('Körperkraft', 'kk'),
  ];

  late final WorkspaceTabEditController _editController;
  HeroSheet? _latestHero;
  HeroState? _latestState;
  HeroComputedSnapshot? _latestSnapshot;
  bool? _draftMagicEnabledOverride;
  bool? _draftDivineEnabledOverride;

  @override
  void initState() {
    super.initState();
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
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _viewRevision.dispose();
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

  TextEditingController _field(String key) {
    return _controllers.putIfAbsent(key, () => TextEditingController());
  }

  void _syncControllers(HeroSheet hero, HeroState state, {bool force = false}) {
    if (!_editController.shouldSync((hero, state), force: force)) {
      return;
    }

    _field('name').text = hero.name;
    _field('rasse').text = hero.background.rasse;
    _field('rasse_mod').text = hero.background.rasseModText;
    _field('kultur').text = hero.background.kultur;
    _field('kultur_mod').text = hero.background.kulturModText;
    _field('profession').text = hero.background.profession;
    _field('profession_mod').text = hero.background.professionModText;
    _field('geschlecht').text = hero.appearance.geschlecht;
    _field('alter').text = hero.appearance.alter;
    _field('groesse').text = hero.appearance.groesse;
    _field('gewicht').text = hero.appearance.gewicht;
    _field('haarfarbe').text = hero.appearance.haarfarbe;
    _field('augenfarbe').text = hero.appearance.augenfarbe;
    _field('aussehen').text = hero.appearance.aussehen;
    _field('stand').text = hero.background.stand;
    _field('titel').text = hero.background.titel;
    _field('familie').text = hero.background.familieHerkunftHintergrund;
    _field('sozialstatus').text = hero.background.sozialstatus.toString();
    _field('vorteile').text = hero.vorteileText;
    _field('nachteile').text = hero.nachteileText;
    _field('ap_total').text = hero.apTotal.toString();
    _field('ap_spent').text = hero.apSpent.toString();
    _field('ap_total_add').clear();
    _field('ap_spent_add').clear();
    _field('b_lep').text = hero.bought.lep.toString();
    _field('b_au').text = hero.bought.au.toString();
    _field('b_asp').text = hero.bought.asp.toString();
    _field('b_kap').text = hero.bought.kap.toString();
    _field('b_mr').text = hero.bought.mr.toString();

    _field('cur_lep').text = state.currentLep.toString();
    _field('cur_au').text = state.currentAu.toString();
    _field('cur_asp').text = state.currentAsp.toString();
    _field('cur_kap').text = state.currentKap.toString();
    _draftMagicEnabledOverride =
        hero.resourceActivationConfig.magicEnabledOverride;
    _draftDivineEnabledOverride =
        hero.resourceActivationConfig.divineEnabledOverride;

    _field('mu').text = hero.attributes.mu.toString();
    _field('kl').text = hero.attributes.kl.toString();
    _field('inn').text = hero.attributes.inn.toString();
    _field('ch').text = hero.attributes.ch.toString();
    _field('ff').text = hero.attributes.ff.toString();
    _field('ge').text = hero.attributes.ge.toString();
    _field('ko').text = hero.attributes.ko.toString();
    _field('kk').text = hero.attributes.kk.toString();

    _field('mu_start').text = hero.startAttributes.mu.toString();
    _field('kl_start').text = hero.startAttributes.kl.toString();
    _field('inn_start').text = hero.startAttributes.inn.toString();
    _field('ch_start').text = hero.startAttributes.ch.toString();
    _field('ff_start').text = hero.startAttributes.ff.toString();
    _field('ge_start').text = hero.startAttributes.ge.toString();
    _field('ko_start').text = hero.startAttributes.ko.toString();
    _field('kk_start').text = hero.startAttributes.kk.toString();
  }

  int _readInt(String key, {required int min, int max = 999999}) {
    final parsed = int.tryParse(_field(key).text.trim()) ?? 0;
    if (parsed < min) {
      return min;
    }
    if (parsed > max) {
      return max;
    }
    return parsed;
  }

  void _setFieldText(String key, String value) {
    final controller = _field(key);
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _startEdit() async {
    _editController.startEdit();
  }

  Future<void> _saveChanges() async {
    final hero = _latestHero;
    final state = _latestState;
    if (hero == null || state == null) {
      return;
    }

    final updatedHero = hero.copyWith(
      name: _field('name').text.trim().isEmpty
          ? 'Unbenannter Held'
          : _field('name').text.trim(),
      appearance: hero.appearance.copyWith(
        geschlecht: _field('geschlecht').text.trim(),
        alter: _field('alter').text.trim(),
        groesse: _field('groesse').text.trim(),
        gewicht: _field('gewicht').text.trim(),
        haarfarbe: _field('haarfarbe').text.trim(),
        augenfarbe: _field('augenfarbe').text.trim(),
        aussehen: _field('aussehen').text.trim(),
      ),
      background: hero.background.copyWith(
        rasse: _field('rasse').text.trim(),
        rasseModText: _field('rasse_mod').text.trim(),
        kultur: _field('kultur').text.trim(),
        kulturModText: _field('kultur_mod').text.trim(),
        profession: _field('profession').text.trim(),
        professionModText: _field('profession_mod').text.trim(),
        stand: _field('stand').text.trim(),
        titel: _field('titel').text.trim(),
        familieHerkunftHintergrund: _field('familie').text.trim(),
        sozialstatus: _readInt('sozialstatus', min: 0, max: 999),
      ),
      vorteileText: _field('vorteile').text.trim(),
      nachteileText: _field('nachteile').text.trim(),
      apTotal: _readInt('ap_total', min: 0),
      apSpent: _readInt('ap_spent', min: 0),
      resourceActivationConfig: HeroResourceActivationConfig(
        magicEnabledOverride: _draftMagicEnabledOverride,
        divineEnabledOverride: _draftDivineEnabledOverride,
      ),
      bought: BoughtStats(
        lep: _readInt('b_lep', min: 0, max: 999),
        au: _readInt('b_au', min: 0, max: 999),
        asp: _readInt('b_asp', min: 0, max: 999),
        kap: _readInt('b_kap', min: 0, max: 999),
        mr: _readInt('b_mr', min: 0, max: 999),
      ),
      attributes: Attributes(
        mu: _readInt('mu', min: 0, max: 99),
        kl: _readInt('kl', min: 0, max: 99),
        inn: _readInt('inn', min: 0, max: 99),
        ch: _readInt('ch', min: 0, max: 99),
        ff: _readInt('ff', min: 0, max: 99),
        ge: _readInt('ge', min: 0, max: 99),
        ko: _readInt('ko', min: 0, max: 99),
        kk: _readInt('kk', min: 0, max: 99),
      ),
    );
    final updatedState = state.copyWith(
      currentLep: _readInt('cur_lep', min: 0, max: 99999),
      currentAu: _readInt('cur_au', min: 0, max: 99999),
      currentAsp: _readInt('cur_asp', min: 0, max: 99999),
      currentKap: _readInt('cur_kap', min: 0, max: 99999),
    );

    await ref.read(heroActionsProvider).saveHero(updatedHero);
    await ref
        .read(heroActionsProvider)
        .saveHeroState(updatedHero.id, updatedState);
    if (!mounted) {
      return;
    }

    _editController.markSaved();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Status gespeichert')));
  }

  Future<void> _cancelChanges() async {
    await _discardChanges();
  }

  Future<void> _discardChanges() async {
    final hero = _latestHero;
    final state = _latestState;
    if (hero != null && state != null) {
      _editController.clearSyncSignature();
      _syncControllers(hero, state, force: true);
    }
    _editController.markDiscarded();
  }

  void _onFieldChanged(String _) {
    _editController.markFieldChanged();
    if (mounted) {
      _viewRevision.value++;
    }
  }

  HeroResourceActivation _buildCurrentResourceActivation(HeroSheet hero) {
    return _buildResourceActivationForOverrides(
      hero,
      magicEnabledOverride: _draftMagicEnabledOverride,
      divineEnabledOverride: _draftDivineEnabledOverride,
    );
  }

  /// Berechnet die Ressourcen-Aktivierung fuer den aktuellen Bearbeitungsstand.
  HeroResourceActivation _buildResourceActivationForOverrides(
    HeroSheet hero, {
    required bool? magicEnabledOverride,
    required bool? divineEnabledOverride,
  }) {
    if (!_editController.isEditing) {
      return computeHeroResourceActivation(
        hero.copyWith(
          resourceActivationConfig: HeroResourceActivationConfig(
            magicEnabledOverride: magicEnabledOverride,
            divineEnabledOverride: divineEnabledOverride,
          ),
        ),
      );
    }
    final draftHero = hero.copyWith(
      background: hero.background.copyWith(
        rasseModText: _field('rasse_mod').text.trim(),
        kulturModText: _field('kultur_mod').text.trim(),
        professionModText: _field('profession_mod').text.trim(),
      ),
      vorteileText: _field('vorteile').text.trim(),
      resourceActivationConfig: HeroResourceActivationConfig(
        magicEnabledOverride: magicEnabledOverride,
        divineEnabledOverride: divineEnabledOverride,
      ),
    );
    return computeHeroResourceActivation(draftHero);
  }

  /// Uebernimmt Ressourcen-Overrides in den Draft des Overview-Tabs.
  void _applyDraftResourceActivationOverrides({
    required bool? magicEnabledOverride,
    required bool? divineEnabledOverride,
  }) {
    final hasChanged =
        _draftMagicEnabledOverride != magicEnabledOverride ||
        _draftDivineEnabledOverride != divineEnabledOverride;
    _draftMagicEnabledOverride = magicEnabledOverride;
    _draftDivineEnabledOverride = divineEnabledOverride;
    if (hasChanged) {
      _onFieldChanged('');
    }
  }

  /// Speichert Ressourcen-Overrides direkt am Helden ausserhalb des Edit-Modus.
  Future<void> _saveResourceActivationOverrides(
    HeroSheet hero, {
    required bool? magicEnabledOverride,
    required bool? divineEnabledOverride,
  }) async {
    final updatedHero = hero.copyWith(
      resourceActivationConfig: HeroResourceActivationConfig(
        magicEnabledOverride: magicEnabledOverride,
        divineEnabledOverride: divineEnabledOverride,
      ),
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }
    _latestHero = updatedHero;
    _draftMagicEnabledOverride = magicEnabledOverride;
    _draftDivineEnabledOverride = divineEnabledOverride;
    _viewRevision.value++;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ressourcen-Einstellungen gespeichert')),
    );
  }

  Future<void> _applyApIncrement({
    required String targetKey,
    required String label,
    required int increment,
  }) async {
    final updatedValue = _readInt(targetKey, min: 0) + increment;
    _field(targetKey)
      ..text = updatedValue.toString()
      ..selection = TextSelection.collapsed(
        offset: updatedValue.toString().length,
      );
    if (!_editController.isEditing) {
      final hero = _latestHero;
      if (hero == null) {
        return;
      }
      final updatedHero = switch (targetKey) {
        'ap_total' => hero.copyWith(apTotal: updatedValue),
        'ap_spent' => hero.copyWith(apSpent: updatedValue),
        _ => hero,
      };
      await ref.read(heroActionsProvider).saveHero(updatedHero);
      if (!mounted) {
        return;
      }
      _latestHero = updatedHero;
      _viewRevision.value++;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label aktualisiert')));
      return;
    }
    _onFieldChanged(updatedValue.toString());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    UiRebuildObserver.bump('hero_overview_tab');
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final computedAsync = ref.watch(heroComputedProvider(widget.heroId));

    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    return computedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
      data: (snapshot) {
        final state = snapshot.state;
        _latestHero = hero;
        _latestState = state;
        _latestSnapshot = snapshot;
        _syncControllers(hero, state);
        final resourceActivation = _buildCurrentResourceActivation(hero);
        return ValueListenableBuilder<int>(
          valueListenable: _viewRevision,
          builder: (context, revision, child) {
            return ListView(
              key: const ValueKey<String>('hero-overview-scroll'),
              padding: const EdgeInsets.all(_pagePadding),
              children: [
                if (hero.appearance.avatarFileName.isEmpty) ...[
                  _NoAvatarActions(heroId: hero.id, hero: hero),
                  const SizedBox(height: _sectionSpacing),
                ],
                _buildBaseInfoSection(hero),
                const SizedBox(height: _sectionSpacing),
                _buildAdvantagesSection(),
                const SizedBox(height: _sectionSpacing),
                _buildApSection(hero),
                if (hero.isEpisch) ...[
                  const SizedBox(height: _sectionSpacing),
                  _buildEpicSection(hero),
                ],
                if (kShowParserWarnings &&
                    hero.unknownModifierFragments.isNotEmpty) ...[
                  const SizedBox(height: _sectionSpacing),
                  _buildParserWarningsSection(hero),
                ],
                const SizedBox(height: _sectionSpacing),
                _buildCombinedStatsAndAttributesSection(
                  snapshot,
                  resourceActivation,
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _DerivedRow {
  const _DerivedRow({
    required this.label,
    required this.variableName,
    required this.statKey,
    required this.current,
    required this.modifier,
    this.bought,
    this.boughtKey,
  });

  final String label;
  final String variableName;

  /// Schluessel fuer benannte Modifikatoren (z.B. 'lep', 'au', 'iniBase').
  final String statKey;
  final int current;
  final int modifier;
  final int? bought;
  final String? boughtKey;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.titleAction,
  });

  final String title;
  final Widget child;
  final Widget? titleAction;

  @override
  Widget build(BuildContext context) {
    return CodexSectionCard(title: title, trailing: titleAction, child: child);
  }
}

class _ResponsiveFieldGrid extends StatelessWidget {
  const _ResponsiveFieldGrid({
    required this.children,
    required this.breakpoint,
  });

  final List<Widget> children;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= breakpoint ? 2 : 1;
        final totalSpacing = (columns - 1) * _gridSpacing;
        final itemWidth = (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: _gridSpacing,
          runSpacing: _gridSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}
