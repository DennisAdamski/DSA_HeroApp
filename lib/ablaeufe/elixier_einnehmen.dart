import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/catalog/alchimikum_def.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_elixier_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_rules.dart';

/// Anwendungsablauf „Elixier einnehmen“ (TRANK, Teilstand 2).
///
/// Legt die Eigenschaftsänderungen des Elixiers als Wirkungsquellen am frisch
/// geladenen Laufzeitzustand an und hängt einen Protokolleintrag an – beides in
/// **einem** Dokument. Eine Wiederholung derselben Vorgangs-ID legt nichts
/// doppelt an. Das Abbuchen des Stücks im Inventar ist ein eigener Schritt am
/// Bogen und gehört dem Aufrufer.
class ElixierEinnehmen {
  /// Erzeugt den Ablauf mit Heldenspeicher, Uhr und ID-Quelle.
  const ElixierEinnehmen({
    required this.repository,
    required this.uhr,
    required this.neueId,
  });

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Protokoll und Änderungsstempel.
  final DateTime Function() uhr;

  /// Liefert eine neue Instanz-ID je Wirkungsquelle.
  final String Function() neueId;

  /// Nimmt [mittel] in [stufe] für den Helden [heroId] ein.
  ///
  /// Gibt die angelegten Eigenschaftsänderungen zurück (bei einer Wiederholung
  /// leer). Wirft einen [StateError], wenn die Stufe keine Eigenschaften
  /// verändert.
  Future<List<AlchimikumEigenschaft>> uebernimm({
    required String heroId,
    required AlchimikumDef mittel,
    required String stufe,
    required String vorgangId,
  }) async {
    final wirkung = alchimikumStufe(mittel, stufe);
    if (wirkung == null || !wirkung.hatEigenschaftsWirkung) {
      throw StateError(
        '${mittel.name} verändert in Qualität $stufe keine '
        'Eigenschaften.',
      );
    }
    final jetzt = uhr();
    var angelegt = const <AlchimikumEigenschaft>[];
    await aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) {
        if (elixierBereitsEingenommen(aktuell, vorgangId)) {
          return aktuell;
        }
        final instanzen = elixierInstanzen(
          mittel: mittel,
          stufe: stufe,
          vorgangsId: vorgangId,
          neueId: neueId,
        );
        if (instanzen.isEmpty) {
          throw StateError(
            '${mittel.name} (Qualität $stufe) hat keine '
            'verwertbaren Eigenschaftsänderungen.',
          );
        }
        angelegt = wirkung.eigenschaften;
        return nimmElixierEin(aktuell, instanzen).withAppendedDiceLog(
          baueElixierProtokoll(
            mittel: mittel,
            stufe: stufe,
            eigenschaften: wirkung.eigenschaften,
            zeitpunkt: jetzt,
          ),
        );
      },
    );
    return angelegt;
  }
}
