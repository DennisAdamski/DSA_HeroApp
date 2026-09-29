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

/// Ändert den gespeicherten Laufzeitzustand eines Helden gezielt.
///
/// Lädt den Zustand frisch aus [repository] (fehlt er, gilt
/// `HeroState.empty()`), wendet [aenderung] an, stempelt ihn mit [uhr] und
/// speichert ihn. Felder, die seit dem letzten Aufbau der Oberfläche anderswo
/// gespeichert wurden, bleiben so erhalten, solange [aenderung] sie nicht
/// selbst ersetzt. Liefert den gespeicherten Zustand.
///
/// Fehler beim Laden oder Speichern werden unverändert an den Aufrufer
/// weitergereicht. Dies ist keine Transaktion gegenüber gleichzeitig
/// laufenden Schreibwegen (ARCH-06).
Future<HeroState> aendereGespeichertenZustand({
  required HeroRepository repository,
  required String heroId,
  required HeroState Function(HeroState aktuell) aenderung,
  required DateTime Function() uhr,
}) async {
  final aktuell =
      await repository.loadHeroState(heroId) ?? const HeroState.empty();
  final geaendert = mitAenderungszeitpunkt(aenderung(aktuell), uhr());
  await repository.saveHeroState(heroId, geaendert);
  return geaendert;
}
