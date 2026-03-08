import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_feature_flags.dart';
import 'package:dsa_heldenverwaltung/ui/debug/ui_rebuild_observer.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

part 'hero_overview/hero_overview_base_info_section.dart';
part 'hero_overview/hero_overview_ap_resources_section.dart';
part 'hero_overview/hero_overview_stats_section.dart';
part 'hero_overview/hero_overview_form_fields.dart';

const double _pagePadding = 16;
const double _sectionSpacing = 16;
const double _fieldSpacing = 12;
const double _gridSpacing = 12;
const double _standardTwoColumnBreakpoint = 700;
const double _largeTwoColumnBreakpoint = 900;
const double _attributeValueCellWidth = 86;

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
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};
  final ValueNotifier<int> _viewRevision = ValueNotifier<int>(0);

  static const List<(String, String)> _attributeEntries = [
    ('Mut', 'mu'),
    ('Klugheit', 'kl'),
    ('Intuition', 'inn'),
    ('Charisma', 'ch'),
    ('Fingerfertigkeit', 'ff'),
    ('Gewandtheit', 'ge'),
    ('Konstitution', 'ko'),
    ('Koerperkraft', 'kk'),
  ];

  late final WorkspaceTabEditController _editController;
  HeroSheet? _latestHero;
  HeroState? _latestState;

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
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
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

  FocusNode _focusNode(String key) {
    return _focusNodes.putIfAbsent(key, () {
      final focusNode = FocusNode();
      if (_isTempAttributeKey(key)) {
        focusNode.addListener(() {
          if (!focusNode.hasFocus) {
            _commitTempAttributeField(key);
          }
        });
      }
      return focusNode;
    });
  }

  void _syncControllers(HeroSheet hero, HeroState state, {bool force = false}) {
    if (!_editController.shouldSync((hero, state), force: force)) {
      return;
    }

    _field('name').text = hero.name;
    _field('rasse').text = hero.rasse;
    _field('rasse_mod').text = hero.rasseModText;
    _field('kultur').text = hero.kultur;
    _field('kultur_mod').text = hero.kulturModText;
    _field('profession').text = hero.profession;
    _field('profession_mod').text = hero.professionModText;
    _field('geschlecht').text = hero.geschlecht;
    _field('alter').text = hero.alter;
    _field('groesse').text = hero.groesse;
    _field('gewicht').text = hero.gewicht;
    _field('haarfarbe').text = hero.haarfarbe;
    _field('augenfarbe').text = hero.augenfarbe;
    _field('aussehen').text = hero.aussehen;
    _field('stand').text = hero.stand;
    _field('titel').text = hero.titel;
    _field('familie').text = hero.familieHerkunftHintergrund;
    _field('sozialstatus').text = hero.sozialstatus.toString();
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

    _field('m_lep').text = hero.persistentMods.lep.toString();
    _field('m_au').text = hero.persistentMods.au.toString();
    _field('m_asp').text = hero.persistentMods.asp.toString();
    _field('m_kap').text = hero.persistentMods.kap.toString();
    _field('m_mr').text = hero.persistentMods.mr.toString();
    _field('m_ini').text = hero.persistentMods.iniBase.toString();
    _field('m_gs').text = hero.persistentMods.gs.toString();
    _field('m_ausw').text = hero.persistentMods.ausweichen.toString();

    _field('cur_lep').text = state.currentLep.toString();
    _field('cur_au').text = state.currentAu.toString();
    _field('cur_asp').text = state.currentAsp.toString();
    _field('cur_kap').text = state.currentKap.toString();

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

    _field('mu_temp').text = state.tempAttributeMods.mu.toString();
    _field('kl_temp').text = state.tempAttributeMods.kl.toString();
    _field('inn_temp').text = state.tempAttributeMods.inn.toString();
    _field('ch_temp').text = state.tempAttributeMods.ch.toString();
    _field('ff_temp').text = state.tempAttributeMods.ff.toString();
    _field('ge_temp').text = state.tempAttributeMods.ge.toString();
    _field('ko_temp').text = state.tempAttributeMods.ko.toString();
    _field('kk_temp').text = state.tempAttributeMods.kk.toString();
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

  bool _isTempAttributeKey(String key) {
    return switch (key) {
      'mu_temp' || 'kl_temp' || 'inn_temp' || 'ch_temp' || 'ff_temp' ||
      'ge_temp' || 'ko_temp' || 'kk_temp' => true,
      _ => false,
    };
  }

  int _normalizeTempAttributeValue(String key) {
    return _readInt(key, min: -99, max: 99);
  }

  AttributeModifiers _tempAttributeModsWithValue(
    AttributeModifiers current,
    String key,
    int value,
  ) {
    switch (key) {
      case 'mu_temp':
        return current.copyWith(mu: value);
      case 'kl_temp':
        return current.copyWith(kl: value);
      case 'inn_temp':
        return current.copyWith(inn: value);
      case 'ch_temp':
        return current.copyWith(ch: value);
      case 'ff_temp':
        return current.copyWith(ff: value);
      case 'ge_temp':
        return current.copyWith(ge: value);
      case 'ko_temp':
        return current.copyWith(ko: value);
      case 'kk_temp':
        return current.copyWith(kk: value);
      default:
        return current;
    }
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

  /// Persistiert Temp-Modifikatoren direkt, ohne den globalen Edit-Modus zu nutzen.
  Future<void> _commitTempAttributeField(String key) async {
    if (!_isTempAttributeKey(key)) {
      return;
    }
    final hero = _latestHero;
    final state = _latestState;
    if (hero == null || state == null) {
      return;
    }

    final normalized = _normalizeTempAttributeValue(key);
    final normalizedText = normalized.toString();
    final currentValue = _field(key).text.trim();
    final nextMods = _tempAttributeModsWithValue(
      state.tempAttributeMods,
      key,
      normalized,
    );
    if (nextMods == state.tempAttributeMods) {
      if (currentValue != normalizedText) {
        _setFieldText(key, normalizedText);
      }
      return;
    }

    final updatedState = state.copyWith(tempAttributeMods: nextMods);
    try {
      await ref.read(heroActionsProvider).saveHeroState(hero.id, updatedState);
      _latestState = updatedState;
      _setFieldText(key, normalizedText);
      if (mounted) {
        _viewRevision.value++;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $error')));
      _editController.clearSyncSignature();
      _syncControllers(hero, state, force: true);
      _viewRevision.value++;
    }
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
      rasse: _field('rasse').text.trim(),
      rasseModText: _field('rasse_mod').text.trim(),
      kultur: _field('kultur').text.trim(),
      kulturModText: _field('kultur_mod').text.trim(),
      profession: _field('profession').text.trim(),
      professionModText: _field('profession_mod').text.trim(),
      geschlecht: _field('geschlecht').text.trim(),
      alter: _field('alter').text.trim(),
      groesse: _field('groesse').text.trim(),
      gewicht: _field('gewicht').text.trim(),
      haarfarbe: _field('haarfarbe').text.trim(),
      augenfarbe: _field('augenfarbe').text.trim(),
      aussehen: _field('aussehen').text.trim(),
      stand: _field('stand').text.trim(),
      titel: _field('titel').text.trim(),
      familieHerkunftHintergrund: _field('familie').text.trim(),
      sozialstatus: _readInt('sozialstatus', min: 0, max: 999),
      vorteileText: _field('vorteile').text.trim(),
      nachteileText: _field('nachteile').text.trim(),
      apTotal: _readInt('ap_total', min: 0),
      apSpent: _readInt('ap_spent', min: 0),
      bought: BoughtStats(
        lep: _readInt('b_lep', min: 0, max: 999),
        au: _readInt('b_au', min: 0, max: 999),
        asp: _readInt('b_asp', min: 0, max: 999),
        kap: _readInt('b_kap', min: 0, max: 999),
        mr: _readInt('b_mr', min: 0, max: 999),
      ),
      persistentMods: StatModifiers(
        lep: _readInt('m_lep', min: -999999, max: 999999),
        au: _readInt('m_au', min: -999999, max: 999999),
        asp: _readInt('m_asp', min: -999999, max: 999999),
        kap: _readInt('m_kap', min: -999999, max: 999999),
        mr: _readInt('m_mr', min: -999999, max: 999999),
        iniBase: _readInt('m_ini', min: -999999, max: 999999),
        gs: _readInt('m_gs', min: -999999, max: 999999),
        ausweichen: _readInt('m_ausw', min: -999999, max: 999999),
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
      tempAttributeMods: AttributeModifiers(
        mu: _readInt('mu_temp', min: -99, max: 99),
        kl: _readInt('kl_temp', min: -99, max: 99),
        inn: _readInt('inn_temp', min: -99, max: 99),
        ch: _readInt('ch_temp', min: -99, max: 99),
        ff: _readInt('ff_temp', min: -99, max: 99),
        ge: _readInt('ge_temp', min: -99, max: 99),
        ko: _readInt('ko_temp', min: -99, max: 99),
        kk: _readInt('kk_temp', min: -99, max: 99),
      ),
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

  void _applyApIncrement({
    required String targetKey,
    required String incrementKey,
    required String label,
  }) {
    if (!_editController.isEditing) {
      return;
    }
    final rawIncrement = _field(incrementKey).text.trim();
    if (rawIncrement.isEmpty) {
      return;
    }
    final increment = int.tryParse(rawIncrement);
    if (increment == null || increment <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fuer $label ist nur eine positive Ganzzahl erlaubt.'),
        ),
      );
      return;
    }
    final updatedValue = _readInt(targetKey, min: 0) + increment;
    _field(targetKey)
      ..text = updatedValue.toString()
      ..selection = TextSelection.collapsed(
        offset: updatedValue.toString().length,
      );
    _field(incrementKey).clear();
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
        _syncControllers(hero, state);
        return ValueListenableBuilder<int>(
          valueListenable: _viewRevision,
          builder: (context, revision, child) {
            return ListView(
              padding: const EdgeInsets.all(_pagePadding),
              children: [
                _buildBaseInfoSection(),
                const SizedBox(height: _sectionSpacing),
                _buildAdvantagesSection(),
                const SizedBox(height: _sectionSpacing),
                _buildApSection(hero),
                const SizedBox(height: _sectionSpacing),
                _buildCurrentResourcesSection(),
                if (kShowParserWarnings &&
                    hero.unknownModifierFragments.isNotEmpty) ...[
                  const SizedBox(height: _sectionSpacing),
                  _buildParserWarningsSection(hero),
                ],
                const SizedBox(height: _sectionSpacing),
                _buildCombinedStatsAndAttributesSection(
                  hero,
                  state,
                  snapshot.derivedStats,
                  snapshot.effectiveStartAttributes,
                  snapshot.attributeMaximums,
                  snapshot.effectiveAttributes,
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
    required this.current,
    required this.modifier,
    this.bought,
    this.boughtKey,
  });

  final String label;
  final int current;
  final int modifier;
  final int? bought;
  final String? boughtKey;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: _fieldSpacing),
            child,
          ],
        ),
      ),
    );
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
