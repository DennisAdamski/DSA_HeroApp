import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';

// Ruhe Körper, Ruhe Geist als Rastprofil (MAG-EFF-05).
//
// Der Zauber ersetzt für die Dauer des Schlafs die normale Regeneration. Er
// ist deshalb ein eigener Ablauf neben dem Rastdialog und kein Zuschlag auf
// ihn: Pro verschlafener Stunde gibt es 2 LeP, 4 Punkte Überanstrengung und 8
// Punkte Erschöpfung weniger, je 6 volle Stunden heilt eine Wunde vollständig.
// Die Kosten trägt der Zaubernde (Reichweite Berührung, nie der Schlafende),
// deshalb zieht die App dem Helden nichts ab.
//
// Nicht belegt und deshalb nicht gerechnet: die Wirkung von Heilungs-Vor- und
// Nachteilen auf die Regeneration („werden auf die gesamte Regenerationszeit
// angerechnet“, ohne Formel) und wann der Schlafende „evtl.“ 1 AsP je Stunde
// zurückbekommt. Beides trägt der Nutzer bewusst ein bzw. korrigiert es.
//
// Beleg: Liber Cantiones S. 220 (Ruhe Körper, Ruhe Geist).

/// Zauber-ID von Ruhe Körper, Ruhe Geist.
const String kRuheKoerperZauberId = 'spell_ruhe_koerper_ruhe_geist';

/// LeP je verschlafener Stunde.
const int kRuheKoerperLepJeStunde = 2;

/// Abbau von Überanstrengung je verschlafener Stunde.
const int kRuheKoerperUeberanstrengungJeStunde = 4;

/// Abbau von Erschöpfung je verschlafener Stunde.
const int kRuheKoerperErschoepfungJeStunde = 8;

/// Stunden, nach denen jeweils eine Wunde vollständig verheilt.
const int kRuheKoerperStundenJeWunde = 6;

/// Bestätigte Eingaben eines Schlafs unter Ruhe Körper.
class RuheKoerperEingabe {
  /// Erstellt die Eingabe.
  const RuheKoerperEingabe({
    required this.zfpStern,
    required this.stunden,
    this.aspRegeneration = 0,
    this.geschlosseneWunden = const <WundZone, int>{},
  });

  /// ZfP* des Zaubernden; der Schlaf dauert höchstens so viele Stunden.
  final int zfpStern;

  /// Verschlafene Stunden.
  final int stunden;

  /// AsP, die der Schlafende zurückbekommt (Meisterentscheid, „evtl. 1 AsP“
  /// je Stunde).
  final int aspRegeneration;

  /// Verheilte Wunden je Zone.
  final Map<WundZone, int> geschlosseneWunden;

  /// Summe der verheilten Wunden.
  int get wundenGesamt => geschlosseneWunden.values.fold<int>(
    0,
    (summe, n) => summe + math.max(0, n),
  );
}

/// Ergebnis der Prüfung eines Schlafs.
class RuheKoerperPruefung {
  /// Erstellt die Prüfung.
  const RuheKoerperPruefung({
    this.fehler = const <String>[],
    this.hinweise = const <String>[],
    this.wundenMoeglich = 0,
  });

  /// Gründe, die das Übernehmen sperren.
  final List<String> fehler;

  /// Hinweise, die nicht sperren.
  final List<String> hinweise;

  /// Wunden, die diese Stundenzahl höchstens heilt.
  final int wundenMoeglich;

  /// Ob der Schlaf übernommen werden darf.
  bool get gueltig => fehler.isEmpty;
}

/// Wunden, die [stunden] Schlaf vollständig heilen.
int ruheKoerperWunden(int stunden) =>
    stunden <= 0 ? 0 : stunden ~/ kRuheKoerperStundenJeWunde;

/// Prüft [eingabe] gegen den gespeicherten Zustand [zustand].
///
/// [maxAsp] begrenzt die AsP, die der Schlafende zurückbekommen kann.
RuheKoerperPruefung pruefeRuheKoerper(
  HeroState zustand,
  RuheKoerperEingabe eingabe, {
  required int maxAsp,
}) {
  final fehler = <String>[];
  final hinweise = <String>[];
  if (eingabe.zfpStern < 1) {
    fehler.add('ZfP* des Zaubernden eintragen.');
  }
  if (eingabe.stunden < 1) {
    fehler.add('Mindestens 1 Stunde Schlaf eintragen.');
  } else if (eingabe.zfpStern >= 1 && eingabe.stunden > eingabe.zfpStern) {
    fehler.add(
      'Der Schlaf dauert höchstens ZfP* = ${eingabe.zfpStern} Stunden.',
    );
  }
  if (eingabe.aspRegeneration < 0 ||
      eingabe.aspRegeneration > math.max(0, eingabe.stunden)) {
    fehler.add(
      'Höchstens 1 AsP je Stunde ("evtl. 1 AsP" laut Regelwerk, Meisterentscheid).',
    );
  }
  final moeglich = ruheKoerperWunden(eingabe.stunden);
  if (eingabe.wundenGesamt > moeglich) {
    fehler.add(
      'Je $kRuheKoerperStundenJeWunde Stunden heilt eine Wunde: höchstens '
      '$moeglich bei ${eingabe.stunden} Stunden.',
    );
  }
  eingabe.geschlosseneWunden.forEach((zone, anzahl) {
    if (anzahl > zustand.wpiZustand.wundenInZone(zone)) {
      fehler.add('In ${wundZoneLabel[zone]} sind weniger Wunden eingetragen.');
    }
  });
  hinweise
    ..add(
      'Der Zauber ersetzt die normale Regeneration dieser Stunden; den '
      'Rastdialog dafür nicht zusätzlich verwenden.',
    )
    ..add(
      'Der Zaubernde trägt die Kosten (4 AsP + 2 AsP je Stunde). Vorteile '
      'und Nachteile der Regeneration sind nicht eingerechnet; bei Bedarf '
      'von Hand korrigieren.',
    )
    ..add(
      'Während der Wirkung hilft kein anderer Heilzauber, und bei allen '
      'anderen Zaubern gilt die MR des Schlafenden als zusätzliche '
      'Erschwernis.',
    );
  if (eingabe.aspRegeneration > 0 && maxAsp <= 0) {
    hinweise.add(
      'Der Held hat keine AsP-Obergrenze; es wird nichts gutgeschrieben.',
    );
  }
  return RuheKoerperPruefung(
    fehler: List<String>.unmodifiable(fehler),
    hinweise: List<String>.unmodifiable(hinweise),
    wundenMoeglich: moeglich,
  );
}

/// Ergebnis der Anwendung eines Schlafs.
class RuheKoerperAnwendung {
  /// Erstellt das Ergebnis.
  const RuheKoerperAnwendung({
    required this.zustand,
    required this.lep,
    required this.asp,
    required this.ueberanstrengung,
    required this.erschoepfung,
    required this.wunden,
    this.istWiederholung = false,
  });

  /// Neuer Zustand.
  final HeroState zustand;

  /// Tatsächlich gutgeschriebene LeP.
  final int lep;

  /// Tatsächlich gutgeschriebene AsP.
  final int asp;

  /// Tatsächlich abgebaute Überanstrengung.
  final int ueberanstrengung;

  /// Tatsächlich abgebaute Erschöpfung.
  final int erschoepfung;

  /// Tatsächlich geheilte Wunden je Zone.
  final Map<WundZone, int> wunden;

  /// Summe der geheilten Wunden.
  int get wundenGesamt => wunden.values.fold<int>(0, (s, n) => s + n);

  /// `true`, wenn derselbe Vorgang schon gebucht war.
  final bool istWiederholung;
}

/// Wendet einen **geprüften** Schlaf auf [zustand] an.
///
/// LeP und AsP steigen höchstens bis [maxLep] bzw. [maxAsp], Überanstrengung
/// und Erschöpfung sinken höchstens bis 0, Wunden werden nur soweit geheilt,
/// wie sie eingetragen sind. Übrige Felder bleiben unverändert.
RuheKoerperAnwendung wendeRuheKoerperAn(
  HeroState zustand,
  RuheKoerperEingabe eingabe, {
  required int maxLep,
  required int maxAsp,
}) {
  final stunden = math.max(0, eingabe.stunden);
  final lep = math.min(
    stunden * kRuheKoerperLepJeStunde,
    math.max(0, maxLep - zustand.currentLep),
  );
  final asp = math.min(
    math.max(0, eingabe.aspRegeneration),
    math.max(0, maxAsp - zustand.currentAsp),
  );
  final ueber = math.min(
    zustand.ueberanstrengung,
    stunden * kRuheKoerperUeberanstrengungJeStunde,
  );
  final ersch = math.min(
    zustand.erschoepfung,
    stunden * kRuheKoerperErschoepfungJeStunde,
  );
  var wunden = zustand.wpiZustand;
  final geheilt = <WundZone, int>{};
  eingabe.geschlosseneWunden.forEach((zone, anzahl) {
    final moeglich = math.min(anzahl, wunden.wundenInZone(zone));
    for (var i = 0; i < moeglich; i++) {
      wunden = wunden.mitWundeEntfernt(zone);
    }
    if (moeglich > 0) {
      geheilt[zone] = moeglich;
    }
  });
  var neu = zustand.copyWith(
    currentLep: RessourcenAenderung.schritt(lep).wendeAn(zustand.currentLep),
    currentAsp: RessourcenAenderung.schritt(asp).wendeAn(zustand.currentAsp),
    ueberanstrengung: zustand.ueberanstrengung - ueber,
    erschoepfung: zustand.erschoepfung - ersch,
  );
  if (geheilt.isNotEmpty) {
    neu = neu.copyWith(wpiZustand: wunden);
  }
  return RuheKoerperAnwendung(
    zustand: neu,
    lep: lep,
    asp: asp,
    ueberanstrengung: ueber,
    erschoepfung: ersch,
    wunden: Map<WundZone, int>.unmodifiable(geheilt),
  );
}

/// Hält fest, was [anwendung] am Zustand tatsächlich verändert hat.
///
/// Heilt der Schlaf Wunden in mehreren Zonen, bleibt die Zone der Buchung
/// leer; das Protokoll nennt sie dann einzeln.
ZustandsBuchung ruheKoerperBuchungAus({
  required RuheKoerperAnwendung anwendung,
  required String id,
  required DateTime zeitpunkt,
}) {
  return ZustandsBuchung(
    id: id,
    art: ZustandsBuchungsArt.heilung,
    zeitpunkt: zeitpunkt.toUtc(),
    lepDelta: anwendung.lep,
    aspDelta: anwendung.asp,
    zone: anwendung.wunden.length == 1 ? anwendung.wunden.keys.single : null,
    wundenDelta: -anwendung.wundenGesamt,
  );
}
