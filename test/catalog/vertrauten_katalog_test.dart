import 'dart:convert';
import 'dart:io';

import 'package:dsa_heldenverwaltung/catalog/vertrauten_katalog.dart';
import 'package:dsa_heldenverwaltung/catalog/vertrautenmagie_preset.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prueft den Vertrautenkatalog (WdZ S. 123–128, ZBA S. 19–21).
///
/// Die Dart-Konstanten sind die Quelle; das JSON unter `assets/` ist ihr
/// Spiegel. Querverweise (Zauber auf Preset-Rituale, Arten auf
/// Ausbildungen) stehen nur als Zeichenketten im Katalog.
void main() {
  test('spiegelt das JSON unter assets/catalogs', () {
    final datei = File('assets/catalogs/house_rules_v1/vertrauten.json');
    final json = jsonDecode(datei.readAsStringSync(encoding: utf8));

    expect(vertrautenKatalogJson(), json);
  });

  test('IDs sind eindeutig und tragen ihr Praefix', () {
    final arten = kVertrautenArten.map((a) => a.id).toList();
    final zauber = kVertrautenZauber.map((z) => z.id).toList();
    final ausbildungen = kVertrautenAusbildungen.map((a) => a.id).toList();
    final fertigkeiten = kVertrautenFertigkeiten.map((f) => f.id).toList();

    for (final (ids, praefix) in <(List<String>, String)>[
      (arten, 'vart_'),
      (zauber, 'vzaub_'),
      (ausbildungen, 'vausb_'),
      (fertigkeiten, 'vfert_'),
    ]) {
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, everyElement(startsWith(praefix)));
    }
  });

  test('die zwoelf ueblichen Arten mit Bindungskosten (WdZ S. 123)', () {
    expect(kVertrautenArten, hasLength(12));
    final teuer = kVertrautenArten
        .where((a) => a.bindungskosten == 100)
        .map((a) => a.id)
        .toSet();
    expect(teuer, <String>{'vart_kroete', 'vart_spinne'});
    expect(
      kVertrautenArten.where((a) => a.bindungskosten != 100),
      everyElement(
        isA<VertrautenArtDef>().having(
          (a) => a.bindungskosten,
          'bindungskosten',
          80,
        ),
      ),
    );
  });

  test('jede Art fuehrt alle acht Eigenschaften mit Start <= Maximum', () {
    for (final art in kVertrautenArten) {
      expect(
        art.eigenschaften.keys,
        kVertrautenEigenschaftKeys,
        reason: art.id,
      );
      for (final spanne in art.eigenschaften.values) {
        expect(spanne.start, lessThanOrEqualTo(spanne.max), reason: art.id);
      }
    }
  });

  test('jeder Vertrautenzauber hat ein Ritual im Preset und umgekehrt', () {
    final preset = kVertrautenmagiePresetCategory.rituals
        .map((r) => r.name)
        .toSet();

    expect(kVertrautenZauber.map((z) => z.name).toSet(), preset);
    for (final zauber in kVertrautenZauber) {
      for (final id in zauber.tierartIds) {
        expect(vertrautenArt(id), isNotNull, reason: '${zauber.id} -> $id');
      }
    }
  });

  test('nur Zwiegespraech und Kroetenschlag kommen mit der Bindung', () {
    expect(
      kVertrautenZauber.where((z) => z.mitBindung).map((z) => z.id).toSet(),
      <String>{'vzaub_zwiegespraech', 'vzaub_kroetenschlag'},
    );
  });

  test('Ausbildungsverweise der Arten zeigen auf waehlbare Stufen', () {
    for (final art in kVertrautenArten) {
      for (final id in art.ausbildungIds) {
        final stufe = vertrautenAusbildung(id);
        expect(stufe, isNotNull, reason: '${art.id} -> $id');
        expect(stufe!.fuerVertraute, isTrue, reason: '${art.id} -> $id');
      }
    }
  });

  test('das Kampftier ist fuer Vertraute nicht waehlbar (WdZ S. 124)', () {
    expect(vertrautenAusbildung('vausb_kampftier')!.fuerVertraute, isFalse);
    expect(
      kVertrautenAusbildungen.where((a) => !a.fuerVertraute),
      hasLength(1),
    );
  });

  test('Ausbildung kostet TaP* x 10, Fertigkeiten 10–50 AP', () {
    expect(vertrautenAusbildung('vausb_jagdtier')!.apKosten, 400);
    expect(vertrautenFertigkeit('vfert_komm')!.apVorschlag, 10);
    expect(vertrautenFertigkeit('vfert_laut')!.apVorschlag, 15);
    expect(vertrautenFertigkeit('vfert_apport')!.apVorschlag, 25);
    expect(vertrautenFertigkeit('vfert_trick')!.apVorschlag, 45);
    for (final fertigkeit in kVertrautenFertigkeiten) {
      final id = fertigkeit.voraussetzungId;
      if (id.isNotEmpty) {
        expect(vertrautenFertigkeit(id), isNotNull, reason: fertigkeit.id);
      }
    }
  });
}
