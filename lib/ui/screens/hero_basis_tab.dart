import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_feature_flags.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

const double _pagePadding = 16;
const double _sectionSpacing = 16;
const double _fieldSpacing = 12;
const double _gridSpacing = 12;
const double _standardTwoColumnBreakpoint = 700;
const double _largeTwoColumnBreakpoint = 900;

class HeroBasisTab extends ConsumerStatefulWidget {
  const HeroBasisTab({
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
  ConsumerState<HeroBasisTab> createState() => _HeroBasisTabState();
}

class _HeroBasisTabState extends ConsumerState<HeroBasisTab>
    with AutomaticKeepAliveClientMixin {
  final _nameController = TextEditingController();
  final _levelController = TextEditingController();
  final _apAvailableController = TextEditingController();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

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
      if (!mounted) {
        return;
      }
      _registerWithParent();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _levelController.dispose();
    _apAvailableController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _registerWithParent() {
    _editController.emitCurrentState();
    widget.onRegisterDiscard(_discardChanges);
    widget.onRegisterEditActions(
      WorkspaceTabEditActions(
        startEdit: _startEdit,
        save: _saveFromParentAction,
        cancel: _cancelFromParentAction,
      ),
    );
  }

  TextEditingController _field(String key) {
    return _controllers.putIfAbsent(key, () => TextEditingController());
  }

  void _syncControllers(HeroSheet hero, HeroState state, {bool force = false}) {
    final signature = jsonEncode({
      'hero': hero.toJson(),
      'state': state.toJson(),
    });
    if (!_editController.shouldSync(signature, force: force)) {
      return;
    }

    _nameController.text = hero.name;
    _levelController.text = hero.level.toString();
    _apAvailableController.text = hero.apAvailable.toString();

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
  }

  int _readInt(String key, {int min = -999999, int max = 999999}) {
    final parsed = int.tryParse(_field(key).text.trim()) ?? 0;
    if (parsed < min) {
      return min;
    }
    if (parsed > max) {
      return max;
    }
    return parsed;
  }

  Future<void> _startEdit() async {
    _editController.startEdit();
  }

  Future<void> _saveFromParentAction() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    await _save(hero, showSnack: true);
    if (!mounted) {
      return;
    }
    _editController.markSaved();
  }

  Future<void> _cancelFromParentAction() async {
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

  Future<void> _save(HeroSheet hero, {bool showSnack = true}) async {
    final actions = ref.read(heroActionsProvider);

    final updatedHero = hero.copyWith(
      name: _nameController.text.trim().isEmpty
          ? 'Unbenannter Held'
          : _nameController.text.trim(),
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
        lep: _readInt('m_lep'),
        au: _readInt('m_au'),
        asp: _readInt('m_asp'),
        kap: _readInt('m_kap'),
        mr: _readInt('m_mr'),
        iniBase: _readInt('m_ini'),
        gs: _readInt('m_gs'),
        ausweichen: _readInt('m_ausw'),
      ),
    );

    final updatedState = HeroState(
      currentLep: _readInt('cur_lep', min: 0, max: 99999),
      currentAu: _readInt('cur_au', min: 0, max: 99999),
      currentAsp: _readInt('cur_asp', min: 0, max: 99999),
      currentKap: _readInt('cur_kap', min: 0, max: 99999),
      tempMods: _latestState?.tempMods ?? const StatModifiers(),
      tempAttributeMods:
          _latestState?.tempAttributeMods ?? const AttributeModifiers(),
    );

    await actions.saveHero(updatedHero);
    await actions.saveHeroState(updatedHero.id, updatedState);

    if (!mounted || !showSnack) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Basisdaten gespeichert')));
  }

  void _onEditableFieldChanged(String _) {
    _editController.markFieldChanged();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hero = ref.watch(heroByIdProvider(widget.heroId));

    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    final stateAsync = ref.watch(heroStateProvider(widget.heroId));

    return stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
      data: (state) {
        _latestHero = hero;
        _latestState = state;
        _syncControllers(hero, state);
        final derived = computeDerivedStats(hero, state);

        return ListView(
          padding: const EdgeInsets.all(_pagePadding),
          children: [
            _buildStammdatenSection(),
            const SizedBox(height: _sectionSpacing),
            _buildBiografieSection(),
            const SizedBox(height: _sectionSpacing),
            _buildApSection(),
            if (kShowParserWarnings && hero.unknownModifierFragments.isNotEmpty) ...[
              const SizedBox(height: _sectionSpacing),
              _buildParserWarningsSection(hero),
            ],
            const SizedBox(height: _sectionSpacing),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= _largeTwoColumnBreakpoint) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildBoughtSection()),
                          const SizedBox(width: _sectionSpacing),
                          Expanded(child: _buildCurrentResourcesSection()),
                        ],
                      ),
                      const SizedBox(height: _sectionSpacing),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildModifiersSection()),
                          const SizedBox(width: _sectionSpacing),
                          Expanded(child: _buildQuickViewSection(derived)),
                        ],
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildBoughtSection(),
                    const SizedBox(height: _sectionSpacing),
                    _buildModifiersSection(),
                    const SizedBox(height: _sectionSpacing),
                    _buildCurrentResourcesSection(),
                    const SizedBox(height: _sectionSpacing),
                    _buildQuickViewSection(derived),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStammdatenSection() {
    return _SectionCard(
      title: 'Stammdaten',
      child: _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          TextField(
            controller: _nameController,
            readOnly: !_editController.isEditing,
            decoration: _inputDecoration('Name'),
            onChanged: _editController.isEditing ? _onEditableFieldChanged : null,
          ),
          _textField('Rasse', 'rasse'),
          _textField('Modifikatoren', 'rasse_mod'),
          _textField('Kultur', 'kultur'),
          _textField('Modifikatoren', 'kultur_mod'),
          _textField('Profession', 'profession'),
          _textField('Modifikatoren', 'profession_mod'),
        ],
      ),
    );
  }

  Widget _buildBiografieSection() {
    return _SectionCard(
      title: 'Biografie und Status',
      child: _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          _textField('Geschlecht', 'geschlecht'),
          _textField('Alter', 'alter'),
          _textField('Groesse', 'groesse'),
          _textField('Gewicht', 'gewicht'),
          _textField('Haarfarbe', 'haarfarbe'),
          _textField('Augenfarbe', 'augenfarbe'),
          _textField('Aussehen', 'aussehen', maxLines: 2),
          _textField('Stand', 'stand'),
          _textField('Titel', 'titel'),
          _textField('Familie, Herkunft und Hintergrund', 'familie', maxLines: 3),
          _intField('Sozialstatus', 'sozialstatus'),
          _textField('Vorteile', 'vorteile', maxLines: 4),
          _textField('Nachteile', 'nachteile', maxLines: 4),
        ],
      ),
    );
  }

  Widget _buildApSection() {
    return _SectionCard(
      title: 'AP und Level',
      child: _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          _intField('AP Gesamt', 'ap_total', min: 0),
          _intField('AP Ausgegeben', 'ap_spent', min: 0),
          TextField(
            controller: _apAvailableController,
            readOnly: true,
            decoration: _inputDecoration('AP Verfuegbar (auto)'),
          ),
          TextField(
            controller: _levelController,
            readOnly: true,
            decoration: _inputDecoration('Level (aus AP-Formel)'),
          ),
        ],
      ),
    );
  }

  Widget _buildParserWarningsSection(HeroSheet hero) {
    return _SectionCard(
      title: 'Parser-Warnungen',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: hero.unknownModifierFragments
            .map((entry) => Chip(label: Text(entry)))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildBoughtSection() {
    return _SectionCard(
      title: 'Zugekaufte Werte',
      child: _numberGrid(['b_lep', 'b_au', 'b_asp', 'b_kap', 'b_mr']),
    );
  }

  Widget _buildModifiersSection() {
    return _SectionCard(
      title: 'Modifikatoren',
      child: _numberGrid([
        'm_lep',
        'm_au',
        'm_asp',
        'm_kap',
        'm_mr',
        'm_ini',
        'm_gs',
        'm_ausw',
      ]),
    );
  }

  Widget _buildCurrentResourcesSection() {
    return _SectionCard(
      title: 'Aktuelle Ressourcen',
      child: _numberGrid(['cur_lep', 'cur_au', 'cur_asp', 'cur_kap']),
    );
  }

  Widget _buildQuickViewSection(DerivedStats derived) {
    return _SectionCard(
      title: 'Schnellansicht Berechnet',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _statChip('LeP Max', derived.maxLep),
          _statChip('Au Max', derived.maxAu),
          _statChip('AsP Max', derived.maxAsp),
          _statChip('MR', derived.mr),
          _statChip('Ini-Basis', derived.iniBase),
        ],
      ),
    );
  }

  Widget _textField(String label, String key, {int maxLines = 1}) {
    return TextField(
      controller: _field(key),
      readOnly: !_editController.isEditing,
      decoration: _inputDecoration(label),
      maxLines: maxLines,
      onChanged: _editController.isEditing ? _onEditableFieldChanged : null,
    );
  }

  Widget _intField(String label, String key, {int min = -999999}) {
    return TextField(
      controller: _field(key),
      readOnly: !_editController.isEditing,
      keyboardType: TextInputType.number,
      decoration: _inputDecoration(label),
      onChanged: _editController.isEditing ? _onEditableFieldChanged : null,
    );
  }

  Widget _statChip(String label, int value) {
    return Chip(label: Text('$label: $value'));
  }

  Widget _numberGrid(List<String> keys) {
    return _ResponsiveFieldGrid(
      breakpoint: _standardTwoColumnBreakpoint,
      children: keys
          .map(
            (key) => TextField(
              controller: _field(key),
              readOnly: !_editController.isEditing,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(_labelForKey(key)),
              onChanged: _editController.isEditing ? _onEditableFieldChanged : null,
            ),
          )
          .toList(growable: false),
    );
  }

  String _labelForKey(String key) {
    const labels = {
      'b_lep': 'LeP gekauft',
      'b_au': 'Au gekauft',
      'b_asp': 'AsP gekauft',
      'b_kap': 'KaP gekauft',
      'b_mr': 'MR gekauft',
      'm_lep': 'Mod LeP',
      'm_au': 'Mod Au',
      'm_asp': 'Mod AsP',
      'm_kap': 'Mod KaP',
      'm_mr': 'Mod MR',
      'm_ini': 'Mod Ini',
      'm_gs': 'Mod GS',
      'm_ausw': 'Mod Ausweichen',
      'cur_lep': 'LeP aktuell',
      'cur_au': 'Au aktuell',
      'cur_asp': 'AsP aktuell',
      'cur_kap': 'KaP aktuell',
    };
    return labels[key] ?? key;
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

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
              .map(
                (child) => SizedBox(
                  width: itemWidth,
                  child: child,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}
