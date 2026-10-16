import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ueberzahl_rules.dart';

void main() {
  // Kämpfende Gegner mit Bindung; [extra] überschreibt einzelne Felder.
  Gefechtsbegegnung begegnung(
    Map<String, String?> bindungen, {
    Map<String, Gefechtsgegner Function(Gefechtsgegner)> extra = const {},
  }) {
    return Gefechtsbegegnung(
      gegner: {
        for (final e in bindungen.entries)
          e.key: (extra[e.key] ?? (g) => g)(
            Gefechtsgegner(id: e.key, name: e.key, ini: 10, bindet: e.value),
          ),
      },
    );
  }

  test('Nur kämpfende, bindende und nicht sehr große Gegner zählen', () {
    final b = begegnung(
      {'a': 'h', 'b': 'h', 'c': null, 'd': 'h', 'e': 'h'},
      extra: {
        'd': (g) => g.copyWith(status: GefechtsgegnerStatus.kampfunfaehig),
        'e': (g) => g.copyWith(groesse: GefechtsGroesse.sehrGross),
      },
    );
    expect(gefechtsUeberzahl(b, eigeneNahkaempfer: 1).gegner, 2);
    expect(gefechtsVerteidigerlage(b, 'h').gegnerIds, ['a', 'b']);
  });

  test('INI-Bonus je Kopf Überzahl, höchstens +4, für die größere Seite', () {
    final sieben = begegnung({for (var i = 0; i < 7; i++) 'g$i': 'h'});
    final u = gefechtsUeberzahl(sieben, eigeneNahkaempfer: 5);
    expect(u.iniBonusGegner, 2);
    expect(u.iniBonusEigene, 0);
    expect(u.ueberzahlGegner, 2);
    expect(gefechtsUeberzahl(sieben, eigeneNahkaempfer: 1).iniBonusGegner, 4);
    final zwei = begegnung({'a': 'h', 'b': 'x'});
    expect(gefechtsUeberzahl(zwei, eigeneNahkaempfer: 4).iniBonusEigene, 2);
    expect(gefechtsUeberzahl(zwei, eigeneNahkaempfer: 2).iniBonusEigene, 0);
    expect(
      () => gefechtsUeberzahl(zwei, eigeneNahkaempfer: -1),
      throwsArgumentError,
    );
  });

  test('Abwehr: PA −1 je weiterem Gegner, Ausweichen −2, drei im Blick', () {
    int pa(int n) =>
        gefechtsAbwehrErschwernisWeitereGegner(n, ausweichen: false);
    int aw(int n) =>
        gefechtsAbwehrErschwernisWeitereGegner(n, ausweichen: true);
    expect([for (var n = 0; n <= 5; n++) pa(n)], [0, 0, 1, 2, 2, 2]);
    expect([for (var n = 0; n <= 5; n++) aw(n)], [0, 0, 2, 4, 4, 4]);
    final l = gefechtsVerteidigerlage(
      begegnung({'a': 'h', 'b': 'h', 'c': 'h', 'd': 'h', 'e': 'x'}),
      'h',
    );
    expect(l.gegner, 4);
    expect(l.imRuecken, 1);
    expect(l.paradeErschwernis, 2);
    expect(l.ausweichenErschwernis, 4);
    expect(l.gegnerInUeberzahl, isTrue);
    final allein = gefechtsVerteidigerlage(begegnung({'a': 'h'}), 'h');
    expect(allein.gegnerInUeberzahl, isFalse);
    expect(allein.paradeErschwernis, 0);
  });

  test('AT +1 ab zwei Angreifern auf dasselbe Ziel', () {
    expect(gefechtsAngriffInUeberzahl(angreiferAufZiel: 1), isFalse);
    expect(gefechtsAngriffInUeberzahl(angreiferAufZiel: 2), isTrue);
  });

  test('Taktik: Aufheben kostet die doppelte Überzahl und nimmt den Bonus', () {
    final b = begegnung({for (var i = 0; i < 7; i++) 'g$i': 'h'});
    final u = gefechtsUeberzahl(b, eigeneNahkaempfer: 5);
    expect(gefechtsTaktikAufhebungErschwernis(u), 4);
    final aufgehoben = setzeGefechtstaktik(
      b,
      const Gefechtstaktik(anfuehrerId: 'jandara', ueberzahlAufgehoben: true),
    );
    final danach = gefechtsUeberzahl(aufgehoben, eigeneNahkaempfer: 5);
    expect(danach.iniBonusGegner, 0);
    expect(danach.aufgehoben, isTrue);
    expect(danach.ueberzahlGegner, 2);
    expect(
      () => setzeGefechtstaktik(
        aufgehoben,
        const Gefechtstaktik(anfuehrerId: 'jandara'),
      ),
      throwsStateError,
    );
  });

  test('Taktik: TaP* gleichmäßig, höchstens 6, Misslingen −1 je Kopf', () {
    // WdS-Beispiel: 4 TaP* an Alrigio und Dana.
    expect(
      gefechtsTaktikVerteilung(tapStern: 4, empfaenger: ['alrigio', 'dana']),
      {'alrigio': 2, 'dana': 2},
    );
    expect(
      gefechtsTaktikVerteilung(tapStern: 9, empfaenger: ['a', 'b', 'c', 'd']),
      {'a': 2, 'b': 2, 'c': 1, 'd': 1},
    );
    expect(gefechtsTaktikVerteilung(tapStern: 3, empfaenger: []), isEmpty);
    expect(
      () => gefechtsTaktikVerteilung(tapStern: -1, empfaenger: ['a']),
      throwsArgumentError,
    );
    expect(gefechtsTaktikMisslungen(['a', 'b']), {'a': -1, 'b': -1});
    const leer = Gefechtsbegegnung();
    expect(
      setzeGefechtstaktik(
        leer,
        const Gefechtstaktik(anfuehrerId: 'j', iniBoni: {'a': 3, 'b': 3}),
      ).taktik!.iniBoni,
      {'a': 3, 'b': 3},
    );
    for (final falsch in [
      const Gefechtstaktik(anfuehrerId: 'j', iniBoni: {'a': 4, 'b': 3}),
      const Gefechtstaktik(anfuehrerId: 'j', iniBoni: {'j': 2}),
      const Gefechtstaktik(
        anfuehrerId: 'j',
        ueberzahlAufgehoben: true,
        iniBoni: {'a': 1},
      ),
      const Gefechtstaktik(anfuehrerId: 'j', iniBoni: {'a': -2}),
      const Gefechtstaktik(anfuehrerId: ''),
    ]) {
      expect(() => setzeGefechtstaktik(leer, falsch), throwsArgumentError);
    }
  });
}
