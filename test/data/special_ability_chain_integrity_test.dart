import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_chain_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';

// Only definitions count: prerequisite references also contain a name.
Iterable<Map<String, dynamic>> _definitions(dynamic value) sync* {
  if (value is List) {
    for (final item in value) {
      yield* _definitions(item);
    }
  } else if (value is Map<String, dynamic>) {
    if (value['id'] != null && value['typ'] == 'sonderfertigkeit') {
      yield value;
    }
    for (final child in value.values) {
      yield* _definitions(child);
    }
  }
}

void main() {
  test(
    'real five-stage chain unlocks each successor after its predecessor',
    () {
      final raw = jsonDecode(
        File(
          'assets/catalogs/house_rules_v1/'
          'magische_sonderfertigkeiten.json',
        ).readAsStringSync(),
      ) as List;
      final definitions = raw
          .map((e) => SpecialAbilityDef.fromJson(e))
          .toList();
      final chain = buildSpecialAbilityChains(definitions)
          .singleWhere((c) => c.id == 'spontane_regeneration');
      final owned = <String>['Pfad der Uralten'];
      List<RequirementCheckResult> check(SpecialAbilityDef def) =>
          evaluateRequirements(
            def.voraussetzungenStruktur,
            HeroRequirementContext(
              eigenschaften: {'KO': 20},
              rasse: 'Achaz',
              sonderfertigkeiten: owned,
            ),
          );
      for (var i = 0; i < chain.stufen.length; i++) {
        final next = naechsteKettenstufe(chain, owned)!;
        expect(next.kette!.stufe, i + 1);
        expect(offeneVoraussetzungen(check(next)), isEmpty);
        if (i + 1 < chain.stufen.length) {
          expect(offeneVoraussetzungen(check(chain.stufen[i + 1])), isNotEmpty);
        }
        owned.add(next.name);
      }
      expect(naechsteKettenstufe(chain, owned), isNull);
    },
  );
  test('all numbered catalog abilities have complete explicit chains', () {
    final entries = <Map<String, dynamic>>[];
    for (final file in Directory(
      'assets/catalogs/house_rules_v1',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      entries.addAll(_definitions(jsonDecode(file.readAsStringSync())));
    }
    final numbered = RegExp(r'\s+[IVXLCDM]+$');
    for (final entry in entries.where((e) => numbered.hasMatch(e['name']))) {
      expect(entry['kette'], isNotNull, reason: entry['name']);
    }
    final chains = <String, List<Map<String, dynamic>>>{};
    for (final entry in entries.where((e) => e['kette'] != null)) {
      chains.putIfAbsent(entry['kette']['id'], () => []).add(entry);
    }
    expect(chains['spontane_regeneration'], hasLength(5));
    expect(chains['zweihaendiger_kampf'], hasLength(3));
    expect(chains['arkane_sensitivitaet'], hasLength(2));
    for (final chain in chains.values) {
      chain.sort(
        (a, b) =>
            (a['kette']['stufe'] as int).compareTo(b['kette']['stufe'] as int),
      );
      for (var i = 0; i < chain.length; i++) {
        final entry = chain[i];
        expect(entry['kette']['stufe'], i + 1, reason: entry['name']);
        final requirements = (entry['voraussetzungen_struktur'] as List?) ?? [];
        for (final later in chain.skip(i)) {
          expect(
            requirements.any(
              (r) =>
                  r['art'] == 'sonderfertigkeit' &&
                  (r['name'] == later['name'] ||
                      (r['name'] == chain.first['kette']['label'] &&
                          r['stufe'] == later['kette']['stufe'])),
            ),
            false,
            reason: 'Zyklische Stufenabhängigkeit: ${entry['name']}',
          );
        }
        if (i == 0) continue;
        final previous = chain[i - 1]['name'];
        expect(
          requirements.any(
            (r) =>
                r['art'] == 'sonderfertigkeit' &&
                (r['name'] == previous ||
                    (r['name'] == chain.first['kette']['label'] &&
                        r['stufe'] == i)),
          ),
          true,
          reason: '${entry['name']} -> $previous',
        );
      }
    }
  });
}
