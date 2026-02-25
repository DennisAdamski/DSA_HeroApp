import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
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

  static const List<(String, String)> _attributeEntries = [
    ('MU', 'mu'),
    ('KL', 'kl'),
    ('IN', 'inn'),
    ('CH', 'ch'),
    ('FF', 'ff'),
    ('GE', 'ge'),
    ('KO', 'ko'),
    ('KK', 'kk'),
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
    final signature = jsonEncode({
      'hero': hero.toJson(),
      'state': state.toJson(),
    });
    if (!_editController.shouldSync(signature, force: force)) {
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

  int _readInt(
    String key, {
    required int min,
    int max = 999999,
  }) {
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
    await ref.read(heroActionsProvider).saveHeroState(updatedHero.id, updatedState);
    if (!mounted) {
      return;
    }

    _editController.markSaved();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Uebersicht gespeichert')));
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
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hero = ref.watch(heroByIdProvider(widget.heroId));

    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    final stateAsync = ref.watch(heroStateProvider(widget.heroId));
    final derivedAsync = ref.watch(derivedStatsProvider(widget.heroId));

    return stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
      data: (state) {
        _latestHero = hero;
        _latestState = state;
        _syncControllers(hero, state);
        final effectiveAttributes = computeEffectiveAttributes(
          hero,
          tempAttributeMods: state.tempAttributeMods,
        );

        return ListView(
          padding: const EdgeInsets.all(_pagePadding),
          children: [
            _buildBaseInfoSection(),
            const SizedBox(height: _sectionSpacing),
            _buildAdvantagesSection(),
            const SizedBox(height: _sectionSpacing),
            _buildApSection(hero),
            if (kShowParserWarnings && hero.unknownModifierFragments.isNotEmpty) ...[
              const SizedBox(height: _sectionSpacing),
              _buildParserWarningsSection(hero),
            ],
            const SizedBox(height: _sectionSpacing),
            derivedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('Fehler: $error'),
              data: (derived) => _buildCombinedStatsAndAttributesSection(
                hero,
                state,
                derived,
                effectiveAttributes,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBaseInfoSection() {
    return _SectionCard(
      title: 'Basisinformationen',
      child: Column(
        children: [
          _buildInputField(label: 'Name', keyName: 'name'),
          const SizedBox(height: _gridSpacing),
          _ResponsiveFieldGrid(
            breakpoint: _standardTwoColumnBreakpoint,
            children: [
              _buildInputField(label: 'Rasse', keyName: 'rasse'),
              _buildInputField(label: 'Rasse Modifikatoren', keyName: 'rasse_mod'),
            ],
          ),
          const SizedBox(height: _gridSpacing),
          _ResponsiveFieldGrid(
            breakpoint: _standardTwoColumnBreakpoint,
            children: [
              _buildInputField(label: 'Kultur', keyName: 'kultur'),
              _buildInputField(
                label: 'Kultur Modifikatoren',
                keyName: 'kultur_mod',
              ),
            ],
          ),
          const SizedBox(height: _gridSpacing),
          _ResponsiveFieldGrid(
            breakpoint: _standardTwoColumnBreakpoint,
            children: [
              _buildInputField(label: 'Profession', keyName: 'profession'),
              _buildInputField(
                label: 'Profession Modifikatoren',
                keyName: 'profession_mod',
              ),
            ],
          ),
          const SizedBox(height: _gridSpacing),
          _ResponsiveFieldGrid(
            breakpoint: _standardTwoColumnBreakpoint,
            children: [
              _buildInputField(label: 'Geschlecht', keyName: 'geschlecht'),
              _buildInputField(label: 'Alter', keyName: 'alter'),
              _buildInputField(label: 'Groesse', keyName: 'groesse'),
              _buildInputField(label: 'Gewicht', keyName: 'gewicht'),
              _buildInputField(label: 'Haarfarbe', keyName: 'haarfarbe'),
              _buildInputField(label: 'Augenfarbe', keyName: 'augenfarbe'),
              _buildInputField(label: 'Stand', keyName: 'stand'),
              _buildInputField(label: 'Titel', keyName: 'titel'),
              _buildInputField(
                label: 'Sozialstatus',
                keyName: 'sozialstatus',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: _gridSpacing),
          _ResponsiveFieldGrid(
            breakpoint: _standardTwoColumnBreakpoint,
            children: [
              _buildInputField(
                label: 'Aussehen',
                keyName: 'aussehen',
                minLines: 4,
                maxLines: 6,
              ),
              _buildInputField(
                label: 'Familie/Herkunft/Hintergrund',
                keyName: 'familie',
                minLines: 4,
                maxLines: 6,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvantagesSection() {
    return _SectionCard(
      title: 'Vorteile und Nachteile',
      child: _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          _buildInputField(
            label: 'Vorteile',
            keyName: 'vorteile',
            minLines: 2,
            maxLines: null,
          ),
          _buildInputField(
            label: 'Nachteile',
            keyName: 'nachteile',
            minLines: 2,
            maxLines: null,
          ),
        ],
      ),
    );
  }

  Widget _buildApSection(HeroSheet hero) {
    return _SectionCard(
      title: 'AP und Level',
      child: _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          _buildInputField(
            label: 'AP Gesamt',
            keyName: 'ap_total',
            keyboardType: TextInputType.number,
          ),
          _buildInputField(
            label: 'AP Ausgegeben',
            keyName: 'ap_spent',
            keyboardType: TextInputType.number,
          ),
          _buildReadOnlyValueField(
            label: 'AP Verfuegbar',
            value: hero.apAvailable.toString(),
          ),
          _buildReadOnlyValueField(
            label: 'Level',
            value: hero.level.toString(),
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

  @override
  bool get wantKeepAlive => true;

  Widget _buildCombinedStatsAndAttributesSection(
    HeroSheet hero,
    HeroState state,
    DerivedStats derived,
    Attributes effectiveAttributes,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final derivedSection = _buildDerivedValuesSection(hero, state, derived);
        final attributesSection = _buildAttributesSection(effectiveAttributes);
        if (constraints.maxWidth >= _largeTwoColumnBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: attributesSection),
              const SizedBox(width: _sectionSpacing),
              Expanded(child: derivedSection),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            attributesSection,
            const SizedBox(height: _sectionSpacing),
            derivedSection,
          ],
        );
      },
    );
  }

  Widget _buildDerivedValuesSection(
    HeroSheet hero,
    HeroState state,
    DerivedStats derived,
  ) {
    final parsed = parseModifierTextsForHero(hero);
    final totalMods = hero.persistentMods + parsed.statMods + state.tempMods;
    final entries = <_DerivedRow>[
      _DerivedRow(
        label: 'LeP Max',
        current: derived.maxLep,
        modifier: totalMods.lep + _cappedLevel(hero.level),
        bought: hero.bought.lep,
      ),
      _DerivedRow(
        label: 'Au Max',
        current: derived.maxAu,
        modifier: totalMods.au + hero.level * 2,
        bought: hero.bought.au,
      ),
      _DerivedRow(
        label: 'AsP Max',
        current: derived.maxAsp,
        modifier: totalMods.asp + hero.level * 2,
        bought: hero.bought.asp,
      ),
      _DerivedRow(
        label: 'KaP Max',
        current: derived.maxKap,
        modifier: totalMods.kap,
        bought: hero.bought.kap,
      ),
      _DerivedRow(
        label: 'MR',
        current: derived.mr,
        modifier: totalMods.mr,
        bought: hero.bought.mr,
      ),
      _DerivedRow(
        label: 'Ini-Basis',
        current: derived.iniBase,
        modifier: totalMods.iniBase,
      ),
      _DerivedRow(
        label: 'GS',
        current: derived.gs,
        modifier: totalMods.gs,
      ),
      _DerivedRow(
        label: 'Ausweichen',
        current: derived.ausweichen,
        modifier: totalMods.ausweichen,
      ),
    ];

    return _SectionCard(
      title: 'Abgeleitete Werte',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 560),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const <int, TableColumnWidth>{
              0: FixedColumnWidth(112),
              1: FixedColumnWidth(_attributeValueCellWidth),
              2: FixedColumnWidth(_attributeValueCellWidth),
              3: FixedColumnWidth(_attributeValueCellWidth),
              4: FixedColumnWidth(_attributeValueCellWidth),
            },
            children: [
              TableRow(
                children: [
                  _buildAttributesTableHeaderCell('Wert'),
                  _buildAttributesTableHeaderCell('Start'),
                  _buildAttributesTableHeaderCell('Modifikator'),
                  _buildAttributesTableHeaderCell('Aktuell'),
                  _buildAttributesTableHeaderCell('Zugekauft'),
                ],
              ),
              ...entries.map(
                (entry) => TableRow(
                  children: [
                    _buildAttributesTableLabelCell(entry.label),
                    _buildDerivedValueCell(
                      value: (entry.current - entry.modifier - (entry.bought ?? 0))
                          .toString(),
                    ),
                    _buildDerivedValueCell(value: entry.modifier.toString()),
                    _buildDerivedValueCell(value: entry.current.toString()),
                    _buildDerivedValueCell(
                      value: entry.bought?.toString() ?? '-',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttributesSection(Attributes effectiveAttributes) {
    final rows = _attributeEntries.map((entry) {
      final key = entry.$2;
      final startKey = '${key}_start';
      final tempKey = '${key}_temp';
      final effective = _effectiveValueByKey(effectiveAttributes, key);
      return TableRow(
        children: [
          _buildAttributesTableLabelCell(entry.$1),
          _buildAttributesNumericCell(
            keyName: startKey,
            readOnly: true,
          ),
          _buildAttributesNumericCell(
            keyName: key,
            readOnly: false,
          ),
          _buildAttributesNumericCell(
            keyName: tempKey,
            readOnly: false,
          ),
          _buildAttributesComputedCell(
            keyName: key,
            value: effective.toString(),
          ),
        ],
      );
    }).toList(growable: false);

    return _SectionCard(
      title: 'Eigenschaften',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 520),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const <int, TableColumnWidth>{
              0: FixedColumnWidth(96),
              1: FixedColumnWidth(_attributeValueCellWidth),
              2: FixedColumnWidth(_attributeValueCellWidth),
              3: FixedColumnWidth(_attributeValueCellWidth),
              4: FixedColumnWidth(_attributeValueCellWidth),
            },
            children: [
              TableRow(
                children: [
                  _buildAttributesTableHeaderCell('Eigenschaft'),
                  _buildAttributesTableHeaderCell('Start'),
                  _buildAttributesTableHeaderCell('Attribut'),
                  _buildAttributesTableHeaderCell('Temp-Mod'),
                  _buildAttributesTableHeaderCell('Berechnet'),
                ],
              ),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttributesTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }

  Widget _buildAttributesTableLabelCell(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }

  Widget _buildAttributesNumericCell({
    required String keyName,
    required bool readOnly,
  }) {
    final isReadOnly = readOnly || !_editController.isEditing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: SizedBox(
        width: _attributeValueCellWidth,
        child: TextField(
          key: ValueKey<String>('overview-field-$keyName'),
          controller: _field(keyName),
          readOnly: isReadOnly,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('').copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
          ),
          onChanged: isReadOnly ? null : _onFieldChanged,
        ),
      ),
    );
  }

  Widget _buildAttributesComputedCell({
    required String keyName,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: SizedBox(
        width: _attributeValueCellWidth,
        child: InputDecorator(
          key: ValueKey<String>('overview-effective-$keyName'),
          decoration: _inputDecoration('').copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
          ),
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }

  Widget _buildDerivedValueCell({required String value}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: SizedBox(
        width: _attributeValueCellWidth,
        child: InputDecorator(
          decoration: _inputDecoration('').copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
          ),
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }

  int _cappedLevel(int level) {
    if (level < 0) {
      return 0;
    }
    if (level > 21) {
      return 21;
    }
    return level;
  }

  int _effectiveValueByKey(Attributes effective, String key) {
    switch (key) {
      case 'mu':
        return effective.mu;
      case 'kl':
        return effective.kl;
      case 'inn':
        return effective.inn;
      case 'ch':
        return effective.ch;
      case 'ff':
        return effective.ff;
      case 'ge':
        return effective.ge;
      case 'ko':
        return effective.ko;
      case 'kk':
        return effective.kk;
      default:
        return 0;
    }
  }

  Widget _buildInputField({
    required String label,
    required String keyName,
    int? minLines,
    int? maxLines = 1,
    TextInputType? keyboardType,
    bool? readOnly,
  }) {
    final isReadOnly = readOnly ?? !_editController.isEditing;
    return TextField(
      key: ValueKey<String>('overview-field-$keyName'),
      controller: _field(keyName),
      readOnly: isReadOnly,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label),
      onChanged: isReadOnly ? null : _onFieldChanged,
    );
  }

  Widget _buildReadOnlyValueField({
    required String label,
    required String value,
    Key? key,
  }) {
    return InputDecorator(
      key: key,
      decoration: _inputDecoration(label),
      child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    );
  }
}

class _DerivedRow {
  const _DerivedRow({
    required this.label,
    required this.current,
    required this.modifier,
    this.bought,
  });

  final String label;
  final int current;
  final int modifier;
  final int? bought;
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
