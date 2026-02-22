import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

class HeroTalentsTab extends ConsumerWidget {
  const HeroTalentsTab({super.key, required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroes = ref.watch(heroListProvider).valueOrNull ?? const <HeroSheet>[];
    HeroSheet? hero;
    for (final item in heroes) {
      if (item.id == heroId) {
        hero = item;
        break;
      }
    }

    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    final catalogAsync = ref.watch(rulesCatalogProvider);

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Katalog-Fehler: $error')),
      data: (catalog) {
        final grouped = _groupTalents(catalog.talents);
        final types = grouped.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: types.length,
          itemBuilder: (context, index) {
            final type = types[index];
            final talents = grouped[type]!..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                title: Text(type),
                subtitle: Text('${talents.length} Talente'),
                children: talents.map((talent) => _TalentTile(hero: hero!, talent: talent)).toList(growable: false),
              ),
            );
          },
        );
      },
    );
  }

  Map<String, List<TalentDef>> _groupTalents(List<TalentDef> talents) {
    final map = <String, List<TalentDef>>{};
    for (final talent in talents.where((entry) => entry.active)) {
      final type = talent.type.isNotEmpty ? talent.type : (talent.group.isNotEmpty ? talent.group : 'Ohne Typ');
      map.putIfAbsent(type, () => <TalentDef>[]).add(talent);
    }
    return map;
  }
}

class _TalentTile extends ConsumerWidget {
  const _TalentTile({required this.hero, required this.talent});

  final HeroSheet hero;
  final TalentDef talent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = hero.talents[talent.id] ?? const HeroTalentEntry();
    final attributeLabel = _buildAttributeLabel(hero.attributes, talent.attributes);

    return ListTile(
      title: Text(talent.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attributeLabel.isNotEmpty) Text(attributeLabel),
          Text(
            'Komplexitaet: ${_fallback(talent.steigerung)} | BE-Mod: ${_fallback(talent.be)} |',// eBE: ToDo Einführen mit Rüstungswerten',
          ),
          Text(
            'Talentwert: ${entry.talentValue} | Modifikator: ${entry.modifier} | Berechnet: ${_calculateTalentwert(entry)}',
          ),
          Text('Spezielle Erfahrungen: ${entry.specialExperiences}'),
          Text('Spezialisierungen: ${_fallback(entry.specializations)}'),
          Text('Sonderfertigkeiten: ${_fallback(entry.specialAbilities)}'),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        tooltip: 'Talentdaten bearbeiten',
        onPressed: () => _editTalent(context, ref, hero, talent, entry),
      ),
      isThreeLine: true,
    );
  }

  String _buildAttributeLabel(Attributes attributes, List<String> attributeNames) {
    final parts = <String>[];
    for (final name in attributeNames) {
      final value = _attributeValue(attributes, name);
      if (value != null) {
        parts.add('$name: $value');
      } else {
        parts.add('$name: ?');
      }
    }
    return parts.join(', ');
  }

  int? _attributeValue(Attributes attributes, String name) {
    final normalized = _normalizeName(name);
    switch (normalized) {
      case 'mu':
      case 'mut':
        return attributes.mu;
      case 'kl':
      case 'klugheit':
        return attributes.kl;
      case 'in':
      case 'inn':
      case 'intuition':
        return attributes.inn;
      case 'ch':
      case 'charisma':
        return attributes.ch;
      case 'ff':
      case 'fingerfertigkeit':
        return attributes.ff;
      case 'ge':
      case 'gewandheit':
        return attributes.ge;
      case 'ko':
      case 'konstitution':
        return attributes.ko;
      case 'kk':
      case 'koerperkraft':
      case 'korperkraft':
        return attributes.kk;
      default:
        return null;
    }
  }

  String _normalizeName(String value) {
    var text = value.toLowerCase();
    text = text
        .replaceAll(String.fromCharCode(228), 'ae')
        .replaceAll(String.fromCharCode(246), 'oe')
        .replaceAll(String.fromCharCode(252), 'ue')
        .replaceAll(String.fromCharCode(223), 'ss');
    text = text.replaceAll(RegExp(r'[^a-z]'), '');
    return text;
  }

  int _calculateTalentwert(HeroTalentEntry entry) {
        return entry.talentValue + entry.modifier - entry.ebe.toInt();
  }

  String _fallback(String value) {
    if (value.trim().isEmpty) {
      return '-';
    }
    return value.trim();
  }

  Future<void> _editTalent(
    BuildContext context,
    WidgetRef ref,
    HeroSheet hero,
    TalentDef talent,
    HeroTalentEntry current,
  ) async {
    final twController = TextEditingController(text: current.talentValue.toString());
    final modController = TextEditingController(text: current.modifier.toString());
    final expController = TextEditingController(text: current.specialExperiences.toString());
    final spezController = TextEditingController(text: current.specializations);
    final sfController = TextEditingController(text: current.specialAbilities);

    final result = await showDialog<HeroTalentEntry>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(talent.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: twController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Talentwert'),
                ),
                TextField(
                  controller: modController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Modifikator'),
                ),
                TextField(
                  controller: expController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Spezielle Erfahrungen'),
                ),
                TextField(
                  controller: spezController,
                  decoration: const InputDecoration(labelText: 'Spezialisierungen'),
                ),
                TextField(
                  controller: sfController,
                  decoration: const InputDecoration(labelText: 'Sonderfertigkeiten'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                int parseInt(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
                Navigator.of(context).pop(
                  HeroTalentEntry(
                    talentValue: parseInt(twController),
                    modifier: parseInt(modController),
                    specialExperiences: parseInt(expController),
                    specializations: spezController.text.trim(),
                    specialAbilities: sfController.text.trim(),
                  ),
                );
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    twController.dispose();
    modController.dispose();
    expController.dispose();
    spezController.dispose();
    sfController.dispose();

    if (result == null) {
      return;
    }

    final updatedTalents = Map<String, HeroTalentEntry>.from(hero.talents);
    updatedTalents[talent.id] = result;

    final updatedHero = hero.copyWith(talents: updatedTalents);
    await ref.read(heroActionsProvider).saveHero(updatedHero);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${talent.name} gespeichert')));
  }
}
