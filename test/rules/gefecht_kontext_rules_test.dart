import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kontext_rules.dart';

void main() {
  const w = Gefechtswerte(
    iniBasis: 10,
    at: 15,
    pa: 14,
    ausweichen: 12,
    waffenDk: 'N',
  );
  for (final aktion in [Gefechtsaktion.parade, Gefechtsaktion.schildparade]) {
    test('$aktion benötigt keine allgemeine Paradebestätigung', () {
      const kontext = Gefechtskontext(
        angriffsart: Gefechtsangriffsart.nahkampf,
        finte: 2,
        schildWmWirksam: true,
      );
      const s = Gefechtszustand(iniWurf: 6, dk: 'N', kontext: kontext);
      final p = pruefeGefechtskontext(s, aktion, 'N');
      expect(p.fehlend, isEmpty);
      expect(p.sperren, isEmpty);
      expect(p.zuschlag, 2);
      expect(gefechtsPflichtkontextErfasst(kontext, aktion), isTrue);
    });
    test('$aktion erhält ein bekanntes Paradeverbot', () {
      const s = Gefechtszustand(
        iniWurf: 6,
        dk: 'N',
        kontext: Gefechtskontext(
          angriffsart: Gefechtsangriffsart.nahkampf,
          finte: 0,
          paradeVerboten: true,
          schildWmWirksam: true,
        ),
      );
      final p = pruefeGefechtsaktion(s, w, aktion);
      expect(p.status, Gefechtsfreigabe.gesperrt);
      expect(
        p.sperrgruende,
        contains('Dieser Angriff kann nicht pariert werden.'),
      );
    });
  }
  test('Parade benötigt weiterhin konkrete Angriffsart und Finte', () {
    const s = Gefechtszustand(iniWurf: 6, dk: 'N');
    final p = pruefeGefechtskontext(s, Gefechtsaktion.parade, 'N');
    expect(p.fehlend, contains('Aktuelle Angriffsart festlegen.'));
    expect(
      p.fehlend,
      contains('Gegnerische Finte für diesen Angriff erfassen (0 möglich).'),
    );
    expect(
      gefechtsPflichtkontextErfasst(s.kontext, Gefechtsaktion.parade),
      isFalse,
    );
  });
  test('DK sperrt unmögliche AT und berechnet AT/PA unterschiedlich', () {
    for (final dk in ['H', 'N', 'S', 'P']) {
      final s = Gefechtszustand(
        iniWurf: 6,
        dk: dk,
        kontext: const Gefechtskontext(
          gegnerzahl: 1,
          angriffsart: Gefechtsangriffsart.nahkampf,
          finte: 0,
          paradeVerboten: false,
        ),
      );
      final at = pruefeGefechtsaktion(s, w, Gefechtsaktion.angriff);
      final pa = pruefeGefechtsaktion(s, w, Gefechtsaktion.parade);
      expect(at.zielwert, dk == 'H' || dk == 'S' ? 9 : 15);
      expect(pa.zielwert, dk == 'H' ? 8 : 14);
      expect(at.status == Gefechtsfreigabe.gesperrt, dk == 'P');
    }
  });
  test('Finte einmal und freies Ausweichen mit einfacher DK', () {
    const s = Gefechtszustand(
      iniWurf: 6,
      dk: 'N',
      kontext: Gefechtskontext(
        gegnerzahl: 1,
        platzZumAusweichen: true,
        angriffsart: Gefechtsangriffsart.nahkampf,
        finte: 3,
        paradeVerboten: false,
      ),
    );
    expect(pruefeGefechtsaktion(s, w, Gefechtsaktion.parade).zielwert, 11);
    expect(
      pruefeGefechtsaktion(s, w, Gefechtsaktion.freiesAusweichen).zielwert,
      7,
    );
  });
  test('Kontaktwechsel verwirft Angriffsdaten und beginnt mit Vorgaben', () {
    const s = Gefechtszustand(
      iniWurf: 6,
      dk: 'S',
      kontext: Gefechtskontext(
        kontakt: 'Ork',
        finte: 4,
        angriffsart: Gefechtsangriffsart.fernkampf,
        paradeVerboten: true,
        entfernung: 20,
      ),
    );
    final neu = wechsleGefechtskontakt(s, 'Wolf');
    expect(neu.dk, isNull);
    expect(neu.kontext.kontakt, 'Wolf');
    expect(neu.kontext.finte, 0);
    expect(neu.kontext.angriffsart, Gefechtsangriffsart.nahkampf);
    expect(neu.kontext.paradeVerboten, isNull);
    expect(neu.kontext.entfernung, isNull);
    final mitDk = wechsleGefechtskontakt(s, 'Wolf', startDk: 'N');
    expect(mitDk.dk, 'N');
  });

  // Review R8: leere oder kleingeschriebene Waffen-DK darf die vorbelegte
  // Start-DK nicht dauerhaft als „Angabe fehlt“ melden.
  for (final waffenDk in ['', 'ns', ' n ']) {
    test('Waffen-DK "$waffenDk" mit Sitzungs-DK N fehlt nicht', () {
      const s = Gefechtszustand(iniWurf: 6, dk: 'N');
      final k = pruefeGefechtskontext(s, Gefechtsaktion.angriff, waffenDk);
      expect(k.fehlend, isEmpty);
      expect(k.sperren, isEmpty);
      expect(gefechtsDkDifferenz(waffenDk, 'N'), 0);
    });
  }
  test('Unbekannte Waffen-DK gilt als Nahkampf und bleibt sichtbar', () {
    const ohneDk = Gefechtswerte(
      iniBasis: 10,
      at: 15,
      pa: 14,
      ausweichen: 12,
      waffenDk: '',
    );
    const s = Gefechtszustand(iniWurf: 6, dk: 'N');
    final p = pruefeGefechtsaktion(s, ohneDk, Gefechtsaktion.angriff);
    expect(p.fehlendeAngaben, isEmpty);
    expect(p.hinweise, contains('Waffen-DK unbekannt, Nahkampf angenommen.'));
    expect(gefechtsDkDifferenz('ns', 'S'), 0);
    expect(gefechtsDkDifferenz('', 'S'), -1);
  });
}
