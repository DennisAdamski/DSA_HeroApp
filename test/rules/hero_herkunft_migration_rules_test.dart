import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/rules/derived/direkter_modifikator_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_migration_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('direkte Modifikatoren', () {
    test('Codes, Aliase und Eigenschaften werden erkannt', () {
      expect(
        erkenneDirektenModifikator('Mu + 1')?.ziel,
        'MU',
        reason: 'Gross-/Kleinschreibung und Leerzeichen',
      );
      expect(erkenneDirektenModifikator('IN+1')?.ziel, 'IN');
      expect(erkenneDirektenModifikator('AE-2')?.ziel, 'ASP');
      expect(erkenneDirektenModifikator('KE+1')?.ziel, 'KAP');
      expect(erkenneDirektenModifikator('LE+3')?.ziel, 'LEP');
      expect(erkenneDirektenModifikator('AW+1')?.ziel, 'AUSWEICHEN');
      expect(erkenneDirektenModifikator('MR-2')?.betrag, -2);
      expect(
        erkenneDirektenModifikator('KK+1')?.art,
        HeroHerkunftsModifikatorArt.eigenschaft,
      );
      expect(
        erkenneDirektenModifikator('GS+1')?.art,
        HeroHerkunftsModifikatorArt.basiswert,
      );
      expect(erkenneDirektenModifikator('Flink'), isNull);
      expect(erkenneDirektenModifikator('XY+1'), isNull);
      expect(erkenneDirektenModifikator('MU+'), isNull);
    });

    test('Eigenschaften wirken laufend und auf den Startwert', () {
      final eigenschaft = wendeDirektenModifikatorAn(
        erkenneDirektenModifikator('KK+2')!,
      );
      expect(eigenschaft.attributeMods.kk, 2);
      expect(eigenschaft.startAttributeMods.kk, 2);
      final basiswert = wendeDirektenModifikatorAn(
        erkenneDirektenModifikator('AE-2')!,
      );
      expect(basiswert.statMods.asp, -2);
      expect(basiswert.startAttributeMods.kk, 0);
    });

    test('normalisierte Basiswertcodes ignorieren Eigenschaften', () {
      expect(normalisierteBasiswertCodes('MU+1, AE-2; LE+1\nFlink, KE+0'), {
        'ASP',
        'LEP',
        'KAP',
      });
    });
  });

  group('Migration', () {
    test('Migration erhält Wiederholungen und wird reproduzierbar', () {
      const text = 'MU+1, MU+1; AE-2\nHausnotiz';
      final a = migriereHerkunftsText(HeroHerkunft.rasse, text);
      final b = migriereHerkunftsText(HeroHerkunft.rasse, text);
      expect(a.map((e) => e.id).toSet(), hasLength(4));
      expect(
        a.map((e) => e.toJson()).toList(),
        b.map((e) => e.toJson()).toList(),
      );
      expect(a[2].ziel, 'ASP');
      expect(a[2].betrag, -2);
      expect(a.last.art, HeroHerkunftsModifikatorArt.frei);
      expect(a.last.text, 'Hausnotiz');
    });

    test('gleiche Fragmente in verschiedenen Gruppen bekommen eigene IDs', () {
      final rasse = migriereHerkunftsText(HeroHerkunft.rasse, 'MU+1');
      final kultur = migriereHerkunftsText(HeroHerkunft.kultur, 'MU+1');
      expect(rasse.single.id, isNot(kultur.single.id));
    });

    test('Position vor der Filterung: Leerfragmente verschieben keine IDs', () {
      final mit = migriereHerkunftsText(HeroHerkunft.rasse, 'MU+1, ,KL+1');
      final ohne = migriereHerkunftsText(HeroHerkunft.rasse, 'MU+1,KL+1');
      expect(mit, hasLength(2));
      expect(mit.first.id, ohne.first.id);
      expect(mit.last.id, isNot(ohne.last.id));
    });

    test('benanntes Flink bleibt freier, bisher wirkungsloser Text', () {
      final eintrag = migriereHerkunftsText(
        HeroHerkunft.kultur,
        'Flink',
      ).single;
      expect(eintrag.art, HeroHerkunftsModifikatorArt.frei);
      expect(eintrag.ziel, isEmpty);
      expect(eintrag.betrag, isNull);
      expect(eintrag.text, 'Flink');
    });

    test('Projektion nennt die Fragmente in Reihenfolge', () {
      final liste = migriereHerkunftsText(HeroHerkunft.rasse, 'MU+1; AE-2');
      expect(projiziereHerkunftsText(liste), 'MU+1, AE-2');
      expect(projiziereHerkunftsText(const []), isEmpty);
    });
  });

  group('Speichern und Abgleich', () {
    test('leere Bestandsfelder werden als leere Listen persistiert', () {
      final gespeichert = herkunftZumSpeichern(const HeroBackground());
      final container = gespeichert.herkunftsModifikatoren!;
      expect(container.rasse, isEmpty);
      expect(container.kultur, isEmpty);
      expect(container.profession, isEmpty);
      expect(gespeichert.rasseModText, isEmpty);
    });

    test('Migration laesst die Texte unveraendert und ist ein Fixpunkt', () {
      const text = 'MU+1; AE-2';
      final erst = herkunftZumSpeichern(
        const HeroBackground(rasseModText: text),
      );
      expect(erst.rasseModText, text);
      expect(
        herkunftZumSpeichern(erst).herkunftsModifikatoren,
        erst.herkunftsModifikatoren,
      );
      expect(gleicheHerkunftAb(erst).abweichungen, isEmpty);
    });

    test('ohne Container rechnet die Laufzeitmigration ohne Abweichung', () {
      const bestand = HeroBackground(kulturModText: 'KK+1, Flink');
      final abgleich = gleicheHerkunftAb(bestand);
      expect(abgleich.abweichungen, isEmpty);
      expect(abgleich.eintraege.kultur, hasLength(2));
      expect(bestand.herkunftsModifikatoren, isNull);
    });

    test('Trennerwechsel ist keine Abweichung', () {
      final basis = herkunftZumSpeichern(
        const HeroBackground(rasseModText: 'MU+1, KL+1'),
      );
      final neu = basis.copyWith(rasseModText: 'MU+1;\nKL+1 ');
      expect(gleicheHerkunftAb(neu).abweichungen, isEmpty);
    });

    test('anderes Feld speichern löst fremden Herkunftstext nicht auf', () {
      final basis = herkunftZumSpeichern(
        const HeroBackground(rasseModText: 'MU+1'),
      );
      final fremd = basis.copyWith(rasseModText: 'MU+3');
      final gespeichert = herkunftZumSpeichern(fremd);
      expect(gespeichert.rasseModText, 'MU+3');
      expect(gleicheHerkunftAb(gespeichert).abweichungen.keys, [
        HeroHerkunft.rasse,
      ]);
      final geloest = loeseHerkunftsAbweichung(
        gespeichert,
        HeroHerkunft.rasse,
        HerkunftsAbgleichWahl.listeBehalten,
      );
      expect(geloest.rasseModText, 'MU+1');
      expect(gleicheHerkunftAb(geloest).abweichungen, isEmpty);
    });

    test('Text uebernehmen baut nur die betroffene Gruppe neu auf', () {
      final basis = herkunftZumSpeichern(
        const HeroBackground(rasseModText: 'MU+1', kulturModText: 'KL+1'),
      );
      final fremd = basis.copyWith(rasseModText: 'MU+3, Hausnotiz');
      final geloest = loeseHerkunftsAbweichung(
        fremd,
        HeroHerkunft.rasse,
        HerkunftsAbgleichWahl.textUebernehmen,
      );
      final container = geloest.herkunftsModifikatoren!;
      expect(container.rasse.map((e) => e.text), ['MU+3', 'Hausnotiz']);
      expect(container.rasse.first.betrag, 3);
      expect(container.kultur, basis.herkunftsModifikatoren!.kultur);
      expect(geloest.rasseModText, 'MU+3, Hausnotiz');
      expect(gleicheHerkunftAb(geloest).abweichungen, isEmpty);
    });

    test('Abweichung nur in einer Gruppe, die andere bleibt unberuehrt', () {
      final basis = herkunftZumSpeichern(
        const HeroBackground(rasseModText: 'MU+1', kulturModText: 'KL+1'),
      );
      final fremd = basis.copyWith(kulturModText: 'KL+2');
      expect(gleicheHerkunftAb(fremd).abweichungen.keys, [HeroHerkunft.kultur]);
    });

    test('leere Liste gegen vorhandenen Text ist eine Abweichung', () {
      final basis = herkunftZumSpeichern(const HeroBackground());
      final fremd = basis.copyWith(professionModText: 'MR+1');
      expect(gleicheHerkunftAb(fremd).abweichungen.keys, [
        HeroHerkunft.profession,
      ]);
    });

    test('unbekannte Version wird weder migriert noch abgeglichen', () {
      final roh = HeroHerkunftsModifikatoren.fromJson(<String, Object?>{
        'formatVersion': 900,
      });
      final background = HeroBackground(
        rasseModText: 'MU+1',
        herkunftsModifikatoren: roh,
      );
      expect(herkunftZumSpeichern(background), same(background));
      expect(gleicheHerkunftAb(background).abweichungen, isEmpty);
      expect(
        () => loeseHerkunftsAbweichung(
          background,
          HeroHerkunft.rasse,
          HerkunftsAbgleichWahl.textUebernehmen,
        ),
        throwsStateError,
      );
    });

    test(
      'nicht verstandene Gruppe wird nicht verglichen und bleibt gesperrt',
      () {
        final roh = HeroHerkunftsModifikatoren.fromJson(<String, Object?>{
          'formatVersion': 1,
          'rasse': 'unlesbar',
          'kultur': <Object?>[],
          'profession': <Object?>[],
        });
        final background = HeroBackground(
          rasseModText: 'MU+1',
          herkunftsModifikatoren: roh,
        );
        expect(gleicheHerkunftAb(background).abweichungen, isEmpty);
        expect(
          () => loeseHerkunftsAbweichung(
            background,
            HeroHerkunft.rasse,
            HerkunftsAbgleichWahl.listeBehalten,
          ),
          throwsStateError,
        );
      },
    );
  });
}
