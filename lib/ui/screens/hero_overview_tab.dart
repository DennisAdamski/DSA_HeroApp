import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

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
  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};

  late final WorkspaceTabEditController _editController;
  HeroSheet? _latestHero;

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

  void _syncControllers(HeroSheet hero, {bool force = false}) {
    final signature = jsonEncode(hero.toJson());
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
    if (hero == null) {
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
      attributes: hero.attributes.copyWith(
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

    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }

    _editController.markSaved();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Übersicht gespeichert')));
  }

  Future<void> _cancelChanges() async {
    await _discardChanges();
  }

  Future<void> _discardChanges() async {
    final hero = _latestHero;
    if (hero != null) {
      _editController.clearSyncSignature();
      _syncControllers(hero, force: true);
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

    _latestHero = hero;
    _syncControllers(hero);

    final derivedAsync = ref.watch(derivedStatsProvider(widget.heroId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Basisinformationen', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isTwoColumn = constraints.maxWidth >= 700;
            final fields = <_OverviewFieldSpec>[
              const _OverviewFieldSpec(label: 'Name', key: 'name'),
              const _OverviewFieldSpec(label: 'Rasse', key: 'rasse'),
              const _OverviewFieldSpec(label: 'Rasse Modifikatoren', key: 'rasse_mod'),
              const _OverviewFieldSpec(label: 'Kultur', key: 'kultur'),
              const _OverviewFieldSpec(label: 'Kultur Modifikatoren', key: 'kultur_mod'),
              const _OverviewFieldSpec(label: 'Profession', key: 'profession'),
              const _OverviewFieldSpec(label: 'Profession Modifikatoren', key: 'profession_mod'),
              const _OverviewFieldSpec(label: 'Geschlecht', key: 'geschlecht'),
              const _OverviewFieldSpec(label: 'Alter', key: 'alter'),
              const _OverviewFieldSpec(label: 'Groesse', key: 'groesse'),
              const _OverviewFieldSpec(label: 'Gewicht', key: 'gewicht'),
              const _OverviewFieldSpec(label: 'Haarfarbe', key: 'haarfarbe'),
              const _OverviewFieldSpec(label: 'Augenfarbe', key: 'augenfarbe'),
              const _OverviewFieldSpec(label: 'Aussehen', key: 'aussehen', maxLines: 2),
              const _OverviewFieldSpec(label: 'Stand', key: 'stand'),
              const _OverviewFieldSpec(label: 'Titel', key: 'titel'),
              const _OverviewFieldSpec(
                label: 'Familie/Herkunft/Hintergrund',
                key: 'familie',
                maxLines: 3,
              ),
              const _OverviewFieldSpec(
                label: 'Sozialstatus',
                key: 'sozialstatus',
                keyboardType: TextInputType.number,
              ),
            ];

            if (isTwoColumn) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: fields
                    .map(
                      (entry) => SizedBox(
                        width: itemWidth,
                        child: _buildInputField(
                          label: entry.label,
                          keyName: entry.key,
                          maxLines: entry.maxLines,
                          keyboardType: entry.keyboardType,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            }

            return Column(
              children: fields
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildInputField(
                        label: entry.label,
                        keyName: entry.key,
                        maxLines: entry.maxLines,
                        keyboardType: entry.keyboardType,
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildInputField(label: 'Vorteile', keyName: 'vorteile', maxLines: 4),
        const SizedBox(height: 12),
        _buildInputField(label: 'Nachteile', keyName: 'nachteile', maxLines: 4),
        const SizedBox(height: 16),
        Text('AP und Level', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildApEditorCard('AP Gesamt', _field('ap_total')),
              const SizedBox(width: 12),
              _buildApEditorCard('AP Ausgegeben', _field('ap_spent')),
              const SizedBox(width: 12),
              _buildApValueCard('AP Verfügbar', hero.apAvailable.toString()),
              const SizedBox(width: 12),
              _buildApValueCard('Level', hero.level.toString()),
            ],
          ),
        ),
        if (hero.unknownModifierFragments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Parser-Warnungen', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hero.unknownModifierFragments
                .map((entry) => Chip(label: Text(entry)))
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: 16),
        derivedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text('Fehler: $error'),
          data: _buildCombinedStatsAndAttributesSection,
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildCombinedStatsAndAttributesSection(DerivedStats derived) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final derivedSection = _buildDerivedValuesSection(derived);
        final attributesSection = _buildAttributesSection();
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: derivedSection),
              const SizedBox(width: 16),
              Expanded(child: attributesSection),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            attributesSection,
            const SizedBox(height: 16),
            derivedSection,
          ],
        );
      },
    );
  }

  Widget _buildDerivedValuesSection(DerivedStats derived) {
    final entries = [
      ('LeP Max', derived.maxLep),
      ('Au Max', derived.maxAu),
      ('AsP Max', derived.maxAsp),
      ('KaP Max', derived.maxKap),
      ('MR', derived.mr),
      ('Ini-Basis', derived.iniBase),
      ('GS', derived.gs),
      ('Ausweichen', derived.ausweichen),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Abgeleitete Werte', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...entries.map(
          (entry) => Card(
            child: ListTile(
              title: Text(entry.$1),
              trailing: Text(
                entry.$2.toString(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttributesSection() {
    final entries = [
      ('MU', 'mu'),
      ('KL', 'kl'),
      ('IN', 'inn'),
      ('CH', 'ch'),
      ('FF', 'ff'),
      ('GE', 'ge'),
      ('KO', 'ko'),
      ('KK', 'kk'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Eigenschaften', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isTwoColumn = constraints.maxWidth >= 260;
            final fieldWidth = isTwoColumn
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: entries
                  .map(
                    (entry) => SizedBox(
                      width: fieldWidth,
                      child: _buildInputField(
                        label: entry.$1,
                        keyName: entry.$2,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String keyName,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      key: ValueKey<String>('overview-field-$keyName'),
      controller: _field(keyName),
      readOnly: !_editController.isEditing,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      onChanged: _editController.isEditing ? _onFieldChanged : null,
    );
  }

  Widget _buildApEditorCard(String label, TextEditingController controller) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                key: ValueKey<String>('overview-ap-$label'),
                controller: controller,
                readOnly: !_editController.isEditing,
                keyboardType: TextInputType.number,
                onChanged: _editController.isEditing ? _onFieldChanged : null,
                decoration: InputDecoration(labelText: label, isDense: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApValueCard(String label, String value) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewFieldSpec {
  const _OverviewFieldSpec({
    required this.label,
    required this.key,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final String key;
  final int maxLines;
  final TextInputType? keyboardType;
}
