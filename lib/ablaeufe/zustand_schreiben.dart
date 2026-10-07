import 'package:dsa_heldenverwaltung/ablaeufe/reihenfolge_je_held.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

/// Setzt den Änderungszeitpunkt eines Laufzeitzustands in UTC.
///
/// Jede Nutzeränderung bekommt einen frischen Stempel, damit die
/// Konfliktansicht des Konto-Syncs sinnvolle Zeiten zeigt. Inhalts-Hashes
/// ignorieren das Feld (`heroStateContentHash`).
HeroState mitAenderungszeitpunkt(HeroState zustand, DateTime zeitpunkt) {
  return zustand.copyWith(lastModified: zeitpunkt.toUtc());
}

/// Laufende Zustandsänderungen je Speicher und Held; getrennt von der
/// Warteschlange des Bogens (`held_schreiben.dart`).
final ReihenfolgeJeHeld _zustandsReihenfolge = ReihenfolgeJeHeld(
  'laufendeZustandsaenderungen',
);

/// Ändert den gespeicherten Laufzeitzustand eines Helden gezielt.
///
/// Lädt den Zustand frisch aus [repository] (fehlt er, gilt
/// `HeroState.empty()`), wendet [aenderung] an, stempelt ihn mit [uhr] und
/// speichert ihn. Gibt [aenderung] den gespeicherten Zustand unverändert
/// zurück (dieselbe Instanz), wird nichts gespeichert — etwa bei einer
/// bereits gebuchten Wiederholung (ARCH-06). Felder, die seit dem letzten Aufbau der Oberfläche anderswo
/// gespeichert wurden, bleiben so erhalten, solange [aenderung] sie nicht
/// selbst ersetzt. Liefert den gespeicherten Zustand.
///
/// Änderungen desselben Helden über dasselbe [repository] laufen streng
/// nacheinander: Jede lädt erst, wenn die vorige gespeichert oder
/// gescheitert ist. Zwei nicht abgewartete Aufrufe (etwa zwei schnell
/// protokollierte Würfe) können sich so nicht gegenseitig überschreiben.
///
/// Fehler beim Laden oder Speichern werden unverändert an den Aufrufer
/// weitergereicht und halten folgende Änderungen nicht auf. Schreibwege, die
/// an dieser Funktion vorbei speichern, sind nicht eingereiht; dies ist
/// keine Transaktion gegenüber ihnen (ARCH-06).
Future<HeroState> aendereGespeichertenZustand({
  required HeroRepository repository,
  required String heroId,
  required HeroState Function(HeroState aktuell) aenderung,
  required DateTime Function() uhr,
}) {
  return _zustandsReihenfolge.reiheEin(
    speicher: repository,
    heroId: heroId,
    vorgang: () => _aendereJetzt(
      repository: repository,
      heroId: heroId,
      aenderung: aenderung,
      uhr: uhr,
    ),
  );
}

// Lädt, ändert, stempelt und speichert ohne Rücksicht auf andere Aufrufe.
Future<HeroState> _aendereJetzt({
  required HeroRepository repository,
  required String heroId,
  required HeroState Function(HeroState aktuell) aenderung,
  required DateTime Function() uhr,
}) async {
  final gespeichert = await repository.loadHeroState(heroId);
  final aktuell = gespeichert ?? const HeroState.empty();
  final neu = aenderung(aktuell);
  // Nur ein tatsächlich gespeicherter Zustand gilt als unverändert; ein
  // fehlender wird immer geschrieben, auch als leerer Zustand.
  if (gespeichert != null && identical(neu, gespeichert)) {
    return gespeichert;
  }
  final geaendert = mitAenderungszeitpunkt(neu, uhr());
  await repository.saveHeroState(heroId, geaendert);
  return geaendert;
}
