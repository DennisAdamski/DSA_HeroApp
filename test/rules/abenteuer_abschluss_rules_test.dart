import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/adventure_rewards_rules.dart';

// Abschluss und Rücknahme auf dem gespeicherten Helden (ARCH-05).

const _abenteuer = HeroAdventureEntry(id: 'adv_1', title: 'Das Purpurzeichen');

const _held = HeroSheet(
  id: 'held',
  name: 'Rondra',
  level: 1,
  apTotal: 1000,
  apSpent: 200,
  apAvailable: 800,
  dukaten: '10',
  adventures: [_abenteuer],
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
);

/// Ergebnis des Abschlussdialogs, aufgebaut auf dem angezeigten Abenteuer.
final _abschluss = _abenteuer.copyWith(apReward: 50, dukatenReward: 5);

void main() {
  test('bucht auf den gespeicherten Stand und behält neue Notizen', () {
    // Seit dem Öffnen des Dialogs hat ein anderer Weg AP gebucht und dem
    // Abenteuer eine Notiz gegeben.
    final gespeichert = _held.copyWith(
      apTotal: 1100,
      adventures: [
        _abenteuer.copyWith(
          notes: const [HeroNoteEntry(title: 'Spur im Nebel')],
        ),
      ],
    );

    final ergebnis = schliesseAbenteuerAb(
      held: gespeichert,
      abenteuerId: 'adv_1',
      abschluss: _abschluss,
    );

    final abenteuer = ergebnis.adventures.single;
    expect(ergebnis.apTotal, 1150);
    expect(ergebnis.dukaten, '15');
    expect(abenteuer.rewardsApplied, isTrue);
    expect(abenteuer.status, HeroAdventureStatus.completed);
    expect(abenteuer.notes.single.title, 'Spur im Nebel');
    expect(abenteuer.apReward, 50);
  });

  test('ein schon abgeschlossenes Abenteuer bucht nicht doppelt', () {
    final einmal = schliesseAbenteuerAb(
      held: _held,
      abenteuerId: 'adv_1',
      abschluss: _abschluss,
    );

    expect(
      () => schliesseAbenteuerAb(
        held: einmal,
        abenteuerId: 'adv_1',
        abschluss: _abschluss,
      ),
      throwsA(
        isA<StateError>().having(
          (fehler) => fehler.message,
          'message',
          'Das Abenteuer wurde bereits abgeschlossen.',
        ),
      ),
    );
  });

  test('ein verbotener Abschluss meldet seinen Grund', () {
    final unlesbar = _held.copyWith(dukaten: 'ein Beutel');
    expect(
      () => schliesseAbenteuerAb(
        held: unlesbar,
        abenteuerId: 'adv_1',
        abschluss: _abschluss,
      ),
      throwsA(
        isA<StateError>().having(
          (fehler) => fehler.message,
          'message',
          contains('nicht numerisch lesbar'),
        ),
      ),
    );
    expect(
      () => schliesseAbenteuerAb(
        held: _held,
        abenteuerId: 'fehlt',
        abschluss: _abschluss,
      ),
      throwsStateError,
    );
  });

  test('Wiederöffnen nimmt zurück, ein zweites Mal wird abgewiesen', () {
    final abgeschlossen = schliesseAbenteuerAb(
      held: _held,
      abenteuerId: 'adv_1',
      abschluss: _abschluss,
    ).copyWith(apAvailable: 850);

    final offen = oeffneAbenteuerWieder(
      held: abgeschlossen,
      abenteuerId: 'adv_1',
    );
    expect(offen.apTotal, 1000);
    expect(offen.adventures.single.rewardsApplied, isFalse);

    expect(
      () => oeffneAbenteuerWieder(held: offen, abenteuerId: 'adv_1'),
      throwsStateError,
    );
  });
}
