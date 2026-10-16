import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_specialization_hints.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_talent_groups.dart';

import '../test_support/real_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Empfehlungen finden Talente unabhängig von Leerzeichen und Groß-/Kleinschreibung', () {
    expect(
      talentSpezialisierungsHinweis('Götter / Kulte')?.freieWahl,
      'je nach Glaubensausrichtung',
    );
    expect(
      talentSpezialisierungsHinweis('Sich Verstecken')?.vorschlaege,
      contains('Wüste'),
    );
    expect(talentSpezialisierungsHinweis('Klettern')?.vorschlaege, [
      'Bergsteigen',
      'Eisklettern',
      'Freiklettern',
      'Seilklettern',
    ]);
    expect(talentSpezialisierungsHinweis('Unbekanntes Talent'), isNull);
  });

  test('Talente ohne Spezialisierung sind als solche gekennzeichnet', () {
    for (final name in ['Skifahren', 'Zechen', 'Philosophie', 'Seiler']) {
      final hinweis = talentSpezialisierungsHinweis(name)!;
      expect(hinweis.keine, isTrue, reason: name);
      expect(hinweis.hatVorschlaege, isFalse, reason: name);
    }
  });

  test('jedes Nicht-Kampftalent des echten Katalogs ist behandelt', () async {
    final katalog = (await ladeEchtenRegelkatalog()).catalog;
    final ohne = <String>[];
    for (final TalentDef def in katalog.talents) {
      final kampf =
          def.weaponCategory.isNotEmpty ||
          def.type == 'nahkampf' ||
          def.type == 'fernkampf';
      if (kampf) continue;
      // Gaben außer der Tierempathie kennen keine Spezialisierungen.
      if (def.group == 'Gabe' && def.name != 'Tierempathie') continue;
      if (talentSpezialisierungsHinweis(def.name) == null) ohne.add(def.name);
    }
    expect(ohne, isEmpty, reason: 'Ohne Eintrag: $ohne');
  });

  test('Empfehlungen enthalten keine Dopplungen', () async {
    final katalog = (await ladeEchtenRegelkatalog()).catalog;
    for (final def in katalog.talents) {
      final hinweis = talentSpezialisierungsHinweis(def.name);
      if (hinweis == null) continue;
      expect(
        hinweis.vorschlaege.toSet().length,
        hinweis.vorschlaege.length,
        reason: def.name,
      );
    }
  });

  test('echte Talentgruppen landen in eigenen Gruppen', () async {
    final katalog = (await ladeEchtenRegelkatalog()).catalog;
    final gruppen = <TalentGruppe>{};
    for (final def in katalog.talents) {
      final gruppe = talentGruppeFuerDefinition(def);
      expect(gruppe, isNot(TalentGruppe.sonstige), reason: def.name);
      gruppen.add(gruppe);
    }
    expect(gruppen, {
      TalentGruppe.kampf,
      TalentGruppe.koerper,
      TalentGruppe.gesellschaft,
      TalentGruppe.natur,
      TalentGruppe.wissen,
      TalentGruppe.handwerk,
      TalentGruppe.gaben,
    });
  });

  test('jede Gruppe hat ein eigenes Symbol und eine eigene Farbe', () {
    final symbole = {for (final g in TalentGruppe.values) g.icon};
    final farben = {
      for (final g in TalentGruppe.values) g.akzent(Brightness.light),
    };
    expect(symbole.length, TalentGruppe.values.length);
    expect(farben.length, TalentGruppe.values.length);
  });
}
