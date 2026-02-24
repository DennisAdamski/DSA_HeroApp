import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

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
  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};

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
      tempMods: const StatModifiers(),
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
          padding: const EdgeInsets.all(16),
          children: [
            Text('Basisdaten', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              readOnly: !_editController.isEditing,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: _editController.isEditing ? _onEditableFieldChanged : null,
            ),
            const SizedBox(height: 12),
            _tripleTextFields('Rasse', 'rasse', 'Modifikatoren', 'rasse_mod'),
            _tripleTextFields('Kultur', 'kultur', 'Modifikatoren', 'kultur_mod'),
            _tripleTextFields(
              'Profession',
              'profession',
              'Modifikatoren',
              'profession_mod',
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            Text('AP und Level', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _intField('AP Gesamt', 'ap_total', min: 0),
            _intField('AP Ausgegeben', 'ap_spent', min: 0),
            TextField(
              controller: _apAvailableController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'AP Verfuegbar (auto)'),
            ),
            TextField(
              controller: _levelController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Level (aus AP-Formel)'),
            ),
            const SizedBox(height: 16),
            if (hero.unknownModifierFragments.isNotEmpty) ...[
              Text('Parser-Warnungen', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hero.unknownModifierFragments
                    .map((entry) => Chip(label: Text(entry)))
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
            ],
            Text('Zugekaufte Werte', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _numberGrid(['b_lep', 'b_au', 'b_asp', 'b_kap', 'b_mr']),
            const SizedBox(height: 16),
            Text('Modifikatoren', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _numberGrid(['m_lep', 'm_au', 'm_asp', 'm_kap', 'm_mr', 'm_ini', 'm_gs', 'm_ausw']),
            const SizedBox(height: 16),
            Text('Aktuelle Ressourcen', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _numberGrid(['cur_lep', 'cur_au', 'cur_asp', 'cur_kap']),
            const SizedBox(height: 16),
            Text('Schnellansicht Berechnet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
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
          ],
        );
      },
    );
  }

  Widget _tripleTextFields(
    String firstLabel,
    String firstKey,
    String secondLabel,
    String secondKey,
  ) {
    return Row(
      children: [
        Expanded(child: _textField(firstLabel, firstKey)),
        const SizedBox(width: 12),
        Expanded(child: _textField(secondLabel, secondKey)),
      ],
    );
  }

  Widget _textField(String label, String key, {int maxLines = 1}) {
    return TextField(
      controller: _field(key),
      readOnly: !_editController.isEditing,
      decoration: InputDecoration(labelText: label),
      maxLines: maxLines,
      onChanged: _editController.isEditing ? _onEditableFieldChanged : null,
    );
  }

  Widget _intField(String label, String key, {int min = -999999}) {
    return TextField(
      controller: _field(key),
      readOnly: !_editController.isEditing,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: _editController.isEditing ? _onEditableFieldChanged : null,
    );
  }

  Widget _statChip(String label, int value) {
    return Chip(label: Text('$label: $value'));
  }

  Widget _numberGrid(List<String> keys) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: keys
          .map((key) {
            return SizedBox(
              width: 150,
              child: TextField(
                controller: _field(key),
                readOnly: !_editController.isEditing,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: _labelForKey(key)),
                onChanged: _editController.isEditing ? _onEditableFieldChanged : null,
              ),
            );
          })
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

  @override
  bool get wantKeepAlive => true;
}
