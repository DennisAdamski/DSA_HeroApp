import 'package:flutter/foundation.dart';

/// Abschnitte der Verwaltung, die eine Kachel der Spielansicht ansteuern kann.
///
/// Eigener Aufzählungstyp, weil die Tab-IDs der Verwaltung in `lib/ui/` liegen
/// und UI2 von dort nichts importiert. Die Zuordnung auf den Bestands-Tab macht
/// ausschließlich die Brücke (`WorkspaceManagementBody`).
enum KartoVerwaltungsAbschnitt {
  /// Vitalwerte, Statuswerte, Eigenschaften, Vor- und Nachteile.
  uebersicht('Übersicht'),

  /// Talentwerte und Spezialisierungen.
  talente('Talente'),

  /// Kampftechniken, Waffen, Rüstung und Manöver.
  kampf('Kampf'),

  /// Zauber und magische Kenntnisse.
  magie('Magie'),

  /// Ausrüstung und Gegenstände.
  inventar('Inventar'),

  /// Chroniken, Kontakte und Abenteuer.
  notizen('Chroniken, Kontakte & Abenteuer'),

  /// Reisebericht und Meilensteine.
  reisebericht('Reisebericht'),

  /// Vertraute und Begleiter.
  begleiter('Begleiter'),

  /// Gruppenmitglieder und Einladungen.
  gruppe('Gruppe');

  const KartoVerwaltungsAbschnitt(this.titel);

  /// Name des Abschnitts, wie ihn die Verwaltung beschriftet.
  final String titel;
}

/// Wunsch der Spielansicht, einen Abschnitt der Verwaltung aufzuschlagen.
///
/// Der Workspace schreibt ihn, die Verwaltung liest ihn. Anders als ein
/// `ValueNotifier` meldet [waehle] auch denselben Abschnitt ein zweites Mal:
/// wer zwischendurch von Hand einen anderen Tab gewählt hat, soll mit dem
/// Knopf wieder dorthin kommen.
///
/// Die Verwaltung wird erst beim ersten Besuch gebaut; sie liest [abschnitt]
/// deshalb auch beim Start und nicht nur über den Listener.
class KartoVerwaltungsZiel extends ChangeNotifier {
  KartoVerwaltungsAbschnitt? _abschnitt;

  /// Zuletzt gewünschter Abschnitt; `null`, solange nichts gewünscht wurde.
  KartoVerwaltungsAbschnitt? get abschnitt => _abschnitt;

  /// Wünscht [abschnitt] und benachrichtigt alle Zuhörer.
  void waehle(KartoVerwaltungsAbschnitt abschnitt) {
    _abschnitt = abschnitt;
    notifyListeners();
  }

  /// Quittiert den Wunsch, sobald die Verwaltung ihn umgesetzt hat.
  ///
  /// Ohne Benachrichtigung: sonst riefe jede Quittung die Zuhörer erneut.
  void erledigt() => _abschnitt = null;
}
