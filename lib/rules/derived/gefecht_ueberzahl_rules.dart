// Kämpfe mit mehreren Beteiligten (WdS S. 81, optional) und die Aktion
// Taktik (ebd., als Aktion auch S. 55). Reine Funktionen über der flüchtigen
// Begegnung; die eigene Seite übergibt der Aufrufer als Zahl bzw. IDs.

import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';

import 'gefecht_gegner_rules.dart' show gefechtsGegnerHandelt;

/// Höchstens drei Gegner hat ein Kämpfer im Blick (WdS S. 81).
const int kGefechtsGegnerImBlick = 3;

/// Höchster INI-Bonus aus Überzahl (WdS S. 81).
const int kGefechtsUeberzahlIniMax = 4;

/// Höchstens so viele INI-Punkte verteilt eine gelungene Taktik (WdS S. 81).
const int kGefechtsTaktikIniMax = 6;

/// Ein Gegner zählt für die Überzahl, wenn er kämpft und jemanden im
/// Nahkampf bindet. Sehr große Wesen zählen nicht (WdS S. 114, dort für
/// Tiere; im Konzept auf alle Gegner übertragen).
bool gefechtsGegnerZaehltFuerUeberzahl(Gefechtsgegner g) =>
    gefechtsGegnerHandelt(g) &&
    g.bindet != null &&
    g.groesse != GefechtsGroesse.sehrGross;

/// Kräfteverhältnis der beiden Seiten im Nahkampf.
class GefechtsUeberzahl {
  /// Wird ausschließlich von [gefechtsUeberzahl] gebildet.
  const GefechtsUeberzahl({
    required this.eigene,
    required this.gegner,
    required this.iniBonusEigene,
    required this.iniBonusGegner,
    required this.aufgehoben,
  });
  final int eigene, gegner;

  /// INI-Bonus für jeden Kämpfer der jeweiligen Seite (0 bis 4).
  final int iniBonusEigene, iniBonusGegner;

  /// Die gegnerische Überzahl wurde durch Taktik aufgehoben.
  final bool aufgehoben;

  /// Köpfe, um die die Gegner in der Überzahl sind (0, wenn nicht).
  int get ueberzahlGegner => gegner > eigene ? gegner - eigene : 0;
}

/// WdS S. 81: Die Partei in der Überzahl erhält INI +1 je Kopf Überzahl,
/// höchstens +4. Eine gelungene Taktik zum Aufheben nimmt den Gegnern
/// diesen Bonus; die Paarungen legt dann die Bindung der Gegner fest.
GefechtsUeberzahl gefechtsUeberzahl(
  Gefechtsbegegnung b, {
  required int eigeneNahkaempfer,
}) {
  if (eigeneNahkaempfer < 0) {
    throw ArgumentError('Die eigene Seite kann nicht negativ sein.');
  }
  final gegner = b.gegner.values
      .where(gefechtsGegnerZaehltFuerUeberzahl)
      .length;
  int bonus(int a, int b) {
    final d = a - b;
    return d <= 0
        ? 0
        : d > kGefechtsUeberzahlIniMax
        ? kGefechtsUeberzahlIniMax
        : d;
  }

  final aufgehoben = b.taktik?.ueberzahlAufgehoben ?? false;
  return GefechtsUeberzahl(
    eigene: eigeneNahkaempfer,
    gegner: gegner,
    iniBonusEigene: bonus(eigeneNahkaempfer, gegner),
    iniBonusGegner: aufgehoben ? 0 : bonus(gegner, eigeneNahkaempfer),
    aufgehoben: aufgehoben,
  );
}

/// Lage eines Verteidigers gegen die Gegner, die ihn binden.
class GefechtsVerteidigerlage {
  /// Wird ausschließlich von [gefechtsVerteidigerlage] gebildet.
  const GefechtsVerteidigerlage(this.gegnerIds);

  /// Zählende Gegner, die diesen Teilnehmer binden, in Erfassungsfolge.
  final List<String> gegnerIds;
  int get gegner => gegnerIds.length;

  /// Ab dem vierten Gegner steht einer im Rücken und ist nicht parierbar.
  int get imRuecken =>
      gegner > kGefechtsGegnerImBlick ? gegner - kGefechtsGegnerImBlick : 0;

  /// Erschwernis auf Paraden (PA-Basis −1 je weiterem Gegner im Blick).
  int get paradeErschwernis =>
      gefechtsAbwehrErschwernisWeitereGegner(gegner, ausweichen: false);

  /// Erschwernis auf Ausweichen (PA-Basis −1 und Ausweichen −1 je weiterem).
  int get ausweichenErschwernis =>
      gefechtsAbwehrErschwernisWeitereGegner(gegner, ausweichen: true);

  /// Wer von mehreren Gegnern gebunden ist, wird von ihnen mit AT +1
  /// angegriffen (Hinweis für die Meisterseite).
  bool get gegnerInUeberzahl => gegner >= 2;
}

/// Zählende Gegner, die [teilnehmerId] binden.
GefechtsVerteidigerlage gefechtsVerteidigerlage(
  Gefechtsbegegnung b,
  String teilnehmerId,
) => GefechtsVerteidigerlage(
  List.unmodifiable([
    for (final g in b.gegner.values)
      if (gefechtsGegnerZaehltFuerUeberzahl(g) && g.bindet == teilnehmerId)
        g.id,
  ]),
);

/// WdS S. 81: Je zusätzlichem Gegner PA-Basis −1 (auf Parade und
/// Ausweichen), Ausweichen zusätzlich −1; höchstens drei Gegner im Blick,
/// also höchstens 2 bzw. 4. Ein vierter Gegner bringt keinen weiteren Malus.
int gefechtsAbwehrErschwernisWeitereGegner(
  int gegner, {
  required bool ausweichen,
}) {
  final weitere = gegner <= 1
      ? 0
      : gegner > kGefechtsGegnerImBlick
      ? kGefechtsGegnerImBlick - 1
      : gegner - 1;
  return ausweichen ? 2 * weitere : weitere;
}

/// WdS S. 81: Angreifer in der Überzahl haben AT +1.
bool gefechtsAngriffInUeberzahl({required int angreiferAufZiel}) =>
    angreiferAufZiel >= 2;

/// Erschwernis der Kriegskunst-Probe, mit der die Taktik die gegnerische
/// Überzahl aufhebt: die doppelte Überzahl der Gegner (WdS S. 81).
int gefechtsTaktikAufhebungErschwernis(GefechtsUeberzahl u) =>
    2 * u.ueberzahlGegner;

/// Verteilt die TaP* einer gelungenen Taktik möglichst gleichmäßig.
///
/// [empfaenger] sind die Kampfgefährten mit positivem TaW Kriegskunst, ohne
/// den Anführer; höchstens 6 Punkte insgesamt (WdS S. 81). Überzählige Reste
/// gehen an die zuerst genannten Empfänger.
Map<String, int> gefechtsTaktikVerteilung({
  required int tapStern,
  required List<String> empfaenger,
}) {
  if (tapStern < 0) throw ArgumentError('TaP* einer gelungenen Probe.');
  if (empfaenger.toSet().length != empfaenger.length) {
    throw ArgumentError('Jeder Empfänger nur einmal.');
  }
  if (empfaenger.isEmpty) return const {};
  final punkte = tapStern > kGefechtsTaktikIniMax
      ? kGefechtsTaktikIniMax
      : tapStern;
  final je = punkte ~/ empfaenger.length;
  final rest = punkte % empfaenger.length;
  return Map.unmodifiable({
    for (var i = 0; i < empfaenger.length; i++)
      empfaenger[i]: je + (i < rest ? 1 : 0),
  });
}

/// Misslungene Taktik: Jeder Positionierte verliert 1 INI (WdS S. 81).
Map<String, int> gefechtsTaktikMisslungen(List<String> positionierte) =>
    Map.unmodifiable({for (final id in positionierte) id: -1});

/// Hält das bestätigte Taktikergebnis einmal pro Kampf fest.
///
/// Aufheben und INI-Verteilung schließen einander aus; der Anführer erhält
/// selbst keinen Bonus, und zusammen sind höchstens 6 Punkte verteilt.
Gefechtsbegegnung setzeGefechtstaktik(Gefechtsbegegnung b, Gefechtstaktik t) {
  if (b.taktik != null) {
    throw StateError('Die Aktion Taktik ist in diesem Kampf schon genutzt.');
  }
  if (t.anfuehrerId.isEmpty) throw ArgumentError('Anführer fehlt.');
  final boni = t.iniBoni.values;
  if (t.ueberzahlAufgehoben && t.iniBoni.isNotEmpty) {
    throw ArgumentError('Aufheben oder INI verteilen, nicht beides.');
  }
  if ((t.iniBoni[t.anfuehrerId] ?? 0) > 0) {
    throw ArgumentError('Der Anführer verteilt keine Punkte an sich selbst.');
  }
  if (boni.any((v) => v < -1) ||
      boni.where((v) => v > 0).fold(0, (a, v) => a + v) >
          kGefechtsTaktikIniMax) {
    throw ArgumentError('Höchstens 6 Punkte, je Misserfolg −1 INI.');
  }
  return b.copyWith(taktik: t);
}
