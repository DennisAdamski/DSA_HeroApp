import 'package:dsa_heldenverwaltung/ablaeufe/import_vorgang.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/vorgangsjournal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Löscht eine abgelegte Bilddatei (lokal und, wo vorhanden, in der Cloud).
typedef BildLoeschen = Future<void> Function(String dateiname);

/// Wie ein offener Vorgang abgeschlossen wurde.
enum VorgangsAusgang {
  /// Zu Ende geführt: Der Held war gespeichert, der Rest wurde nachgetragen.
  fortgesetzt,

  /// Ausgeglichen: Der Held war nicht gespeichert, abgelegte Dateien wurden
  /// entfernt.
  ausgeglichen,
}

/// Ergebnis eines Wiederanlaufs.
class WiederanlaufBericht {
  /// Erzeugt den Bericht.
  const WiederanlaufBericht({
    this.fortgesetzt = 0,
    this.ausgeglichen = 0,
    this.unbekannt = 0,
    this.gescheitert = 0,
  });

  /// Zu Ende geführte Vorgänge.
  final int fortgesetzt;

  /// Ausgeglichene Vorgänge.
  final int ausgeglichen;

  /// Einträge unbekannter Art; sie bleiben im Journal.
  final int unbekannt;

  /// Vorgänge, deren Abschluss erneut scheiterte; sie bleiben im Journal.
  final int gescheitert;

  @override
  String toString() =>
      'Wiederanlauf(fortgesetzt: $fortgesetzt, ausgeglichen: $ausgeglichen, '
      'unbekannt: $unbekannt, gescheitert: $gescheitert)';
}

/// Anwendungsablauf „Vorgänge wiederaufnehmen“ (ARCH-06).
///
/// Schließt Vorgänge ab, die ein Abbruch im [journal] offen gelassen hat.
/// Heute ist das allein der Heldenimport ([ImportVorgang]):
///
/// - **Zu Ende führen**, sobald der Import-Held gespeichert ist — vermerkt
///   oder daran erkennbar, dass der gespeicherte Held vom Stand vor dem
///   Import abweicht. Der Zustand des Exports wird eingereiht und gestempelt
///   geschrieben, die Bilder bleiben.
/// - **Ausgleichen** sonst: Abgelegte Bilder, auf die der gespeicherte Held
///   nicht verweist, werden gelöscht. Dateien des vorigen Stands, die der
///   Import unter demselben Namen überschrieben hat, lassen sich nicht
///   zurückholen.
///
/// Beides ist wiederholbar: Ein erledigter Eintrag ist weg, ein erneutes
/// Nachtragen schreibt denselben Inhalt. Scheitert ein Schritt, bleibt der
/// Eintrag für den nächsten Lauf stehen.
class VorgaengeWiederaufnehmen {
  /// Erzeugt den Ablauf.
  const VorgaengeWiederaufnehmen({
    required this.repository,
    required this.journal,
    required this.loescheBild,
    required this.uhr,
  });

  /// Heldenspeicher, aus dem gelesen und in den nachgetragen wird.
  final HeroRepository repository;

  /// Journal der offenen Vorgänge.
  final Vorgangsjournal journal;

  /// Löscht ein abgelegtes Bild.
  final BildLoeschen loescheBild;

  /// Zeitquelle für den Stempel nachgetragener Zustände.
  final DateTime Function() uhr;

  /// Nimmt alle offenen Vorgänge wieder auf. Wirft nie wegen eines
  /// einzelnen Vorgangs; dessen Fehler zählt als [WiederanlaufBericht.gescheitert].
  Future<WiederanlaufBericht> fuehreAus() async {
    var fortgesetzt = 0;
    var ausgeglichen = 0;
    var unbekannt = 0;
    var gescheitert = 0;
    final offene = await journal.offene();
    for (final MapEntry(key: id, value: eintrag) in offene.entries) {
      final vorgang = ImportVorgang.fromJson(id, eintrag);
      if (vorgang == null) {
        unbekannt++;
        continue;
      }
      try {
        switch (await fuehreFort(vorgang)) {
          case VorgangsAusgang.fortgesetzt:
            fortgesetzt++;
          case VorgangsAusgang.ausgeglichen:
            ausgeglichen++;
        }
      } on Object {
        gescheitert++;
      }
    }
    return WiederanlaufBericht(
      fortgesetzt: fortgesetzt,
      ausgeglichen: ausgeglichen,
      unbekannt: unbekannt,
      gescheitert: gescheitert,
    );
  }

  /// Schließt den Importvorgang [vorgang] ab und erledigt seinen Eintrag.
  ///
  /// Wird auch vom laufenden Import benutzt, wenn einer seiner Schritte
  /// scheitert. Fehler erreichen den Aufrufer; der Eintrag bleibt dann.
  Future<VorgangsAusgang> fuehreFort(ImportVorgang vorgang) async {
    final held = await repository.loadHeroById(vorgang.heroId);
    final heldGeschrieben =
        held != null &&
        (vorgang.schritt == ImportSchritt.heldGespeichert ||
            heroContentHash(held) != vorgang.heldHashVorher);
    if (heldGeschrieben) {
      final zustand = HeroState.fromJson(
        Map<String, dynamic>.of(vorgang.zustand),
      );
      await aendereGespeichertenZustand(
        repository: repository,
        heroId: vorgang.heroId,
        aenderung: (_) => zustand,
        uhr: uhr,
      );
      await journal.erledige(vorgang.id);
      return VorgangsAusgang.fortgesetzt;
    }

    final verwendet = held == null ? const <String>{} : _bilddateien(held);
    for (final datei in vorgang.dateien) {
      if (!verwendet.contains(datei)) {
        await loescheBild(datei);
      }
    }
    await journal.erledige(vorgang.id);
    return VorgangsAusgang.ausgeglichen;
  }

  // Dateinamen, auf die der Held verweist.
  Set<String> _bilddateien(HeroSheet held) {
    final aussehen = held.appearance;
    return <String>{
      if (aussehen.avatarFileName.isNotEmpty) aussehen.avatarFileName,
      for (final eintrag in aussehen.avatarGallery)
        if (eintrag.fileName.isNotEmpty) eintrag.fileName,
    };
  }
}
