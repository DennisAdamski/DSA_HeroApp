import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Snapshot der Heldenindex-Daten fuer O(1)-Zugriffe nach ID.
class HeroIndexSnapshot {
  HeroIndexSnapshot._({required this.sortedIds, required this.byId});

  factory HeroIndexSnapshot.fromMap(Map<String, HeroSheet> index) {
    final byId = Map<String, HeroSheet>.unmodifiable(
      Map<String, HeroSheet>.from(index),
    );
    final sortedIds = byId.values.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    return HeroIndexSnapshot._(
      sortedIds: sortedIds.map((hero) => hero.id).toList(growable: false),
      byId: byId,
    );
  }

  final List<String> sortedIds;
  final Map<String, HeroSheet> byId;

  List<HeroSheet> get heroes {
    return sortedIds
        .map((id) => byId[id])
        .whereType<HeroSheet>()
        .toList(growable: false);
  }
}
