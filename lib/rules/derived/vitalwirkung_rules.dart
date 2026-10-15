import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/vitalwirkung.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';

// Anwendung eines Verbrauchsgegenstands mit Wirkung auf Vitalwerte und Wunden
// (Heiltrank, Verband, Kraftelixier …).
//
// Der Gegenstand liefert nur Vorschläge (`Vitalwirkung`); gebucht wird, was
// der Nutzer im Dialog bestätigt. Gewürfelte Wirkungen und die Wahl der
// geschlossenen Wunden werden nie geraten. LeP, AsP und AuP steigen höchstens
// bis zu ihrem Maximum; Wunden werden nur dort geschlossen, wo welche
// eingetragen sind. Gebucht wird in einem Zustandsdokument mit einer
// `ZustandsBuchung`, die dieselbe Vorgangs-ID nie zweimal anwendet.

/// Bestätigte Eingaben der Anwendung.
class VitalEingabe {
  /// Erstellt die Eingabe; alle Zahlen sind nicht negativ.
  const VitalEingabe({
    this.lep = 0,
    this.asp = 0,
    this.aup = 0,
    this.wundenJeZone = const <WundZone, int>{},
  });

  /// Zurückkehrende LeP.
  final int lep;

  /// Zurückkehrende AsP.
  final int asp;

  /// Zurückkehrende AuP.
  final int aup;

  /// Geschlossene Wunden je Zone.
  final Map<WundZone, int> wundenJeZone;

  /// Summe der zu schließenden Wunden.
  int get wundenGesamt =>
      wundenJeZone.values.fold<int>(0, (summe, n) => summe + n);
}

/// Obergrenzen, bis zu denen Werte steigen dürfen.
class VitalGrenzen {
  /// Erstellt die Grenzen.
  const VitalGrenzen({
    required this.maxLep,
    required this.maxAsp,
    required this.maxAu,
  });

  /// Maximale LeP.
  final int maxLep;

  /// Maximale AsP.
  final int maxAsp;

  /// Maximale AuP.
  final int maxAu;
}

/// Ergebnis der Prüfung.
class VitalPruefung {
  /// Erstellt die Prüfung.
  const VitalPruefung({
    this.fehler = const <String>[],
    this.hinweise = const <String>[],
  });

  /// Gründe, die das Übernehmen sperren.
  final List<String> fehler;

  /// Hinweise, die nicht sperren.
  final List<String> hinweise;

  /// Ob die Anwendung übernommen werden darf.
  bool get gueltig => fehler.isEmpty;
}

/// Prüft [eingabe] gegen den gespeicherten Zustand [zustand].
VitalPruefung pruefeVitalwirkung(
  HeroState zustand,
  VitalEingabe eingabe, {
  required VitalGrenzen grenzen,
}) {
  final fehler = <String>[];
  final hinweise = <String>[];
  if (eingabe.lep < 0 || eingabe.asp < 0 || eingabe.aup < 0) {
    fehler.add('Die Werte dürfen nicht negativ sein.');
  }
  if (eingabe.lep == 0 &&
      eingabe.asp == 0 &&
      eingabe.aup == 0 &&
      eingabe.wundenGesamt == 0) {
    fehler.add('Mindestens eine Wirkung eintragen.');
  }
  for (final eintrag in eingabe.wundenJeZone.entries) {
    if (eintrag.value < 0) {
      fehler.add('Die Zahl der Wunden darf nicht negativ sein.');
    } else if (eintrag.value > zustand.wpiZustand.wundenInZone(eintrag.key)) {
      fehler.add(
        'In der Zone ${wundZoneLabel[eintrag.key]} sind weniger Wunden '
        'eingetragen.',
      );
    }
  }
  void hinweisBisMaximum(String name, int wert, int aktuell, int maximum) {
    final frei = math.max(0, maximum - aktuell);
    if (wert > frei) {
      hinweise.add('$name: gutgeschrieben werden nur $frei (bis zum Maximum).');
    }
  }

  if (fehler.isEmpty) {
    hinweisBisMaximum('LeP', eingabe.lep, zustand.currentLep, grenzen.maxLep);
    hinweisBisMaximum('AsP', eingabe.asp, zustand.currentAsp, grenzen.maxAsp);
    hinweisBisMaximum('AuP', eingabe.aup, zustand.currentAu, grenzen.maxAu);
  }
  return VitalPruefung(
    fehler: List<String>.unmodifiable(fehler),
    hinweise: List<String>.unmodifiable(hinweise),
  );
}

/// Ergebnis der Anwendung.
class VitalAnwendung {
  /// Erstellt das Ergebnis.
  const VitalAnwendung({
    required this.zustand,
    required this.lep,
    required this.asp,
    required this.aup,
    required this.wundenJeZone,
    this.istWiederholung = false,
  });

  /// Neuer Zustand.
  final HeroState zustand;

  /// Tatsächlich gutgeschriebene LeP.
  final int lep;

  /// Tatsächlich gutgeschriebene AsP.
  final int asp;

  /// Tatsächlich gutgeschriebene AuP.
  final int aup;

  /// Tatsächlich geschlossene Wunden je Zone.
  final Map<WundZone, int> wundenJeZone;

  /// `true`, wenn dieselbe Buchung schon gespeichert war.
  final bool istWiederholung;

  /// Summe der geschlossenen Wunden.
  int get wunden => wundenJeZone.values.fold<int>(0, (summe, n) => summe + n);
}

/// Wendet eine **geprüfte** Eingabe auf [zustand] an.
///
/// Alle übrigen Felder bleiben unverändert.
VitalAnwendung wendeVitalwirkungAn(
  HeroState zustand,
  VitalEingabe eingabe, {
  required VitalGrenzen grenzen,
}) {
  int begrenzt(int wert, int aktuell, int maximum) =>
      math.min(math.max(0, wert), math.max(0, maximum - aktuell));
  final lep = begrenzt(eingabe.lep, zustand.currentLep, grenzen.maxLep);
  final asp = begrenzt(eingabe.asp, zustand.currentAsp, grenzen.maxAsp);
  final aup = begrenzt(eingabe.aup, zustand.currentAu, grenzen.maxAu);

  var wunden = zustand.wpiZustand;
  final geschlossen = <WundZone, int>{};
  for (final eintrag in eingabe.wundenJeZone.entries) {
    final moeglich = math.min(
      math.max(0, eintrag.value),
      wunden.wundenInZone(eintrag.key),
    );
    for (var i = 0; i < moeglich; i++) {
      wunden = wunden.mitWundeEntfernt(eintrag.key);
    }
    if (moeglich > 0) {
      geschlossen[eintrag.key] = moeglich;
    }
  }
  var neu = zustand.copyWith(
    currentLep: RessourcenAenderung.schritt(lep).wendeAn(zustand.currentLep),
    currentAsp: RessourcenAenderung.schritt(asp).wendeAn(zustand.currentAsp),
    currentAu: RessourcenAenderung.schritt(aup).wendeAn(zustand.currentAu),
  );
  if (geschlossen.isNotEmpty) {
    neu = neu.copyWith(wpiZustand: wunden);
  }
  return VitalAnwendung(
    zustand: neu,
    lep: lep,
    asp: asp,
    aup: aup,
    wundenJeZone: Map<WundZone, int>.unmodifiable(geschlossen),
  );
}

/// Hält fest, was [anwendung] am Zustand tatsächlich verändert hat.
///
/// Die Buchung kennt eine Zone; wurden Wunden in mehreren Zonen geschlossen,
/// bleibt sie leer, die Zahl steht trotzdem in `wundenDelta` und das Protokoll
/// nennt jede Zone.
ZustandsBuchung vitalBuchungAus({
  required VitalAnwendung anwendung,
  required String id,
  required DateTime zeitpunkt,
}) {
  final zonen = anwendung.wundenJeZone.keys.toList();
  return ZustandsBuchung(
    id: id,
    art: ZustandsBuchungsArt.heilung,
    zeitpunkt: zeitpunkt.toUtc(),
    lepDelta: anwendung.lep,
    auDelta: anwendung.aup,
    aspDelta: anwendung.asp,
    zone: zonen.length == 1 ? zonen.single : null,
    wundenDelta: -anwendung.wunden,
  );
}

/// Titel des Protokolleintrags.
const String vitalwirkungProtokollTitel = 'Gegenstand angewendet';

/// Baut den Protokolleintrag; er nennt die tatsächlichen Änderungen, damit die
/// Buchung von Hand korrigiert werden kann. `total` sind die gutgeschriebenen
/// LeP.
DiceLogEntry baueVitalProtokoll({
  required String gegenstand,
  required VitalAnwendung anwendung,
  required DateTime zeitpunkt,
  required String buchungId,
}) {
  final teile = <String>[
    gegenstand,
    if (anwendung.lep > 0) '+${anwendung.lep} LeP',
    if (anwendung.asp > 0) '+${anwendung.asp} AsP',
    if (anwendung.aup > 0) '+${anwendung.aup} AuP',
    for (final eintrag in anwendung.wundenJeZone.entries)
      '${eintrag.value == 1 ? '1 Wunde' : '${eintrag.value} Wunden'} '
          '${wundZoneLabel[eintrag.key]} geschlossen',
  ];
  return diceLogEntryFromRoll(
    title: vitalwirkungProtokollTitel,
    subtitle: teile.join(' · '),
    diceValues: const <int>[],
    total: anwendung.lep,
    timestamp: zeitpunkt,
    buchungId: buchungId,
  );
}

/// Eingabe-Vorschlag aus der Vorbelegung des Gegenstands.
///
/// Die Wunden-Vorgabe wird auf vorhandene Wunden begrenzt und von der ersten
/// Zone mit Wunden an verteilt; der Nutzer korrigiert im Dialog.
VitalEingabe vitalVorschlag(Vitalwirkung? vorgabe, HeroState zustand) {
  if (vorgabe == null) {
    return const VitalEingabe();
  }
  var offen = vorgabe.wunden;
  final verteilt = <WundZone, int>{};
  for (final zone in WundZone.values) {
    if (offen <= 0) {
      break;
    }
    final vorhanden = zustand.wpiZustand.wundenInZone(zone);
    final nimm = math.min(offen, vorhanden);
    if (nimm > 0) {
      verteilt[zone] = nimm;
      offen -= nimm;
    }
  }
  return VitalEingabe(
    lep: vorgabe.lep,
    asp: vorgabe.asp,
    aup: vorgabe.aup,
    wundenJeZone: verteilt,
  );
}
