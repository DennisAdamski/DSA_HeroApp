import 'dart:convert';

import 'package:dsa_heldenverwaltung/ablaeufe/held_schreiben.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/import_vorgang.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/vorgaenge_wiederaufnehmen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/vorgangsjournal.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Übernimmt eingebettete eigene Katalogeinträge eines Exports.
typedef ImportKatalogUebernehmen = Future<void> Function(
  List<HeroTransferCatalogEntry> eintraege,
);

/// Legt ein Galeriebild ab und liefert den tatsächlich vergebenen
/// Dateinamen; leer bedeutet „nicht gespeichert“ (`AvatarFileStorage`).
typedef ImportGaleriebildSpeichern = Future<String> Function({
  required String heroId,
  required String entryId,
  required List<int> bytes,
});

/// Legt das Legacy-Hauptbild eines alten Exports ab und liefert den
/// tatsächlich vergebenen Dateinamen; leer bedeutet „nicht gespeichert“.
typedef ImportHauptbildSpeichern = Future<String> Function({
  required String heroId,
  required List<int> bytes,
});

/// Ergebnis eines Heldenimports.
class HeldImportErgebnis {
  /// Erzeugt das Ergebnis.
  const HeldImportErgebnis({
    required this.heroId,
    required this.fehlendeBilder,
  });

  /// ID des importierten (ggf. neu angelegten) Helden.
  final String heroId;

  /// Bilder, die nicht gespeichert werden konnten, und unter einer neuen ID
  /// zusätzlich Galerieeinträge ohne Bilddaten im Export.
  final int fehlendeBilder;
}

/// Anwendungsablauf „Held importieren“ (ARCH-05).
///
/// Übernimmt einen Export samt eigener Katalogeinträge, Bildern und
/// Laufzeitzustand. Der Held wird **einmal** gespeichert, nachdem seine
/// Bilder abgelegt sind; jeder abgelegte Galerieeintrag trägt dann den
/// Dateinamen, den die Ablage tatsächlich vergeben hat. Ein Bild, das sich
/// nicht speichern lässt, wird gezählt, bricht den Import aber nicht ab — der
/// Held ist wichtiger als sein Porträt. Unter einer neuen ID fehlt es dann in
/// der Galerie; unter derselben ID bleibt sein bisheriger Verweis stehen.
/// Alle übrigen Fehler erreichen den Aufrufer unverändert. Die Auswahl des
/// Helden bleibt beim Aufrufer.
///
/// Bilder, Bogen und Zustand sind getrennte Schreibvorgänge. Der Import
/// vermerkt sich deshalb vor dem ersten Bild im [journal] und nach jedem
/// Schritt (ARCH-06). Scheitert ein Schritt, wird der Vorgang sofort über
/// [VorgaengeWiederaufnehmen.fuehreFort] ausgeglichen bzw. zu Ende geführt;
/// bricht die App ab, erledigt das der Wiederanlauf beim nächsten Start.
/// Eigene Katalogeinträge stehen außerhalb des Journals: ihr Übernehmen ist
/// ein wiederholbares Einfügen und bleibt auch bei Abbruch bestehen.
class HeldImportieren {
  /// Erzeugt den Ablauf mit seinen Abhängigkeiten.
  const HeldImportieren({
    required this.repository,
    required this.speichere,
    required this.uebernimmKatalog,
    required this.speichereGaleriebild,
    required this.speichereHauptbild,
    required this.loescheBild,
    required this.journal,
    required this.neueId,
    required this.uhr,
    required this.maxHelden,
  });

  /// Heldenspeicher für Limit und Zustand.
  final HeroRepository repository;

  /// Normalisiert und speichert den Helden; reiht sich selbst ein.
  final BogenSpeichern speichere;

  /// Übernimmt eigene Katalogeinträge des Exports.
  final ImportKatalogUebernehmen uebernimmKatalog;

  /// Legt ein Galeriebild ab.
  final ImportGaleriebildSpeichern speichereGaleriebild;

  /// Legt das Legacy-Hauptbild eines alten Exports ab.
  final ImportHauptbildSpeichern speichereHauptbild;

  /// Löscht ein abgelegtes Bild, wenn der Import ausgeglichen wird.
  final BildLoeschen loescheBild;

  /// Journal offener Vorgänge (ARCH-06).
  final Vorgangsjournal journal;

  /// Vergibt die ID eines neu angelegten Helden.
  final String Function() neueId;

  /// Zeitquelle für den Stempel des Laufzeitzustands.
  final DateTime Function() uhr;

  /// Höchstzahl an Helden je Nutzer.
  final int maxHelden;

  /// Importiert [bundle]; mit [neuAnlegen] unter einer neuen ID.
  ///
  /// Das Heldenlimit gilt immer, wenn die Ziel-ID noch nicht existiert —
  /// auch beim Import eines bisher unbekannten Helden ohne „Als neu
  /// erstellen“. Liefert die Ziel-ID und die Zahl ausgelassener Bilder.
  Future<HeldImportErgebnis> importiere(
    HeroTransferBundle bundle, {
    required bool neuAnlegen,
  }) async {
    final heroId = neuAnlegen ? neueId() : bundle.hero.id;
    final vorhandene = await repository.listHeroes();
    final vorhandener = vorhandene
        .where((held) => held.id == heroId)
        .firstOrNull;
    if (vorhandener == null && vorhandene.length >= maxHelden) {
      throw Exception(
        'Maximale Anzahl von $maxHelden Helden erreicht. '
        'Bitte lösche einen bestehenden Helden, bevor du einen neuen '
        'importierst.',
      );
    }

    final katalogeintraege = bundle.catalogEntries;
    if (katalogeintraege != null && katalogeintraege.isNotEmpty) {
      await uebernimmKatalog(katalogeintraege);
    }

    var vorgang = ImportVorgang(
      id: 'import:$heroId:${uhr().toUtc().microsecondsSinceEpoch}',
      heroId: heroId,
      begonnen: uhr(),
      schritt: ImportSchritt.bilderAblegen,
      heldHashVorher: vorhandener == null ? null : heroContentHash(vorhandener),
      dateien: const <String>[],
      zustand: bundle.state.toJson(),
    );
    await journal.merke(vorgang.id, vorgang.toJson());
    final wiederanlauf = VorgaengeWiederaufnehmen(
      repository: repository,
      journal: journal,
      loescheBild: loescheBild,
      uhr: uhr,
    );

    final ({HeroAppearance aussehen, int fehlend}) bilder;
    try {
      bilder = await _legeBilderAb(
        bundle: bundle,
        heroId: heroId,
        neuAnlegen: neuAnlegen,
        abgelegt: (name) async {
          vorgang = vorgang.mitDatei(name);
          await journal.merke(vorgang.id, vorgang.toJson());
        },
      );
      await speichere(
        bundle.hero.copyWith(id: heroId, appearance: bilder.aussehen),
      );
      vorgang = vorgang.alsHeldGespeichert();
      await journal.merke(vorgang.id, vorgang.toJson());
    } on Object {
      await _versucheAbschluss(wiederanlauf, vorgang);
      rethrow;
    }

    try {
      await aendereGespeichertenZustand(
        repository: repository,
        heroId: heroId,
        aenderung: (_) => bundle.state,
        uhr: uhr,
      );
      await journal.erledige(vorgang.id);
    } on Object {
      // Der Held steht schon; ein zweiter Versuch trägt den Zustand nach.
      // Scheitert auch er, bleibt der Eintrag für den Neustart.
      if (!await _versucheAbschluss(wiederanlauf, vorgang)) {
        rethrow;
      }
    }
    return HeldImportErgebnis(heroId: heroId, fehlendeBilder: bilder.fehlend);
  }

  // Schließt [vorgang] nach einem gescheiterten Schritt ab; liefert, ob das
  // gelang. Der ursprüngliche Fehler bleibt der maßgebliche.
  Future<bool> _versucheAbschluss(
    VorgaengeWiederaufnehmen wiederanlauf,
    ImportVorgang vorgang,
  ) async {
    try {
      await wiederanlauf.fuehreFort(vorgang);
      return true;
    } on Object {
      return false;
    }
  }

  // Legt die Bilder des Exports ab und baut daraus die Galerie des Helden.
  Future<({HeroAppearance aussehen, int fehlend})> _legeBilderAb({
    required HeroTransferBundle bundle,
    required String heroId,
    required bool neuAnlegen,
    required Future<void> Function(String dateiname) abgelegt,
  }) async {
    final aussehen = bundle.hero.appearance;
    final galerie = aussehen.avatarGallery;
    final neueNamen = <String, String>{};
    final abgelegteEintraege = <String, AvatarGalleryEntry>{};
    final gescheitert = <String>{};
    var fehlend = 0;

    final galeriebilder = <Map<String, dynamic>>[
      for (final bild in bundle.galleryImages ?? const <Map<String, dynamic>>[])
        if (bild['base64'] is String && (bild['base64'] as String).isNotEmpty)
          bild,
    ];
    final paketeintraege = <AvatarGalleryEntry>[];
    if (galeriebilder.isNotEmpty) {
      for (final bild in galeriebilder) {
        final eintrag = AvatarGalleryEntry.fromJson(
          Map<String, dynamic>.from(bild)..remove('base64'),
        );
        paketeintraege.add(eintrag);
        final name = await _versuche(
          () => speichereGaleriebild(
            heroId: heroId,
            entryId: eintrag.id,
            bytes: base64Decode(bild['base64'] as String),
          ),
        );
        if (name == null) {
          fehlend++;
          gescheitert.add(eintrag.id);
          continue;
        }
        await abgelegt(name);
        neueNamen[eintrag.fileName] = name;
        abgelegteEintraege[eintrag.id] = eintrag.copyWith(fileName: name);
      }
    } else if (bundle.avatarBase64 != null && bundle.avatarBase64!.isNotEmpty) {
      // Alter Export ohne Galeriebilder: Das Hauptbild gehört zum Eintrag
      // mit dem alten Dateinamen, ersatzweise zum aktiven Bild; fehlt beides,
      // bekommt es einen Legacy-Eintrag wie beim Laden alter Helden.
      final ziel =
          galerie
              .where((e) => e.fileName == aussehen.avatarFileName)
              .firstOrNull ??
          aussehen.aktivesBild ??
          AvatarGalleryEntry(
            id: '${heroId}_legacy',
            fileName: aussehen.avatarFileName,
          );
      paketeintraege.add(ziel);
      final name = await _versuche(
        () => speichereHauptbild(
          heroId: heroId,
          bytes: base64Decode(bundle.avatarBase64!),
        ),
      );
      if (name == null) {
        fehlend++;
        gescheitert.add(ziel.id);
      } else {
        await abgelegt(name);
        neueNamen[ziel.fileName] = name;
        abgelegteEintraege[ziel.id] = ziel.copyWith(fileName: name);
      }
    }

    // Ohne abgelegtes Bild bleibt ein Eintrag unter derselben ID, wie er
    // war: Seine Datei liegt womöglich schon in diesem Speicher bzw. in der
    // Cloud des Kontos. Unter einer neuen ID zeigte er dagegen auf die Datei
    // des Originals — Löschen in der Kopie entfernte sie dort —, deshalb
    // fällt er weg und wird gezählt.
    final ergebnis = <AvatarGalleryEntry>[];
    final entfallen = <AvatarGalleryEntry>[];
    final gesehen = <String>{};
    for (final eintrag in [...galerie, ...paketeintraege]) {
      if (!gesehen.add(eintrag.id)) {
        continue;
      }
      final neu = abgelegteEintraege[eintrag.id];
      if (neu != null) {
        ergebnis.add(neu);
      } else if (!neuAnlegen) {
        ergebnis.add(eintrag);
      } else {
        entfallen.add(eintrag);
        if (!gescheitert.contains(eintrag.id)) {
          fehlend++;
        }
      }
    }

    // Verweise nur bereinigen, wenn ihr Eintrag tatsächlich entfallen ist.
    final entfalleneIds = entfallen.map((e) => e.id).toSet();
    final aktiv = entfalleneIds.contains(aussehen.aktivesBildId)
        ? (ergebnis.isEmpty ? '' : ergebnis.first.id)
        : aussehen.aktivesBildId;
    final primaerEntfallen = entfalleneIds.contains(aussehen.primaerbildId);
    final alterName = aussehen.avatarFileName;
    final hauptbild =
        neueNamen[alterName] ??
        (entfallen.any((e) => e.fileName == alterName) ? '' : alterName);
    return (
      aussehen: aussehen.copyWith(
        avatarFileName: hauptbild,
        avatarGallery: ergebnis,
        aktivesBildId: aktiv,
        primaerbildId: primaerEntfallen ? '' : null,
        avatarSnapshot: primaerEntfallen ? () => null : null,
      ),
      fehlend: fehlend,
    );
  }

  // Liefert den vergebenen Dateinamen oder `null`, wenn die Ablage scheitert
  // oder keinen Namen vergibt.
  Future<String?> _versuche(Future<String> Function() ablegen) async {
    try {
      final name = await ablegen();
      return name.isEmpty ? null : name;
    } on Object {
      return null;
    }
  }
}
