import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ausbildungsstand von Reittieren am Begleitermodell.
///
/// Wichtig ist vor allem das „nur bei Belegung“: Ein Begleiter ohne
/// Ausbildung muss byte- und hashgleich bleiben, sonst meldete der
/// Konto-Sync beim naechsten Speichern Konflikte.
void main() {
  const ausbildung = ReittierAusbildung(
    ausgangsstufe: ReittierAusbildungsstufe.erprobt,
    ausgangsart: ReittierAusbildungsart.fundiert,
    varianteId: 'pvar_leichtes_streitross',
    schritte: <ReittierAusbildungsschritt>[
      ReittierAusbildungsschritt(
        nach: ReittierAusbildungsstufe.geschult,
        art: ReittierAusbildungsart.fundiert,
        fehlschlaege: 3,
        ausbilder: 'Zureiterin Alva',
        notiz: 'Gestüt Ferdok',
      ),
    ],
    unartIds: <String>['punart_treten'],
  );

  test('Rundlauf mit allen Feldern', () {
    final json = ausbildung.toJson();

    expect(ReittierAusbildung.fromJson(json), ausbildung);
    expect(json['schritte'], hasLength(1));
    expect(json['unarten'], <String>['punart_treten']);
  });

  test('ein Mindeststand schreibt nur Stufe und Art', () {
    expect(const ReittierAusbildung().toJson(), <String, dynamic>{
      'ausgangsstufe': 'ungearbeitet',
      'ausgangsart': 'laendlich',
    });
    expect(
      const ReittierAusbildungsschritt(
        nach: ReittierAusbildungsstufe.unerfahren,
        art: ReittierAusbildungsart.laendlich,
      ).toJson(),
      <String, dynamic>{'nach': 'unerfahren', 'art': 'laendlich'},
    );
  });

  test('der Begleiter traegt die Ausbildung nur bei Belegung', () {
    const pferd = HeroCompanion(id: 'p1', typ: BegleiterTyp.reittier);
    final mit = pferd.copyWith(reittierAusbildung: ausbildung);

    expect(pferd.toJson().containsKey('reittierAusbildung'), isFalse);
    expect(HeroCompanion.fromJson(mit.toJson()), mit);
    expect(HeroCompanion.fromJson(pferd.toJson()).reittierAusbildung, isNull);
    // copyWith ohne Angabe behaelt, ausdrueckliches null entfernt.
    expect(mit.copyWith(name: 'Falbe').reittierAusbildung, ausbildung);
    expect(mit.copyWith(reittierAusbildung: null).reittierAusbildung, isNull);
  });

  test('ein Bestandsbegleiter behaelt seinen Inhalts-Hash', () {
    final held = HeroSheet(
      id: 'h1',
      name: 'Alrik',
      level: 1,
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      ),
      companions: const <HeroCompanion>[
        HeroCompanion(
          id: 'p1',
          name: 'Falbe',
          typ: BegleiterTyp.reittier,
          sonderfertigkeiten: <HeroCompanionSonderfertigkeit>[
            HeroCompanionSonderfertigkeit(name: 'Stopp'),
          ],
        ),
      ],
    );
    final geladen = HeroSheet.fromJson(held.toJson());

    expect(geladen.toJson(), held.toJson());
    expect(heroContentHash(geladen), heroContentHash(held));
    final sf = (held.toJson()['companions'] as List).single as Map;
    expect(
      ((sf['sonderfertigkeiten'] as List).single as Map).containsKey(
        'katalogId',
      ),
      isFalse,
    );
  });

  test('Katalog-SF behalten Name und Beschreibung fuer aeltere Versionen', () {
    const sf = HeroCompanionSonderfertigkeit(
      name: 'Steigen',
      beschreibung: 'Steigt auf Kommando.',
      katalogId: 'psf_steigen',
    );

    expect(HeroCompanionSonderfertigkeit.fromJson(sf.toJson()), sf);
    expect(sf.toJson()['name'], 'Steigen');
  });
}
