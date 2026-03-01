import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

abstract class HeroRepository {
  Stream<Map<String, HeroSheet>> watchHeroIndex();
  Future<List<HeroSheet>> listHeroes();
  Future<HeroSheet?> loadHeroById(String heroId);
  Future<void> saveHero(HeroSheet hero);
  Future<void> deleteHero(String heroId);
  Stream<HeroState> watchHeroState(String heroId);
  Future<HeroState?> loadHeroState(String heroId);
  Future<void> saveHeroState(String heroId, HeroState state);
}
