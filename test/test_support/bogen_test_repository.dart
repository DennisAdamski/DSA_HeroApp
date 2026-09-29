import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

/// Test-Repository für die frischen Schreibwege des Bogens (ARCH-05).
///
/// [fremdeAenderung] ist ein Schreibweg, den die Oberfläche nicht gesehen
/// hat: Die Oberfläche liest den Helden über `watchHeroIndex`, nur ein
/// frisches Laden (`loadHeroById`) liefert die Änderung mit. Erst das nächste
/// Speichern macht sie dauerhaft. Ein Snapshot-Schreibweg überschreibt sie
/// also, ein frischer erhält sie.
class BogenTestRepository extends FakeRepository {
  /// Erstellt das Repository mit den Anfangsbeständen.
  BogenTestRepository({super.heroes, super.states});

  /// Änderung eines anderen Schreibwegs, siehe Klassenbeschreibung.
  HeroSheet Function(HeroSheet held)? fremdeAenderung;

  /// Lässt jedes Speichern des Bogens scheitern.
  bool schreibFehler = false;

  /// Zahl der erfolgreichen Bogenspeicherungen.
  int bogenSpeicherungen = 0;

  @override
  Future<HeroSheet?> loadHeroById(String heroId) async {
    final gespeichert = await super.loadHeroById(heroId);
    final fremd = fremdeAenderung;
    if (gespeichert == null || fremd == null) {
      return gespeichert;
    }
    return fremd(gespeichert);
  }

  @override
  Future<void> saveHero(HeroSheet hero) async {
    if (schreibFehler) {
      throw StateError('Speicher voll');
    }
    fremdeAenderung = null;
    bogenSpeicherungen++;
    await super.saveHero(hero);
  }

  /// Der gespeicherte Stand ohne [fremdeAenderung].
  Future<HeroSheet> gespeichert(String heroId) async {
    return (await super.loadHeroById(heroId))!;
  }
}
