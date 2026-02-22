import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

class HeroDetailScreen extends ConsumerStatefulWidget {
  const HeroDetailScreen({super.key, required this.heroId, this.embedded = false});

  final String heroId;
  final bool embedded;

  @override
  ConsumerState<HeroDetailScreen> createState() => _HeroDetailScreenState();
}

class _HeroDetailScreenState extends ConsumerState<HeroDetailScreen> {
  final _nameController = TextEditingController();
  final _levelController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};

  String? _initializedHeroId;

  @override
  void dispose() {
    _nameController.dispose();
    _levelController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _field(String key) {
    return _controllers.putIfAbsent(key, () => TextEditingController());
  }

  void _syncControllers(HeroSheet hero, HeroState state) {
    if (_initializedHeroId == hero.id) {
      return;
    }
    _initializedHeroId = hero.id;

    _nameController.text = hero.name;
    _levelController.text = hero.level.toString();

    _field('mu').text = hero.attributes.mu.toString();
    _field('kl').text = hero.attributes.kl.toString();
    _field('inn').text = hero.attributes.inn.toString();
    _field('ch').text = hero.attributes.ch.toString();
    _field('ff').text = hero.attributes.ff.toString();
    _field('ge').text = hero.attributes.ge.toString();
    _field('ko').text = hero.attributes.ko.toString();
    _field('kk').text = hero.attributes.kk.toString();

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

  int _readInt(String key, {int min = -999, int max = 999}) {
    final parsed = int.tryParse(_field(key).text.trim()) ?? 0;
    if (parsed < min) {
      return min;
    }
    if (parsed > max) {
      return max;
    }
    return parsed;
  }

  Future<void> _save(HeroSheet hero) async {
    final actions = ref.read(heroActionsProvider);

    final updatedHero = hero.copyWith(
      name: _nameController.text.trim().isEmpty ? 'Unbenannter Held' : _nameController.text.trim(),
      level: int.tryParse(_levelController.text.trim())?.clamp(1, 40) ?? 1,
      attributes: Attributes(
        mu: _readInt('mu', min: 1, max: 30),
        kl: _readInt('kl', min: 1, max: 30),
        inn: _readInt('inn', min: 1, max: 30),
        ch: _readInt('ch', min: 1, max: 30),
        ff: _readInt('ff', min: 1, max: 30),
        ge: _readInt('ge', min: 1, max: 30),
        ko: _readInt('ko', min: 1, max: 30),
        kk: _readInt('kk', min: 1, max: 30),
      ),
      bought: BoughtStats(
        lep: _readInt('b_lep', min: 0, max: 99),
        au: _readInt('b_au', min: 0, max: 99),
        asp: _readInt('b_asp', min: 0, max: 99),
        kap: _readInt('b_kap', min: 0, max: 99),
        mr: _readInt('b_mr', min: 0, max: 99),
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
      currentLep: _readInt('cur_lep', min: 0, max: 999),
      currentAu: _readInt('cur_au', min: 0, max: 999),
      currentAsp: _readInt('cur_asp', min: 0, max: 999),
      currentKap: _readInt('cur_kap', min: 0, max: 999),
      tempMods: const StatModifiers(),
    );

    await actions.saveHero(updatedHero);
    await actions.saveHeroState(updatedHero.id, updatedState);

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Held gespeichert')));
  }

  @override
  Widget build(BuildContext context) {
    final heroes = ref.watch(heroListProvider).valueOrNull ?? const [];
    HeroSheet? hero;
    for (final item in heroes) {
      if (item.id == widget.heroId) {
        hero = item;
        break;
      }
    }

    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    final stateAsync = ref.watch(heroStateProvider(widget.heroId));

    return stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
      data: (state) {
        _syncControllers(hero!, state);
        final derived = computeDerivedStats(hero, state);

        final content = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Basisdaten', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(
              controller: _levelController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Level'),
            ),
            const SizedBox(height: 16),
            Text('Eigenschaften', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _numberGrid(['mu', 'kl', 'inn', 'ch', 'ff', 'ge', 'ko', 'kk']),
            const SizedBox(height: 16),
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
            Text('Berechnete Werte', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statChip('LeP Max', derived.maxLep),
                _statChip('Au Max', derived.maxAu),
                _statChip('AsP Max', derived.maxAsp),
                _statChip('KaP Max', derived.maxKap),
                _statChip('MR', derived.mr),
                _statChip('Ini-Basis', derived.iniBase),
                _statChip('GS', derived.gs),
                _statChip('Ausweichen', derived.ausweichen),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _save(hero!),
                  icon: const Icon(Icons.save),
                  label: const Text('Speichern'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await ref.read(heroActionsProvider).deleteHero(widget.heroId);
                    if (!mounted || widget.embedded) {
                      return;
                    }
                    navigator.pop();
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Loeschen'),
                ),
              ],
            ),
          ],
        );

        if (widget.embedded) {
          return content;
        }

        return Scaffold(
          appBar: AppBar(title: Text(hero.name)),
          body: content,
        );
      },
    );
  }

  Widget _statChip(String label, int value) {
    return Chip(label: Text('$label: $value'));
  }

  Widget _numberGrid(List<String> keys) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: keys.map((key) {
        return SizedBox(
          width: 140,
          child: TextField(
            controller: _field(key),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: _labelForKey(key)),
          ),
        );
      }).toList(),
    );
  }

  String _labelForKey(String key) {
    const labels = {
      'mu': 'MU',
      'kl': 'KL',
      'inn': 'IN',
      'ch': 'CH',
      'ff': 'FF',
      'ge': 'GE',
      'ko': 'KO',
      'kk': 'KK',
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
}



