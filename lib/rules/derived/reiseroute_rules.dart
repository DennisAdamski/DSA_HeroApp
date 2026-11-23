import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_age_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';

/// Regeln zur Reiseroute eines Helden: Reihenfolge der Stationen, Abstände
/// zwischen ihnen und gezielte Änderungen der Stationsliste.

/// Meilen je Einheit des Avesmaps-Kartensystems.
const double kMeilenProKarteneinheit = 3;

/// Fortlaufende Tagesnummer des Stationsdatums, oder `null`, wenn Tag, Monat
/// oder Jahr fehlen oder nicht lesbar sind.
int? reiseStationTagesnummer(HeroReiseStation station) {
  final datum = station.datum;
  if (!datum.hasContent) return null;
  final jahr = parseAventurianYear(datum.year);
  if (jahr == null) return null;
  final tag = aventurianDayOfYear(
    AventurianDate.fromParts(datum.day, datum.month, datum.year),
  );
  if (tag == null) return null;
  return jahr * aventurianDaysPerYear + tag - 1;
}

/// Formatiertes Datum der Station, oder `null` ohne Datum.
String? reiseStationDatumText(HeroReiseStation station) =>
    station.datum.hasContent ? station.datum.anzeigeText : null;

/// Stationen in zeitlicher Reihenfolge.
///
/// Stationen mit vollständigem Datum ordnen sich nach dem Kalender. Eine
/// Station ohne lesbares Datum bleibt hinter der Station, nach der sie erfasst
/// wurde; vor der ersten datierten Station erfasste Stationen stehen vorn. Bei
/// gleichem Tag gilt die Erfassungsreihenfolge.
List<HeroReiseStation> sortiereReiseStationen(
  List<HeroReiseStation> stationen,
) {
  final schluessel = <int?>[];
  int? zuletzt;
  for (final station in stationen) {
    zuletzt = reiseStationTagesnummer(station) ?? zuletzt;
    schluessel.add(zuletzt);
  }
  final indizes = List<int>.generate(stationen.length, (i) => i);
  indizes.sort((a, b) {
    final ka = schluessel[a];
    final kb = schluessel[b];
    if (ka != kb) {
      if (ka == null) return -1;
      if (kb == null) return 1;
      return ka.compareTo(kb);
    }
    return a.compareTo(b);
  });
  return List<HeroReiseStation>.unmodifiable(indizes.map((i) => stationen[i]));
}

/// Tage von [von] bis [bis], oder `null`, wenn eines der Daten fehlt.
int? reiseTageZwischen(HeroReiseStation von, HeroReiseStation bis) {
  final a = reiseStationTagesnummer(von);
  final b = reiseStationTagesnummer(bis);
  if (a == null || b == null) return null;
  return b - a;
}

/// Luftlinie zwischen zwei Stationen in Meilen, oder `null`, wenn eine der
/// beiden keine Kartenposition hat.
double? luftlinieMeilen(HeroReiseStation von, HeroReiseStation bis) {
  if (!von.hatKartenposition || !bis.hatKartenposition) return null;
  final dx = bis.kartenX! - von.kartenX!;
  final dy = bis.kartenY! - von.kartenY!;
  return math.sqrt(dx * dx + dy * dy) * kMeilenProKarteneinheit;
}

/// Eine Etappe der Reiseroute: die Station und der Abstand zur vorigen.
class ReiseEtappe {
  /// Erzeugt eine Etappe.
  const ReiseEtappe({
    required this.station,
    required this.nummer,
    this.vorherige,
    this.tageSeitVorher,
    this.meilenSeitVorher,
  });

  /// Station am Ende der Etappe.
  final HeroReiseStation station;

  /// Laufende Nummer ab 1 in zeitlicher Reihenfolge.
  final int nummer;

  /// Station am Anfang der Etappe, oder `null` (erste Station).
  final HeroReiseStation? vorherige;

  /// Tage seit der vorigen Station, oder `null` (erste Station, Datum fehlt).
  final int? tageSeitVorher;

  /// Luftlinie zur vorigen Station in Meilen, oder `null`.
  final double? meilenSeitVorher;
}

/// Die Stationen als Etappen in zeitlicher Reihenfolge.
///
/// Mit [adventureId] nur die Stationen dieses Abenteuers; die Abstände
/// beziehen sich dann auf die vorige Station desselben Abenteuers.
List<ReiseEtappe> reiseEtappen(
  List<HeroReiseStation> stationen, {
  String? adventureId,
}) {
  final gefiltert = adventureId == null
      ? stationen
      : stationen.where((s) => s.adventureId == adventureId).toList();
  final sortiert = sortiereReiseStationen(gefiltert);
  final etappen = <ReiseEtappe>[];
  for (var i = 0; i < sortiert.length; i++) {
    final vorher = i == 0 ? null : sortiert[i - 1];
    etappen.add(
      ReiseEtappe(
        station: sortiert[i],
        nummer: i + 1,
        vorherige: vorher,
        tageSeitVorher: vorher == null
            ? null
            : reiseTageZwischen(vorher, sortiert[i]),
        meilenSeitVorher: vorher == null
            ? null
            : luftlinieMeilen(vorher, sortiert[i]),
      ),
    );
  }
  return List<ReiseEtappe>.unmodifiable(etappen);
}

/// Tage zwischen der ersten und der letzten datierten Etappe, oder `null`
/// bei weniger als zwei datierten Stationen.
int? reiseTageGesamt(List<ReiseEtappe> etappen) {
  int? erste;
  int? letzte;
  var datiert = 0;
  for (final etappe in etappen) {
    final tag = reiseStationTagesnummer(etappe.station);
    if (tag == null) continue;
    datiert++;
    erste ??= tag;
    letzte = tag;
  }
  if (datiert < 2) return null;
  return letzte! - erste!;
}

/// Reisetage eines Wegs, auf Vierteltage gerundet („5¾ Reisetage“); unter
/// einem halben Tag in Reisestunden.
String formatiereReisezeit(AvesmapsRoute weg) {
  if (weg.reisetage < .5) {
    final stunden = math.max(1, weg.reisestunden.round());
    return stunden == 1 ? '1 Reisestunde' : '$stunden Reisestunden';
  }
  final viertel = (weg.reisetage * 4).round();
  final ganz = viertel ~/ 4;
  final bruch = const <String>['', '¼', '½', '¾'][viertel % 4];
  if (ganz == 0) return '$bruch Reisetag';
  return viertel == 4 ? '1 Reisetag' : '$ganz$bruch Reisetage';
}

/// Kurzer Text zum Abstand einer Etappe, etwa „+3 Tage · 45 Meilen
/// Luftlinie“, oder `null`, wenn nichts bekannt ist.
///
/// Mit einem gefundenen [weg] stehen dessen Meilen und Reisezeit statt der
/// Luftlinie da („+9 Tage · 341 Meilen · 5¾ Reisetage“).
String? reiseEtappenAbstandText(ReiseEtappe etappe, {AvesmapsRoute? weg}) {
  final teile = <String>[];
  final tage = etappe.tageSeitVorher;
  if (tage != null) {
    teile.add(switch (tage) {
      0 => 'am selben Tag',
      1 => '+1 Tag',
      -1 => '1 Tag früher',
      < 0 => '${-tage} Tage früher',
      _ => '+$tage Tage',
    });
  }
  final meilen = etappe.meilenSeitVorher;
  if (weg != null && weg.gefunden) {
    teile
      ..add('${weg.meilen.round()} Meilen')
      ..add(formatiereReisezeit(weg));
  } else if (meilen != null) {
    teile.add('${meilen.round()} Meilen Luftlinie');
  }
  return teile.isEmpty ? null : teile.join(' · ');
}

/// Titel des Abenteuers, zu dem [station] gehört, oder `null` ohne
/// Zuordnung.
///
/// Ein Abenteuer ohne Titel heißt „Ohne Titel“; ist das zugeordnete Abenteuer
/// inzwischen entfernt, steht „Entferntes Abenteuer“, damit die Zuordnung
/// sichtbar bleibt.
String? reiseStationAbenteuerTitel(
  HeroReiseStation station,
  List<HeroAdventureEntry> abenteuer,
) {
  if (station.adventureId.isEmpty) return null;
  for (final eintrag in abenteuer) {
    if (eintrag.id != station.adventureId) continue;
    final titel = eintrag.title.trim();
    return titel.isEmpty ? 'Ohne Titel' : titel;
  }
  return 'Entferntes Abenteuer';
}

/// Vorbelegung einer neuen Station: Standort des Helden, Datum und Abenteuer
/// des laufenden Abenteuers.
///
/// Fehlt eine Angabe, bleibt das Feld leer; nichts wird erfunden. Das Datum
/// kommt bevorzugt aus dem ersten laufenden Abenteuer mit Datum, sonst aus
/// [resolveCurrentAdventureDate].
HeroReiseStation reiseStationVorschlag({
  required HeroSheet held,
  required String standort,
  required String id,
}) {
  HeroAdventureEntry? abenteuer;
  for (final eintrag in held.adventures) {
    if (eintrag.status == HeroAdventureStatus.current) {
      abenteuer = eintrag;
      break;
    }
  }
  var datum = const HeroAdventureDateValue();
  for (final kandidat in <HeroAdventureDateValue>[
    if (abenteuer != null) abenteuer.currentAventurianDate,
    if (abenteuer != null) abenteuer.startAventurianDate,
  ]) {
    if (kandidat.hasContent) {
      datum = HeroAdventureDateValue(
        day: kandidat.day,
        month: kandidat.month,
        year: kandidat.year,
      );
      break;
    }
  }
  if (!datum.hasContent) {
    final ersatz = resolveCurrentAdventureDate(held);
    if (ersatz != null) {
      datum = HeroAdventureDateValue(
        day: ersatz.day,
        month: ersatz.month,
        year: ersatz.year,
      );
    }
  }
  return HeroReiseStation(
    id: id,
    ort: bereinigeStandort(standort),
    datum: datum,
    adventureId: abenteuer?.id ?? '',
  );
}

/// Ob [alterStandort] und [neuerStandort] denselben Ort meinen (bereinigt, ohne
/// Rücksicht auf Groß- und Kleinschreibung).
bool _gleicherOrt(String a, String b) =>
    bereinigeStandort(a).toLowerCase() == bereinigeStandort(b).toLowerCase();

/// Der Held mit der Station, die ein Wechsel des Standorts von [alterStandort]
/// nach [neuerStandort] festhält, oder `null`, wenn keine entsteht.
///
/// Keine Station gibt es, wenn der neue Standort leer ist (Standort entfernt),
/// wenn sich der Ort nicht ändert oder wenn die zeitlich letzte Station schon
/// diesen Ort trägt (zweiter Schutz gegen doppelte Einträge). Datum und
/// Abenteuer kommen aus [reiseStationVorschlag]; den Kartenverweis (`ortId`,
/// Position) trägt die Station, wenn der Standort ausdrücklich gewählt wurde
/// ([gewaehlt], der Aufrufer verbürgt, dass er zum Namen gehört) oder [orte]
/// den Ort eindeutig kennt.
HeroSheet? reiseStationFuerStandortwechsel({
  required HeroSheet held,
  required String alterStandort,
  required String neuerStandort,
  required String id,
  required DateTime jetzt,
  List<OrtEintrag> orte = const <OrtEintrag>[],
  OrtEintrag? gewaehlt,
}) {
  final neu = bereinigeStandort(neuerStandort);
  if (neu.isEmpty || _gleicherOrt(alterStandort, neu)) return null;
  final sortiert = sortiereReiseStationen(held.reiseStationen);
  if (sortiert.isNotEmpty && _gleicherOrt(sortiert.last.ort, neu)) return null;
  final vorschlag = reiseStationVorschlag(held: held, standort: neu, id: id);
  final verweis = gewaehlt != null && gewaehlt.hatKartenposition
      ? gewaehlt
      : ortsVerweisFuer(neu, orte);
  final station = vorschlag.copyWith(
    ortId: verweis?.ortId,
    kartenX: verweis?.kartenX,
    kartenY: verweis?.kartenY,
    lastModified: jetzt.toUtc(),
  );
  return fuegeReiseStationHinzu(held, station);
}

/// Hängt [station] an die Stationsliste an.
HeroSheet fuegeReiseStationHinzu(HeroSheet held, HeroReiseStation station) {
  if (held.reiseStationen.any((s) => s.id == station.id)) {
    throw StateError('Die Station ist bereits erfasst.');
  }
  return held.copyWith(reiseStationen: [...held.reiseStationen, station]);
}

/// Ersetzt genau die Station mit [id]; ist sie verschwunden, wird nichts
/// still neu angelegt.
HeroSheet ersetzeReiseStation(
  HeroSheet held,
  String id,
  HeroReiseStation Function(HeroReiseStation station) aenderung,
) {
  final index = held.reiseStationen.indexWhere((s) => s.id == id);
  if (index < 0) {
    throw StateError('Die Station wurde inzwischen entfernt.');
  }
  final stationen = List<HeroReiseStation>.of(held.reiseStationen);
  stationen[index] = aenderung(stationen[index]);
  return held.copyWith(reiseStationen: stationen);
}

/// Entfernt die Station mit [id]; fehlt sie, bleibt der Held unverändert.
HeroSheet entferneReiseStation(HeroSheet held, String id) {
  if (!held.reiseStationen.any((s) => s.id == id)) return held;
  return held.copyWith(
    reiseStationen: [
      for (final s in held.reiseStationen)
        if (s.id != id) s,
    ],
  );
}
