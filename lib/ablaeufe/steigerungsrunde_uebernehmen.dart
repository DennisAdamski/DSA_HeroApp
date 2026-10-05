import 'package:dsa_heldenverwaltung/ablaeufe/held_schreiben.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_rules.dart';

/// Speichert einen gebuchten Helden normalisiert und liefert den
/// gespeicherten Stand.
///
/// Entspricht dem Tear-off `HeroActions.saveHero`: reiht sich selbst in die
/// Bogenvorgänge des Helden ein (`reiheBogenvorgangEin`) und prüft
/// [expectedContentHash] erst unmittelbar vor dem Schreiben.
typedef SteigerungSpeichern = Future<HeroSheet> Function(
  HeroSheet gebucht, {
  String? expectedContentHash,
  RulesCatalog? validationCatalog,
});

/// Anwendungsablauf „Steigerungsrunde übernehmen“ (ARCH-05).
///
/// Bucht eine geplante Runde auf den Helden, aus dem sie geplant wurde:
/// Werte, AP/SE und Historie gemeinsam in einem Speichervorgang. Ein
/// inzwischen anderswo geänderter Held wird nie mit der alten Basis
/// überschrieben. Planung und Sitzungszustand bleiben beim Aufrufer
/// (`AdvancementSessionController`). Fehler werden nicht gefangen, sondern
/// an die Oberfläche weitergereicht.
class SteigerungsrundeUebernehmen {
  /// Erzeugt den Ablauf mit Heldenspeicher und normalisierender Speicherung.
  const SteigerungsrundeUebernehmen({
    required this.repository,
    required this.speichere,
  });

  /// Speicher, aus dem frisch geladen wird.
  final HeroRepository repository;

  /// Normalisiert und speichert den gebuchten Helden; reiht sich selbst ein.
  final SteigerungSpeichern speichere;

  /// Übernimmt [eintraege], geplant auf [basis] nach [katalog].
  ///
  /// Geprüft wird zweimal: hier gegen den frisch geladenen Helden, damit eine
  /// veraltete Runde früh und verständlich scheitert, und in [speichere]
  /// unmittelbar vor dem Schreiben. Die zweite Prüfung fängt Stände ab, die
  /// an der Warteschlange vorbei gespeichert werden (etwa ein Online-Stand
  /// aus dem Konto-Sync). [istGeschlossen] meldet, dass die Runde während
  /// des Ladens geschlossen wurde; dann wird nichts gespeichert.
  ///
  /// Weil [speichere] sich selbst einreiht, darf dieser Ablauf nie aus einem
  /// bereits eingereihten Bogenvorgang aufgerufen werden — er wartete dort
  /// auf sich selbst. Liefert den gespeicherten Helden.
  Future<HeroSheet> uebernehmeRunde({
    required HeroSheet basis,
    required List<HeroAdvancementEntry> eintraege,
    required RulesCatalog katalog,
    bool Function()? istGeschlossen,
  }) async {
    final aktuell = await repository.loadHeroById(basis.id);
    if (istGeschlossen?.call() ?? false) {
      throw StateError('Die Steigerungsrunde wurde inzwischen geschlossen.');
    }
    final erwarteterHash = heroContentHash(basis);
    if (aktuell == null || heroContentHash(aktuell) != erwarteterHash) {
      throw StateError(
        'Der Held wurde inzwischen geändert. Bitte verwirf diese Runde '
        'und plane mit dem aktuellen Helden erneut.',
      );
    }
    final gebucht = commitAdvancements(
      base: basis,
      entries: eintraege,
      catalog: katalog,
    );
    return speichere(
      gebucht,
      expectedContentHash: erwarteterHash,
      validationCatalog: katalog,
    );
  }

  /// Speichert nur die Anzeige nicht passender Sonderfertigkeiten.
  ///
  /// Läuft eingereiht hinter früheren Bogenvorgängen desselben Helden und
  /// ändert den frisch geladenen Stand. Bei offener Runde ist [basis] deren
  /// Ausgangsheld: Weicht der gespeicherte Held davon ab, wird nichts
  /// gespeichert, weil die Runde sonst eine fremde Änderung als Basis
  /// übernähme. [istGeschlossen] wie bei [uebernehmeRunde].
  ///
  /// Eine reine Anzeigepräferenz wird bewusst **nicht** normalisiert: Sie
  /// darf weder AP neu rechnen noch das Inventar abgleichen. Liefert den
  /// gespeicherten Helden.
  Future<HeroSheet> speichereSfAnzeige({
    required String heroId,
    required bool anzeigen,
    HeroSheet? basis,
    bool Function()? istGeschlossen,
  }) {
    return reiheBogenvorgangEin(
      repository: repository,
      heroId: heroId,
      vorgang: () async {
        final aktuell = await repository.loadHeroById(heroId);
        if (istGeschlossen?.call() ?? false) {
          throw StateError(
            'Die Steigerungsrunde wurde inzwischen geschlossen.',
          );
        }
        if (aktuell == null ||
            (basis != null &&
                heroContentHash(aktuell) != heroContentHash(basis))) {
          throw StateError('Der Held wurde inzwischen geändert.');
        }
        final geaendert = aktuell.copyWith(
          showInapplicableSpecialAbilities: anzeigen,
        );
        await repository.saveHero(geaendert);
        return geaendert;
      },
    );
  }
}
