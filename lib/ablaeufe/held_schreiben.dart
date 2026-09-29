import 'package:dsa_heldenverwaltung/ablaeufe/reihenfolge_je_held.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Speichert einen geänderten Helden samt Normalisierung und liefert den
/// tatsächlich gespeicherten Stand.
///
/// Wird von außen hereingereicht, weil die Normalisierung (Katalog,
/// Merkmalsmigration, Inventarabgleich) in `HeroActions` liegt und Riverpod
/// braucht. Sie darf selbst **nie** wieder einreihen, sonst wartete der
/// Vorgang auf sich selbst.
typedef BogenSpeichern = Future<HeroSheet> Function(HeroSheet geaendert);

/// Laufende Bogenvorgänge je Speicher und Held; getrennt von der
/// Warteschlange des Laufzeitzustands (`zustand_schreiben.dart`).
final ReihenfolgeJeHeld _bogenReihenfolge = ReihenfolgeJeHeld(
  'laufendeBogenvorgaenge',
);

/// Führt [vorgang] nach allen früher eingereihten Bogenvorgängen desselben
/// Helden über dasselbe [repository] aus.
///
/// Damit landet auch ein Speichern ohne frisches Laden (Editorentwurf,
/// Steigerungsübernahme) nie zwischen Laden und Schreiben einer frischen
/// Änderung. Fehler gehen an den Aufrufer und halten folgende Vorgänge nicht
/// auf.
Future<T> reiheBogenvorgangEin<T>({
  required HeroRepository repository,
  required String heroId,
  required Future<T> Function() vorgang,
}) {
  return _bogenReihenfolge.reiheEin(
    speicher: repository,
    heroId: heroId,
    vorgang: vorgang,
  );
}

/// Ändert den gespeicherten Heldenbogen gezielt (ARCH-05).
///
/// Gegenstück zu `aendereGespeichertenZustand` für den Bogen: lädt den Helden
/// frisch aus [repository], wendet [aenderung] an und speichert über
/// [speichere]. Felder, die seit dem letzten Aufbau der Oberfläche anderswo
/// gespeichert wurden, bleiben erhalten, solange [aenderung] sie nicht selbst
/// ersetzt. Liefert den gespeicherten Helden.
///
/// Liefert [aenderung] dasselbe Objekt zurück, gibt es nichts zu speichern:
/// Dann wird weder normalisiert noch gestempelt noch hochgeladen.
///
/// Ein fehlender Held ist ein `StateError`. Fehler beim Laden, in
/// [aenderung] oder beim Speichern erreichen den Aufrufer unverändert und
/// halten folgende Änderungen nicht auf. Dies ist keine Transaktion
/// gegenüber Schreibwegen, die an der Warteschlange vorbei speichern (ARCH-06).
Future<HeroSheet> aendereGespeichertenHelden({
  required HeroRepository repository,
  required String heroId,
  required HeroSheet Function(HeroSheet aktuell) aenderung,
  required BogenSpeichern speichere,
}) {
  return reiheBogenvorgangEin(
    repository: repository,
    heroId: heroId,
    vorgang: () async {
      final aktuell = await repository.loadHeroById(heroId);
      if (aktuell == null) {
        throw StateError('Der Held wurde nicht gefunden.');
      }
      final geaendert = aenderung(aktuell);
      if (identical(geaendert, aktuell)) {
        return aktuell;
      }
      return speichere(geaendert);
    },
  );
}
