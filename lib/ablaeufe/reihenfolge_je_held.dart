/// Reiht asynchrone Vorgänge je Speicher und Held nacheinander ein.
///
/// Gemeinsamer Baustein der frischen Schreibwege (ARCH-05): Ein Vorgang
/// startet erst, wenn der vorige desselben Helden über denselben Speicher
/// fertig oder gescheitert ist. Zwei nicht abgewartete Aufrufe können so nicht
/// denselben Stand laden und einander überschreiben.
///
/// Die Warteschlange hängt per [Expando] am Speicherobjekt statt global, damit
/// getrennte Speicher (Tests, Profil- oder Kontowechsel) einander nicht
/// blockieren und nichts überdauert, was der Speicher selbst nicht überdauert.
/// Jede Instanz ist eine eigene Warteschlange; Bogen und Laufzeitzustand
/// benutzen getrennte, weil sie getrennt gespeichert werden.
class ReihenfolgeJeHeld {
  /// Erstellt eine Warteschlange; [name] erscheint nur in der Fehlersuche.
  ReihenfolgeJeHeld(String name)
    : _laufend = Expando<Map<String, Future<void>>>(name);

  final Expando<Map<String, Future<void>>> _laufend;

  /// Hängt [vorgang] an die Warteschlange von [heroId] in [speicher] an.
  ///
  /// Das Einreihen geschieht synchron beim Aufruf, die Reihenfolge der Aufrufe
  /// bleibt also erhalten. Fehler von [vorgang] erreichen den Aufrufer über
  /// das Ergebnis und halten folgende Vorgänge nicht auf.
  Future<T> reiheEin<T>({
    required Object speicher,
    required String heroId,
    required Future<T> Function() vorgang,
  }) {
    final proHeld = _laufend[speicher] ??= <String, Future<void>>{};
    final vorige = proHeld[heroId] ?? Future<void>.value();
    final ergebnis = vorige.then<T>((_) => vorgang());
    // Das Kettenglied schluckt den Fehler, damit der nächste Vorgang läuft;
    // der Aufrufer bekommt ihn über [ergebnis].
    final erledigt = ergebnis.then<void>((_) {}, onError: (Object _) {});
    proHeld[heroId] = erledigt;
    erledigt.then((_) {
      if (identical(proHeld[heroId], erledigt)) {
        proHeld.remove(heroId);
      }
    });
    return ergebnis;
  }
}
