import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vertrauten_spiel_rules.dart';

/// Was die Vereinigung tatsächlich gekostet hat.
class VereinigungsErgebnis {
  /// Erstellt das Ergebnis.
  const VereinigungsErgebnis({
    required this.verlustHexe,
    required this.verlustVertrauter,
  });

  /// AsP, die die Hexe verloren hat.
  final int verlustHexe;

  /// AsP, die der Vertraute verloren hat.
  final int verlustVertrauter;
}

/// Anwendungsablauf „Vereinigung bei Vollmond“ (WdZ S. 125, V2).
///
/// Hexe und Vertrauter verlieren je 1W6 AsP. Beide Werte stehen im
/// Laufzeitzustand, der Ablauf schreibt deshalb genau ein Dokument: er lädt
/// den Zustand frisch, zieht die AsP ab (höchstens den Vorrat) und hängt für
/// jeden Wurf einen Protokolleintrag an. Fehler werden nicht gefangen.
class VertrautenVereinigung {
  /// Erzeugt den Ablauf mit Heldenspeicher und Uhr.
  const VertrautenVereinigung({required this.repository, required this.uhr});

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Protokoll und Änderungsstempel.
  final DateTime Function() uhr;

  /// Bucht die Vereinigung mit den Würfen [wurfHexe] und [wurfVertrauter]
  /// (je 1 bis 6, gewürfelt oder von Hand eingetragen).
  Future<VereinigungsErgebnis> vereinige({
    required String heroId,
    required String begleiterId,
    required int wurfHexe,
    required int wurfVertrauter,
  }) async {
    for (final wurf in <int>[wurfHexe, wurfVertrauter]) {
      if (wurf < 1 || wurf > 6) {
        throw StateError('Ein W6-Wurf liegt zwischen 1 und 6.');
      }
    }
    final held = await repository.loadHeroById(heroId);
    final vertrauter = held?.companions
        .where((c) => c.id == begleiterId)
        .firstOrNull;
    if (vertrauter == null) {
      throw StateError('Der Vertraute wurde inzwischen entfernt.');
    }
    if (vertrauter.typ != BegleiterTyp.vertrauter) {
      throw StateError('Die Vereinigung gilt nur für Vertraute.');
    }
    final jetzt = uhr();
    var verlustHexe = 0;
    var verlustVertrauter = 0;
    await aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) {
        verlustHexe = vertrautenVereinigungsVerlust(
          aktuell: aktuell.currentAsp,
          wurf: wurfHexe,
        );
        verlustVertrauter = vertrautenVereinigungsVerlust(
          aktuell: begleiterAktuellerPool(
            vertrauter,
            aktuell,
            BegleiterPool.asp,
          ),
          wurf: wurfVertrauter,
        );
        final ohneHexe = aktuell.copyWith(
          currentAsp: aktuell.currentAsp - verlustHexe,
        );
        final ohneVertrauten = mitBegleiterPool(
          ohneHexe,
          vertrauter,
          BegleiterPool.asp,
          RessourcenAenderung.schritt(-verlustVertrauter),
        );
        return ohneVertrauten.withAppendedDiceLogEntries(<DiceLogEntry>[
          _eintrag('Vereinigung: Hexe', wurfHexe, verlustHexe, jetzt),
          _eintrag(
            'Vereinigung: ${_name(vertrauter)}',
            wurfVertrauter,
            verlustVertrauter,
            jetzt,
          ),
        ]);
      },
    );
    return VereinigungsErgebnis(
      verlustHexe: verlustHexe,
      verlustVertrauter: verlustVertrauter,
    );
  }

  static String _name(HeroCompanion c) =>
      c.name.trim().isEmpty ? 'Vertrauter' : c.name.trim();

  static DiceLogEntry _eintrag(
    String titel,
    int wurf,
    int verlust,
    DateTime zeitpunkt,
  ) => diceLogEntryFromRoll(
    title: titel,
    subtitle: verlust == wurf
        ? '1W6 AsP: −$verlust AsP'
        : '1W6 AsP: −$verlust AsP (Vorrat erschöpft, Wurf $wurf)',
    diceValues: <int>[wurf],
    total: wurf,
    timestamp: zeitpunkt,
  );
}
