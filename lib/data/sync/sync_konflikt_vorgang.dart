import 'dart:convert';

import 'package:dsa_heldenverwaltung/data/vorgangsjournal.dart';

/// Gewählte Aktion einer Heldenentscheidung (ARCH-06).
enum SyncKonfliktAktion {
  /// Lokale Fassung behalten und online durchsetzen.
  nurLokal,

  /// Online-Fassung übernehmen.
  nurOnline,

  /// Online-Fassung übernehmen, die lokale als Kopie erhalten.
  beideBehalten,

  /// Zusammengeführte Fassung (Dreiwege-Zusammenführung) schreiben.
  automatisch,
}

/// Art eines Dokuments, das ein Konfliktvorgang schreibt.
enum SyncKonfliktDokumentArt {
  /// Heldenblatt.
  held,

  /// Laufzeitzustand des Helden.
  zustand,
}

/// Ein Dokument, das eine Konfliktentscheidung ablegen muss.
///
/// Hält die **vollständige Zielfassung**: Der Wiederanlauf rechnet nichts neu
/// (keine Zusammenführung, keine Zählerdeltas). Jeder Schritt wird über den
/// Inhalt des Dokuments als erledigt erkannt, die Flags nur als Fortschritt.
class SyncKonfliktDokument {
  /// Erzeugt ein Dokument eines Vorgangs.
  const SyncKonfliktDokument({
    required this.art,
    required this.id,
    required this.ziel,
    required this.zielHash,
    required this.ausgangHash,
    required this.lokalSchreiben,
    required this.remoteSchreiben,
    this.istKopie = false,
    this.vorRevision,
    this.onlineRevision,
    this.onlineHash,
    this.onlineGeloescht = false,
    this.lokalErledigt = false,
    this.remoteErledigt = false,
    this.metaErledigt = false,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Plant ein Dokument: nicht nötige Schritte gelten sofort als erledigt.
  ///
  /// Ohne [onlineRevision] gibt es nichts, was sich als Sync-Metadatum
  /// festhalten ließe (Gateway ohne Zustandsdokumente); die Metadaten gelten
  /// dann ebenfalls als erledigt.
  factory SyncKonfliktDokument.plane({
    required SyncKonfliktDokumentArt art,
    required String id,
    required Map<String, dynamic> ziel,
    required String zielHash,
    required String? ausgangHash,
    required bool lokalSchreiben,
    required bool remoteSchreiben,
    bool istKopie = false,
    String? vorRevision,
    String? onlineRevision,
    String? onlineHash,
    bool onlineGeloescht = false,
  }) {
    return SyncKonfliktDokument(
      art: art,
      id: id,
      ziel: ziel,
      zielHash: zielHash,
      ausgangHash: ausgangHash,
      lokalSchreiben: lokalSchreiben,
      remoteSchreiben: remoteSchreiben,
      istKopie: istKopie,
      vorRevision: vorRevision,
      onlineRevision: onlineRevision,
      onlineHash: onlineHash,
      onlineGeloescht: onlineGeloescht,
      lokalErledigt: !lokalSchreiben,
      remoteErledigt: !remoteSchreiben,
      metaErledigt: !remoteSchreiben && onlineRevision == null,
    );
  }

  static const Set<String> _bekannteSchluessel = <String>{
    'art',
    'id',
    'ziel',
    'zielHash',
    'ausgangHash',
    'lokalSchreiben',
    'remoteSchreiben',
    'istKopie',
    'vorRevision',
    'onlineRevision',
    'onlineHash',
    'onlineGeloescht',
    'lokalErledigt',
    'remoteErledigt',
    'metaErledigt',
  };

  /// Heldenblatt oder Zustand.
  final SyncKonfliktDokumentArt art;

  /// Helden-ID des Dokuments (bei der Kopie deren ID).
  final String id;

  /// Zielfassung als JSON (`toJson()` in der Darstellung dieser App).
  final Map<String, dynamic> ziel;

  /// Inhalts-Hash der Zielfassung (`heroContentHash`/`heroStateContentHash`).
  final String zielHash;

  /// Inhalts-Hash der lokalen Ausgangsfassung; `null`, wenn lokal nichts lag.
  final String? ausgangHash;

  /// Ob die Zielfassung lokal abzulegen ist.
  final bool lokalSchreiben;

  /// Ob die Zielfassung online abzulegen ist.
  final bool remoteSchreiben;

  /// Ob das Dokument zur lokalen Kopie („Beide behalten“) gehört.
  final bool istKopie;

  /// Online-Revision, auf der geschrieben werden darf (`null` = neues Dokument).
  final String? vorRevision;

  /// Bestätigte Online-Revision nach dem Ablegen.
  final String? onlineRevision;

  /// Online-Inhalts-Hash zu [onlineRevision].
  final String? onlineHash;

  /// Ob das Online-Dokument ein Tombstone ist.
  final bool onlineGeloescht;

  /// Fortschritt: lokal abgelegt.
  final bool lokalErledigt;

  /// Fortschritt: online abgelegt und bestätigt.
  final bool remoteErledigt;

  /// Fortschritt: Basis und Sync-Metadaten nachgeführt.
  final bool metaErledigt;

  /// Unbekannte JSON-Felder späterer Versionen; sie werden zurückgeschrieben.
  final Map<String, Object?> unbekannteFelder;

  /// Kopie mit geändertem Fortschritt bzw. bestätigtem Online-Ergebnis.
  SyncKonfliktDokument kopiere({
    bool? lokalErledigt,
    bool? remoteErledigt,
    bool? metaErledigt,
    String? onlineRevision,
    String? onlineHash,
  }) {
    return SyncKonfliktDokument(
      art: art,
      id: id,
      ziel: ziel,
      zielHash: zielHash,
      ausgangHash: ausgangHash,
      lokalSchreiben: lokalSchreiben,
      remoteSchreiben: remoteSchreiben,
      istKopie: istKopie,
      vorRevision: vorRevision,
      onlineRevision: onlineRevision ?? this.onlineRevision,
      onlineHash: onlineHash ?? this.onlineHash,
      onlineGeloescht: onlineGeloescht,
      lokalErledigt: lokalErledigt ?? this.lokalErledigt,
      remoteErledigt: remoteErledigt ?? this.remoteErledigt,
      metaErledigt: metaErledigt ?? this.metaErledigt,
      unbekannteFelder: unbekannteFelder,
    );
  }

  /// JSON für das Journal.
  Map<String, Object?> toJson() => <String, Object?>{
    ...unbekannteFelder,
    'art': art.name,
    'id': id,
    'ziel': ziel,
    'zielHash': zielHash,
    'ausgangHash': ausgangHash,
    'lokalSchreiben': lokalSchreiben,
    'remoteSchreiben': remoteSchreiben,
    'istKopie': istKopie,
    'vorRevision': vorRevision,
    'onlineRevision': onlineRevision,
    'onlineHash': onlineHash,
    'onlineGeloescht': onlineGeloescht,
    'lokalErledigt': lokalErledigt,
    'remoteErledigt': remoteErledigt,
    'metaErledigt': metaErledigt,
  };

  /// Liest ein Dokument; `null`, wenn Pflichtangaben fehlen.
  static SyncKonfliktDokument? fromJson(Object? roh) {
    if (roh is! Map) {
      return null;
    }
    final art = SyncKonfliktDokumentArt.values
        .where((kandidat) => kandidat.name == roh['art'])
        .firstOrNull;
    final id = roh['id'];
    final ziel = roh['ziel'];
    final zielHash = roh['zielHash'];
    if (art == null ||
        id is! String ||
        id.isEmpty ||
        ziel is! Map ||
        zielHash is! String) {
      return null;
    }
    return SyncKonfliktDokument(
      art: art,
      id: id,
      ziel: _tiefeKopie(ziel),
      zielHash: zielHash,
      ausgangHash: roh['ausgangHash'] as String?,
      lokalSchreiben: roh['lokalSchreiben'] == true,
      remoteSchreiben: roh['remoteSchreiben'] == true,
      istKopie: roh['istKopie'] == true,
      vorRevision: roh['vorRevision'] as String?,
      onlineRevision: roh['onlineRevision'] as String?,
      onlineHash: roh['onlineHash'] as String?,
      onlineGeloescht: roh['onlineGeloescht'] == true,
      lokalErledigt: roh['lokalErledigt'] == true,
      remoteErledigt: roh['remoteErledigt'] == true,
      metaErledigt: roh['metaErledigt'] == true,
      unbekannteFelder: <String, Object?>{
        for (final eintrag in roh.entries)
          if (eintrag.key is String &&
              !_bekannteSchluessel.contains(eintrag.key))
            eintrag.key as String: eintrag.value,
      },
    );
  }
}

/// Grund, aus dem ein Vorgang nicht weiterlaufen darf.
class SyncKonfliktBlockade {
  /// Erzeugt die Angabe.
  const SyncKonfliktBlockade({required this.grund, required this.seit});

  /// Das lokale Dokument weicht von Ausgangs- und Zielfassung ab.
  static const String lokalGeaendert = 'lokalGeaendert';

  /// Das Online-Dokument wurde seit der Entscheidung anderweitig geändert.
  static const String onlineGeaendert = 'onlineGeaendert';

  /// Maschinenlesbarer Grund.
  final String grund;

  /// Zeitpunkt der Feststellung.
  final DateTime seit;
}

/// Dauerhafter Vorgang „Konfliktentscheidung“ im [Vorgangsjournal] (ARCH-06).
///
/// Beschreibt eine vollständig geplante Entscheidung über einen Helden samt
/// zugehörigem Zustand (und gegebenenfalls einer lokalen Kopie). Er wird vor
/// dem ersten überschreibenden Zugriff gespeichert und erst entfernt, wenn
/// alle Dokumente lokal, online und in den Sync-Metadaten vollständig sind.
class SyncKonfliktVorgang {
  /// Erzeugt einen Vorgang.
  const SyncKonfliktVorgang({
    required this.kontoId,
    required this.begonnen,
    required this.originalId,
    required this.aktion,
    required this.dokumente,
    this.kopieId,
    this.blockade,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Kennung der Vorgangsart im Journal.
  static const String art = kSyncKonfliktVorgangsart;

  /// Aktuelle Formatversion; höhere Versionen werden nicht angefasst.
  static const int formatVersion = 1;

  static const Set<String> _bekannteSchluessel = <String>{
    'art',
    'version',
    'kontoId',
    'begonnen',
    'originalId',
    'kopieId',
    'aktion',
    'blockade',
    'dokumente',
  };

  /// Journalschlüssel des Vorgangs zum Helden [originalId].
  static String schluessel(String originalId) => '$art-$originalId';

  /// Konto, in dessen Profil entschieden wurde.
  final String kontoId;

  /// Beginn der Entscheidung.
  final DateTime begonnen;

  /// ID des Helden, über dessen Konflikt entschieden wurde.
  final String originalId;

  /// Feste ID der lokalen Kopie („Beide behalten“), einmal vergeben.
  final String? kopieId;

  /// Gewählte Aktion.
  final SyncKonfliktAktion aktion;

  /// Zu schreibende Dokumente.
  final List<SyncKonfliktDokument> dokumente;

  /// Gesetzt, wenn eine weitere Änderung den Vorgang anhält.
  final SyncKonfliktBlockade? blockade;

  /// Unbekannte JSON-Felder späterer Versionen.
  final Map<String, Object?> unbekannteFelder;

  /// Journalschlüssel dieses Vorgangs.
  String get id => schluessel(originalId);

  /// Alle IDs, die der Vorgang für normalen Sync reserviert.
  Set<String> get betroffeneIds => <String>{originalId, ?kopieId};

  /// Kopie mit ersetzten Dokumenten und/oder Blockade.
  SyncKonfliktVorgang kopiere({
    List<SyncKonfliktDokument>? dokumente,
    SyncKonfliktBlockade? blockade,
    bool blockadeLoeschen = false,
  }) {
    return SyncKonfliktVorgang(
      kontoId: kontoId,
      begonnen: begonnen,
      originalId: originalId,
      kopieId: kopieId,
      aktion: aktion,
      dokumente: dokumente ?? this.dokumente,
      blockade: blockadeLoeschen ? null : (blockade ?? this.blockade),
      unbekannteFelder: unbekannteFelder,
    );
  }

  /// JSON für das Journal.
  Map<String, Object?> toJson() => <String, Object?>{
    ...unbekannteFelder,
    'art': art,
    'version': formatVersion,
    'kontoId': kontoId,
    'begonnen': begonnen.toUtc().toIso8601String(),
    'originalId': originalId,
    'kopieId': kopieId,
    'aktion': aktion.name,
    if (blockade != null)
      'blockade': <String, Object?>{
        'grund': blockade!.grund,
        'seit': blockade!.seit.toUtc().toIso8601String(),
      },
    'dokumente': <Object?>[for (final d in dokumente) d.toJson()],
  };

  /// Liest einen Journaleintrag der Art [art].
  ///
  /// Fremde Arten liefern `null` (nicht Sache dieses Vorgangs). Alles andere
  /// ergibt ein [SyncKonfliktEintrag]: lesbar und bekannt, oder als unbekannt
  /// mit den IDs, die der Eintrag noch benennt.
  static SyncKonfliktEintrag? lies(
    String journalId,
    Map<String, Object?> json, {
    required String kontoId,
  }) {
    final eintragArt = json['art'];
    if (eintragArt == '_beschaedigt') {
      return SyncKonfliktUnbekannt(
        journalId: journalId,
        reservierteIds: const <String>{},
        grund: 'Der Journaleintrag ist beschädigt.',
      );
    }
    if (eintragArt != art) {
      return null;
    }
    final ids = <String>{
      for (final schluessel in const <String>['originalId', 'kopieId'])
        if (json[schluessel] case final String wert when wert.isNotEmpty) wert,
    };
    SyncKonfliktUnbekannt unbekannt(String grund) => SyncKonfliktUnbekannt(
      journalId: journalId,
      reservierteIds: ids,
      grund: grund,
    );

    final version = json['version'];
    if (version is! int || version > formatVersion) {
      return unbekannt('Unbekannte Formatversion des Journaleintrags.');
    }
    final eintragKonto = json['kontoId'];
    if (eintragKonto is! String || eintragKonto != kontoId) {
      return unbekannt('Der Journaleintrag gehört zu einem anderen Konto.');
    }
    final originalId = json['originalId'];
    final aktion = SyncKonfliktAktion.values
        .where((kandidat) => kandidat.name == json['aktion'])
        .firstOrNull;
    final rohDokumente = json['dokumente'];
    if (originalId is! String ||
        originalId.isEmpty ||
        aktion == null ||
        rohDokumente is! List) {
      return unbekannt('Der Journaleintrag ist unvollständig.');
    }
    final dokumente = <SyncKonfliktDokument>[];
    for (final roh in rohDokumente) {
      final dokument = SyncKonfliktDokument.fromJson(roh);
      if (dokument == null) {
        return unbekannt('Ein Dokument des Journaleintrags ist unlesbar.');
      }
      dokumente.add(dokument);
    }
    SyncKonfliktBlockade? blockade;
    final rohBlockade = json['blockade'];
    if (rohBlockade is Map) {
      blockade = SyncKonfliktBlockade(
        grund: rohBlockade['grund'] as String? ?? '',
        seit:
            DateTime.tryParse(rohBlockade['seit'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }
    return SyncKonfliktGueltig(
      SyncKonfliktVorgang(
        kontoId: eintragKonto,
        begonnen:
            DateTime.tryParse(json['begonnen'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        originalId: originalId,
        kopieId: json['kopieId'] as String?,
        aktion: aktion,
        dokumente: List<SyncKonfliktDokument>.unmodifiable(dokumente),
        blockade: blockade,
        unbekannteFelder: <String, Object?>{
          for (final eintrag in json.entries)
            if (!_bekannteSchluessel.contains(eintrag.key))
              eintrag.key: eintrag.value,
        },
      ),
    );
  }
}

/// Ergebnis des Lesens eines Journaleintrags der Art `syncKonflikt`.
sealed class SyncKonfliktEintrag {
  const SyncKonfliktEintrag();
}

/// Lesbarer, bekannter Vorgang.
final class SyncKonfliktGueltig extends SyncKonfliktEintrag {
  /// Erzeugt das Ergebnis.
  const SyncKonfliktGueltig(this.vorgang);

  /// Der gelesene Vorgang.
  final SyncKonfliktVorgang vorgang;
}

/// Eintrag, den diese App nicht ausführen darf.
///
/// Bleibt unangetastet im Journal. Er reserviert die IDs, die er noch nennt;
/// nennt er keine, bleibt normaler schreibender Sync vorsorglich gesperrt.
final class SyncKonfliktUnbekannt extends SyncKonfliktEintrag {
  /// Erzeugt das Ergebnis.
  const SyncKonfliktUnbekannt({
    required this.journalId,
    required this.reservierteIds,
    required this.grund,
  });

  /// Schlüssel im Journal.
  final String journalId;

  /// Noch bestimmbare betroffene IDs.
  final Set<String> reservierteIds;

  /// Benutzerlesbarer Grund.
  final String grund;
}

// Tiefe Kopie über JSON, damit weder Journal noch Aufrufer Maps teilen.
Map<String, dynamic> _tiefeKopie(Map<dynamic, dynamic> json) {
  return jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
}
