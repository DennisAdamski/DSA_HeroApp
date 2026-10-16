import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_ausbildung_aenderung_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sofortbuchungen an der Reittier-Ausbildung: frischer Stand, keine
/// Dubletten, nichts anderes am Helden veraendert.
void main() {
  const geschultSchritt = ReittierAusbildungsschritt(
    nach: ReittierAusbildungsstufe.geschult,
    art: ReittierAusbildungsart.fundiert,
    fehlschlaege: 1,
    ausbilder: 'Alva',
  );
  const pferd = HeroCompanion(
    id: 'p1',
    name: 'Falbe',
    typ: BegleiterTyp.reittier,
    sonderfertigkeiten: <HeroCompanionSonderfertigkeit>[
      HeroCompanionSonderfertigkeit(name: 'Steigen', beschreibung: 'eigene'),
    ],
    reittierAusbildung: ReittierAusbildung(
      ausgangsstufe: ReittierAusbildungsstufe.erprobt,
      ausgangsart: ReittierAusbildungsart.fundiert,
    ),
  );
  const hund = HeroCompanion(id: 'h1', name: 'Bello');
  final held = HeroSheet(
    id: 'held',
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
    companions: const <HeroCompanion>[hund, pferd],
  );

  test('der Schritt nach „geschult“ setzt die Variante und uebernimmt ihre '
      'fehlenden SF', () {
    final neu = schliesseAusbildungsschrittAb(
      pferd,
      erwarteteSchrittanzahl: 0,
      schritt: geschultSchritt,
      varianteId: 'pvar_leichtes_streitross',
    );
    final sf = neu.sonderfertigkeiten;

    expect(neu.reittierAusbildung!.schritte, <ReittierAusbildungsschritt>[
      geschultSchritt,
    ]);
    expect(neu.reittierAusbildung!.varianteId, 'pvar_leichtes_streitross');
    // Steigen stand schon als Freitext und kommt nicht doppelt.
    expect(sf.where((s) => s.name == 'Steigen'), hasLength(1));
    expect(sf.first.beschreibung, 'eigene');
    expect(sf, hasLength(10));
    expect(sf.last.katalogId, 'psf_sprungsicherheit');
  });

  test('ohne Uebernahme bleiben die SF unveraendert', () {
    final neu = schliesseAusbildungsschrittAb(
      pferd,
      erwarteteSchrittanzahl: 0,
      schritt: geschultSchritt,
      varianteId: 'pvar_leichtes_streitross',
      varianteSfUebernehmen: false,
    );

    expect(neu.sonderfertigkeiten, pferd.sonderfertigkeiten);
  });

  test('ein inzwischen geaenderter Stand wird abgewiesen', () {
    expect(
      () => schliesseAusbildungsschrittAb(
        pferd,
        erwarteteSchrittanzahl: 1,
        schritt: geschultSchritt,
      ),
      throwsStateError,
    );
    expect(
      () => schliesseAusbildungsschrittAb(
        hund,
        erwarteteSchrittanzahl: 0,
        schritt: geschultSchritt,
      ),
      throwsStateError,
    );
  });

  test('der letzte Schritt laesst sich zuruecknehmen', () {
    final gebucht = schliesseAusbildungsschrittAb(
      pferd,
      erwarteteSchrittanzahl: 0,
      schritt: geschultSchritt,
    );
    final zurueck = nimmLetztenAusbildungsschrittZurueck(
      gebucht,
      erwarteteSchrittanzahl: 1,
    );

    expect(zurueck.reittierAusbildung!.schritte, isEmpty);
    expect(
      () => nimmLetztenAusbildungsschrittZurueck(
        zurueck,
        erwarteteSchrittanzahl: 0,
      ),
      throwsStateError,
    );
  });

  test('eine Pferde-SF wird einmal mit Katalog-ID eingetragen', () {
    final neu = erlernePferdeSf(pferd, 'psf_stopp');

    expect(neu.sonderfertigkeiten.last.katalogId, 'psf_stopp');
    expect(neu.sonderfertigkeiten.last.name, 'Stopp');
    expect(() => erlernePferdeSf(neu, 'psf_stopp'), throwsStateError);
    expect(() => erlernePferdeSf(pferd, 'psf_unbekannt'), throwsStateError);
  });

  test('Buchungen am Helden aendern nur den einen Begleiter', () {
    final gebucht = buchePferdeSf(held, begleiterId: 'p1', sfId: 'psf_wacht');
    final geschult = bucheAusbildungsschritt(
      gebucht,
      begleiterId: 'p1',
      erwarteteSchrittanzahl: 0,
      schritt: geschultSchritt,
    );

    expect(geschult.companions.first, hund);
    expect(geschult.companions.last.sonderfertigkeiten, hasLength(2));
    expect(geschult.companions.last.reittierAusbildung!.schritte, hasLength(1));
    expect(
      bucheAusbildungsschrittZurueck(
        geschult,
        begleiterId: 'p1',
        erwarteteSchrittanzahl: 1,
      ).companions.last.reittierAusbildung!.schritte,
      isEmpty,
    );
    expect(
      () => buchePferdeSf(held, begleiterId: 'weg', sfId: 'psf_wacht'),
      throwsStateError,
    );
  });
}
