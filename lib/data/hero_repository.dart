import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

abstract class HeroRepository {
  Future<List<HeroSheet>> listHeroes();
  Future<void> saveHero(HeroSheet hero);
  Future<void> deleteHero(String heroId);
  Future<HeroState?> loadHeroState(String heroId);
  Future<void> saveHeroState(String heroId, HeroState state);
}
