import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/sync_geraete.dart';

const String _krieger = 'bestand-f01';

// Grenze aus ARCH-06: Eine Loeschung waehrend einer offenen
// Konfliktentscheidung ginge still verloren, weil der Wiederanlauf den
// Helden mit dem gewaehlten Stand wiederherstellt. Sie wird deshalb abgelehnt.
void main() {
  late GeteilteCloud cloud;
  late SyncTestGeraet a;
  late SyncTestGeraet b;

  // Beide Geraete aendern denselben Helden offline; B entscheidet „Nur
  // Lokal“, die Leitung bricht vor dem ersten Schreibzugriff ab.
  Future<void> offenerVorgang() async {
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
    await a.repo.saveHero(bundle.hero);
    await a.repo.saveHeroState(bundle.hero.id, bundle.state);
    await a.repo.syncNow();
    await b.repo.syncNow();
    a.remote.offline = true;
    b.remote.offline = true;
    final heldA = (await a.lokal.loadHeroById(_krieger))!;
    await a.repo.saveHero(heldA.copyWith(dukaten: '20'));
    final heldB = (await b.lokal.loadHeroById(_krieger))!;
    await b.repo.saveHero(heldB.copyWith(dukaten: '30'));
    a.remote.offline = false;
    b.remote.offline = false;
    await a.repo.syncNow();
    await b.repo.syncNow();
    b.remote.schreibvorgaengeBisAbbruch = 0;
    await expectLater(
      b.repo.resolveConflict(
        b.konflikte.single.id,
        SyncResolutionChoice.keepLocal,
      ),
      throwsA(isA<SyncNetworkException>()),
    );
    expect(b.repo.currentStatus.ausstehendeVorgaenge, 1);
  }

  setUp(() {
    cloud = GeteilteCloud();
    a = SyncTestGeraet(cloud);
    b = SyncTestGeraet(cloud);
  });

  test('deleteHero lehnt ab und lässt den Helden unangetastet', () async {
    await offenerVorgang();

    await expectLater(
      b.repo.deleteHero(_krieger),
      throwsA(isA<HeldInKonfliktentscheidungException>()),
    );

    expect((await b.lokal.loadHeroById(_krieger))!.dukaten, '30');
    expect(b.lokal.loadHeroState(_krieger), completion(isNotNull));
  });

  test('nach abgeschlossener Entscheidung lässt sich löschen', () async {
    await offenerVorgang();
    await expectLater(
      b.repo.deleteHero(_krieger),
      throwsA(isA<HeldInKonfliktentscheidungException>()),
    );

    b.remote.schreibvorgaengeBisAbbruch = null;
    await b.repo.syncNow();
    expect(b.repo.currentStatus.ausstehendeVorgaenge, 0);
    expect((await cloud.loadHero(_krieger))!.hero!.dukaten, '30');

    await b.repo.deleteHero(_krieger);
    await b.repo.syncNow();
    await a.repo.syncNow();

    expect(await b.lokal.loadHeroById(_krieger), isNull);
    expect((await cloud.loadHero(_krieger))!.isDeleted, isTrue);
    expect(await a.lokal.loadHeroById(_krieger), isNull);
  });

  test('ein Held ohne offenen Vorgang wird weiter sofort gelöscht', () async {
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
    await a.repo.saveHero(bundle.hero);
    await a.repo.saveHeroState(bundle.hero.id, bundle.state);
    await a.repo.syncNow();

    await a.repo.deleteHero(_krieger);

    expect(await a.lokal.loadHeroById(_krieger), isNull);
    expect((await cloud.loadHero(_krieger))!.isDeleted, isTrue);
  });
}
