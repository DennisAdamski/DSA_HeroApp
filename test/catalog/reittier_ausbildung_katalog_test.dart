import 'dart:convert';
import 'dart:io';

import 'package:dsa_heldenverwaltung/catalog/reittier_ausbildung_katalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/reittier_ausbildungsstufe.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_reference_names.dart';

/// Prueft den Reittier-Ausbildungskatalog (ZBA S. 32–40).
///
/// Die Dart-Konstanten sind die Quelle; das JSON unter `assets/` ist ihr
/// Spiegel. Die Querverweise (Varianten- und Vorstufen-SF, Talente) stehen
/// nur als Zeichenketten im Katalog und fielen ohne diesen Test erst im
/// Betrieb auf.
void main() {
  test('spiegelt das JSON unter assets/catalogs', () {
    final datei = File(
      'assets/catalogs/house_rules_v1/reittier_ausbildung.json',
    );
    final json = jsonDecode(datei.readAsStringSync(encoding: utf8));

    expect(reittierAusbildungsKatalogJson(), json);
  });

  test('IDs sind eindeutig und tragen ihr Praefix', () {
    final varianten = kReittierVarianten.map((v) => v.id).toList();
    final sf = kPferdeSonderfertigkeiten.map((s) => s.id).toList();
    final unarten = kPferdeUnarten.map((u) => u.id).toList();

    expect(varianten.toSet(), hasLength(varianten.length));
    expect(sf.toSet(), hasLength(sf.length));
    expect(unarten.toSet(), hasLength(unarten.length));
    expect(varianten, everyElement(startsWith('pvar_')));
    expect(sf, everyElement(startsWith('psf_')));
    expect(unarten, everyElement(startsWith('punart_')));
  });

  test('jede Varianten- und Vorstufen-SF zeigt auf einen Eintrag', () {
    for (final variante in kReittierVarianten) {
      for (final id in variante.sfIds) {
        expect(pferdeSf(id), isNotNull, reason: '${variante.id} -> $id');
      }
      expect(variante.sfIds.toSet(), hasLength(variante.sfIds.length));
    }
    for (final sf in kPferdeSonderfertigkeiten) {
      for (final id in sf.voraussetzungSfIds) {
        expect(pferdeSf(id), isNotNull, reason: '${sf.id} -> $id');
      }
    }
    // Trampeln kommt nur ueber das schwere Streitross (ZBA S. 32, 40).
    expect(
      reittierVariante('pvar_schweres_streitross')!.sfIds,
      contains('psf_trampeln'),
    );
  });

  test('jede Ausbildungsprobe nennt ein echtes Talent', () {
    final talente = <String>{
      for (final talent in ladeKatalogDatei('talente.json'))
        talent['id'] as String,
    };
    for (final schritt in kReittierStufenschritte) {
      for (final probe in schritt.proben) {
        expect(talente, contains(probe.talentId));
        if (probe.alternativeTalentId != null) {
          expect(talente, contains(probe.alternativeTalentId));
        }
      }
    }
  });

  test('jeder Ausbildungsschritt ist genau einmal beschrieben (ZBA S. 34)', () {
    final schluessel = kReittierStufenschritte
        .map((s) => '${s.von.name}>${s.nach.name}:${s.art.name}')
        .toList();

    expect(schluessel.toSet(), hasLength(schluessel.length));
    expect(schluessel, hasLength(5));
    // Laendliche Ausbildung endet bei „erprobt“.
    expect(
      kReittierStufenschritte.where(
        (s) =>
            s.art == ReittierAusbildungsart.laendlich &&
            s.nach == ReittierAusbildungsstufe.geschult,
      ),
      isEmpty,
    );
  });

  test('jede Stufe hat genau einen Reiten-Modifikator (ZBA S. 35)', () {
    expect(
      kReittierReitenModifikatoren.map((m) => m.stufe),
      ReittierAusbildungsstufe.values,
    );
  });

  test('Kampfpferde sind die Streit- und Kriegsrosse samt Schuetzen- und '
      'Streitwagenpferd', () {
    final kampfpferde = kReittierVarianten
        .where((v) => v.kampfpferd)
        .map((v) => v.id)
        .toSet();

    expect(kampfpferde, <String>{
      'pvar_leichtes_streitross',
      'pvar_mittelschweres_streitross',
      'pvar_schweres_streitross',
      'pvar_tulamidisches_kriegspferd',
      'pvar_novadisches_kriegspferd',
      'pvar_schuetzenpferd',
      'pvar_streitwagenpferd',
    });
  });

  test('Gezielter Biss ist allgemein (ZBA S. 39)', () {
    expect(pferdeSf('psf_gezielter_biss')!.typ, PferdeSfTyp.allgemein);
  });
}
