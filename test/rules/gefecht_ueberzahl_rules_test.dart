import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
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
  test('Eigene Seite: Helden, Gruppe, manuelle Mitstreiter ohne Doppel', () {
    final b = Gefechtsbegegnung(
      gegner: {'o': const Gefechtsgegner(id: 'o', name: 'Oger', ini: 7)},
      mitstreiter: {
        'extern:y': const Gefechtsmitstreiter(
          id: 'extern:y',
          name: 'Yasmina',
          beteiligung: GefechtsBeteiligung.fernkampf,
          zielId: 'o',
        ),
        'h2': const Gefechtsmitstreiter(
          id: 'h2',
          name: 'Bosper',
          beteiligung: GefechtsBeteiligung.nichtDabei,
        ),
        'm': const Gefechtsmitstreiter(id: 'm', name: 'Söldner', zielId: 'o'),
      },
    );
    final seite = gefechtsEigeneSeite(
      b,
      helden: [
        (id: 'h1', name: 'Alrike', zielId: 'o'),
        (id: 'h2', name: 'Bosper', zielId: 'o'),
        (id: 'h1', name: 'Alrike', zielId: 'o'),
      ],
      externe: [
        (id: 'y', name: 'Yasmina', ini: 12),
        (id: 'z', name: 'Haldor', ini: 9),
      ],
    );
    expect(seite.map((t) => t.id), ['h1', 'h2', 'extern:y', 'extern:z', 'm']);
    expect(seite[1].beteiligung, GefechtsBeteiligung.nichtDabei);
    expect(seite[2].beteiligung, GefechtsBeteiligung.fernkampf);
    expect(seite[2].ini, 12);
    expect(seite[3].beteiligung, GefechtsBeteiligung.nahkampf);
    expect(seite[4].herkunft, GefechtsTeilnehmerherkunft.manuell);
    // Nahkämpfer: Alrike, Haldor, Söldner; auf den Oger: Alrike und Söldner.
    expect(gefechtsEigeneNahkaempfer(seite), 3);
    expect(gefechtsAngreiferAufZiel(seite, 'o'), 2);
  });

  test('Nicht dabei löst Bindungen und Ziel, Ziel braucht den Gegner', () {
    var b = Gefechtsbegegnung(
      gegner: {
        'o': const Gefechtsgegner(id: 'o', name: 'Oger', ini: 7, bindet: 'x'),
        'p': const Gefechtsgegner(id: 'p', name: 'Ork', ini: 7, bindet: 'h'),
      },
    );
    b = setzeGefechtsmitstreiterZiel(
      b,
      teilnehmerId: 'x',
      name: 'Haldor',
      zielId: 'o',
    );
    expect(b.mitstreiter['x']!.zielId, 'o');
    b = setzeGefechtsBeteiligung(
      b,
      teilnehmerId: 'x',
      name: 'Haldor',
      beteiligung: GefechtsBeteiligung.fernkampf,
    );
    expect(b.mitstreiter['x']!.zielId, 'o');
    expect(b.gegner['o']!.bindet, 'x');
    b = setzeGefechtsBeteiligung(
      b,
      teilnehmerId: 'x',
      name: 'Haldor',
      beteiligung: GefechtsBeteiligung.nichtDabei,
    );
    expect(b.mitstreiter['x']!.zielId, isNull);
    expect(b.gegner['o']!.bindet, isNull);
    expect(b.gegner['p']!.bindet, 'h');
    expect(
      () => setzeGefechtsmitstreiterZiel(
        b,
        teilnehmerId: 'x',
        name: 'Haldor',
        zielId: 'fehlt',
      ),
      throwsStateError,
    );
  });
  test('Ohne Nahkampf auf beiden Seiten gibt es keinen INI-Bonus', () {
    final b = begegnung({'a': 'h'});
    expect(gefechtsUeberzahl(b, eigeneNahkaempfer: 0).iniBonusGegner, 0);
    expect(
      gefechtsUeberzahl(
        const Gefechtsbegegnung(),
        eigeneNahkaempfer: 3,
      ).iniBonusEigene,
      0,
    );
  });

  test('Lage-INI: Überzahl und Taktik, nicht für Unbeteiligte', () {
    final b = setzeGefechtstaktik(
      begegnung({'a': 'h'}),
      const Gefechtstaktik(anfuehrerId: 'h', iniBoni: {'x': 2}),
    );
    final u = gefechtsUeberzahl(b, eigeneNahkaempfer: 3);
    expect(u.iniBonusEigene, 2);
    GefechtsTeilnehmer t(String id, GefechtsBeteiligung b) =>
        gefechtsEigeneSeite(
          Gefechtsbegegnung(
            mitstreiter: {
              id: Gefechtsmitstreiter(id: id, name: id, beteiligung: b),
            },
          ),
          helden: const [],
        ).single;
    expect(gefechtsLageIni(b, u, t('x', GefechtsBeteiligung.fernkampf)), 4);
    expect(gefechtsLageIni(b, u, t('y', GefechtsBeteiligung.nahkampf)), 2);
    expect(gefechtsLageIni(b, u, t('x', GefechtsBeteiligung.nichtDabei)), 0);
  });

  test('Gegner-INI: Überzahl der Gegner und INI-Basis-Abzug der Wunden', () {
    // KO 12: Schwellen 6/12/18; RS 0.
    var g = const Gefechtsgegner(
      id: 'o',
      name: 'Ork',
      lep: 30,
      rs: 0,
      ko: 12,
      ini: 10,
      bindet: 'h',
      treffer: [
        Gefechtsgegnertreffer(buchungId: '1', tp: 13, zone: WundZone.brust),
        Gefechtsgegnertreffer(buchungId: '2', tp: 7, zone: WundZone.linkesBein),
      ],
    );
    // Zwei Wunden Brust (−4) und eine im Bein (−2 und Zonenanteil −2).
    expect(gefechtsGegnerIniWundmalus(g), -8);
    final b = Gefechtsbegegnung(
      gegner: {
        'o': g,
        'p': const Gefechtsgegner(id: 'p', name: 'Ork 2', ini: 9, bindet: 'h'),
      },
    );
    final u = gefechtsUeberzahl(b, eigeneNahkaempfer: 1);
    final ini = gefechtsGegnerIni(g, u);
    expect((ini.wert, ini.ueberzahl, ini.wunden), (3, 1, -8));
    g = g.copyWith(status: GefechtsgegnerStatus.kampfunfaehig);
    expect(gefechtsGegnerIni(g, u).ueberzahl, 0);
  });
}
