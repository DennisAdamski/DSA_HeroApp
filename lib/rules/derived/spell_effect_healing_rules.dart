import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';

// Heilung durch Zauber (MAG-EFF-05).
//
// Eine Heilung ist ein einmaliges Ereignis, keine laufende Wirkung: Sie gibt
// dem Helden LeP zurück, kostet (nur bei Selbstwirkung) AsP des Helden und
// kann bei Balsam Wunden schließen. Gerechnet wird nur, was das Regelwerk
// eindeutig belegt; ungerade AsP bei Wunden (Hexenspeichel) und die Rettung
// von der Schwelle des Todes sind nicht festgelegt und werden nie geraten.
// Gebucht wird in einem Zustandsdokument mit einer `ZustandsBuchung`, die
// dieselbe Vorgangs-ID nie zweimal anwendet.
//
// Belege: Liber Cantiones S. 37 (Balsam Salabunde), S. 117 (Hexenspeichel),
// S. 151 (Lach dich gesund).

/// Zauber-ID des Balsam Salabunde.
const String kBalsamZauberId = 'spell_balsam_salabunde';

/// Zauber-ID des Hexenspeichels.
const String kHexenspeichelZauberId = 'spell_hexenspeichel';

/// Zauber-ID von Lach dich gesund.
const String kLachDichGesundZauberId = 'spell_lach_dich_gesund';

/// Heilzauber, die dieses Modul rechnet.
const Set<String> kHeilZauberIds = <String>{
  kBalsamZauberId,
  kHexenspeichelZauberId,
  kLachDichGesundZauberId,
};

/// Mindestkosten des Balsam in AsP.
const int kBalsamMindestAsp = 5;

/// LeP, die eine Wunde bei Balsam vollständig heilen („Je 7 zurückgegebene
/// LeP“, LC S. 37).
const int kBalsamLepJeWunde = 7;

/// Woher der zu heilende LeP-Verlust stammt (Hexenspeichel rechnet je nach
/// Herkunft verschieden).
enum HeilSchaden {
  /// Verletzung durch Wunden: 1 LeP je 2 AsP.
  wunde,

  /// Krankheit: 1 LeP je AsP.
  krankheit,

  /// Vergiftung: 2 LeP je AsP.
  vergiftung,
}

/// Bestätigte Eingaben einer Heilung.
class HeilEingabe {
  /// Erstellt die Eingabe.
  const HeilEingabe({
    required this.zauberId,
    required this.asp,
    required this.zfw,
    this.zfpStern = 0,
    this.schaden = HeilSchaden.wunde,
    this.wundheilungAngesagt = false,
    this.zone,
    this.wunden = 0,
    this.selbstGewirkt = false,
  });

  /// Gewählter Heilzauber.
  final String zauberId;

  /// Eingesetzte AsP.
  final int asp;

  /// ZfW des Zaubernden.
  final int zfw;

  /// ZfP* des Zaubernden (nur Lach dich gesund: so viele LeP kommen zurück).
  final int zfpStern;

  /// Herkunft des LeP-Verlusts (nur Hexenspeichel).
  final HeilSchaden schaden;

  /// Ob die Heilung von Wunden angesagt wurde (nur Balsam).
  final bool wundheilungAngesagt;

  /// Zone, in der Wunden geschlossen werden.
  final WundZone? zone;

  /// Anzahl der zu schließenden Wunden in [zone].
  final int wunden;

  /// Ob der Held selbst zaubert und die AsP bezahlt. Bei einer fremden Quelle
  /// ohne bekannte Kosten wird dem Empfänger nichts abgezogen.
  final bool selbstGewirkt;
}

/// Ergebnis der Prüfung einer Heilung.
class HeilPruefung {
  /// Erstellt die Prüfung.
  const HeilPruefung({
    this.fehler = const <String>[],
    this.hinweise = const <String>[],
    this.lep = 0,
    this.kosten = 0,
    this.wundenVorschlag = 0,
  });

  /// Gründe, die das Übernehmen sperren.
  final List<String> fehler;

  /// Hinweise, die nicht sperren.
  final List<String> hinweise;

  /// Zurückgegebene LeP laut Zauber (vor der Obergrenze).
  final int lep;

  /// AsP-Kosten des Zaubers.
  final int kosten;

  /// Vorschlag für die Zahl der geschlossenen Wunden (Balsam, nur bei
  /// angesagter Wundheilung).
  final int wundenVorschlag;

  /// Ob die Heilung übernommen werden darf.
  bool get gueltig => fehler.isEmpty;
}

/// Zurückgegebene LeP laut Zauber; `null` bei unbekanntem Zauber oder
/// unzulässiger AsP-Zahl (Grund dann in [pruefeHeilung]).
int? _zurueckgegebeneLep(HeilEingabe e) {
  switch (e.zauberId) {
    case kLachDichGesundZauberId:
      return e.zfpStern;
    case kBalsamZauberId:
      return e.asp;
    case kHexenspeichelZauberId:
      return switch (e.schaden) {
        // 1 LeP je 2 AsP, echt gerundet (7 AsP -> 3,5 -> 4 LeP).
        HeilSchaden.wunde => (e.asp + 1) ~/ 2,
        HeilSchaden.krankheit => e.asp,
        HeilSchaden.vergiftung => 2 * e.asp,
      };
  }
  return null;
}

/// Prüft [eingabe] gegen den gespeicherten Zustand [zustand].
///
/// [maxLep] ist die Obergrenze der LeP; mehr als bis dahin wird nicht
/// gutgeschrieben.
HeilPruefung pruefeHeilung(
  HeroState zustand,
  HeilEingabe eingabe, {
  required int maxLep,
}) {
  final fehler = <String>[];
  final hinweise = <String>[];
  if (!kHeilZauberIds.contains(eingabe.zauberId)) {
    return const HeilPruefung(fehler: <String>['Unbekannter Heilzauber.']);
  }
  final balsam = eingabe.zauberId == kBalsamZauberId;
  final lach = eingabe.zauberId == kLachDichGesundZauberId;
  if (!lach && eingabe.zfw < 1) {
    fehler.add('ZfW des Zaubernden eintragen.');
  }
  if (lach) {
    if (eingabe.zfpStern < 1) {
      fehler.add('ZfP* des Zaubernden eintragen.');
    }
    if (eingabe.selbstGewirkt) {
      fehler.add('Lach dich gesund wirkt nie auf die Zaubernde selbst.');
    }
    hinweise
      ..add(
        'Der Patient regeneriert die LeP über die Zeit (eine Spielrunde je '
        'Punkt); gebucht wird die gesamte Heilung auf einmal.',
      )
      ..add(
        'Misslingt die Probe, bringt der Zauber nur 1W3 LeP: diesen Wurf als '
        'ZfP* eintragen. Die Zaubernde zahlt so viele AsP wie LeP '
        'zurückkommen.',
      );
  } else if (balsam) {
    if (eingabe.asp < kBalsamMindestAsp) {
      fehler.add('Balsam kostet mindestens $kBalsamMindestAsp AsP.');
    } else if (eingabe.zfw >= 1 && eingabe.asp > 2 * eingabe.zfw) {
      fehler.add(
        'Balsam gibt höchstens ZfW × 2 = ${2 * eingabe.zfw} LeP zurück; '
        'mehr AsP bringen nichts.',
      );
    }
  } else {
    if (eingabe.asp < 1) {
      fehler.add('Mindestens 1 AsP einsetzen.');
    } else if (eingabe.zfw >= 1 && eingabe.asp > eingabe.zfw) {
      fehler.add(
        'Hexenspeichel erlaubt höchstens ZfW = ${eingabe.zfw} AsP auf einmal.',
      );
    }
    if (eingabe.schaden == HeilSchaden.wunde && eingabe.asp.isOdd) {
      hinweise.add(
        'Bei Wunden gibt es 1 LeP je 2 AsP; die ungerade Zahl wird '
        'aufgerundet (allgemeine Rundungsregel).',
      );
    }
    if (eingabe.selbstGewirkt) {
      hinweise.add(
        'Die Hexe kann sich mit Hexenspeichel üblicherweise nicht selbst '
        'heilen; dafür ist eine Spontane Modifikation nötig.',
      );
    }
  }
  if (zustand.currentLep < 1) {
    fehler.add(
      'Bei 0 LeP oder weniger gilt die Variante „Rettung von der Schwelle des '
      'Todes“ (mehr AsP, permanente AsP); sie wird nicht berechnet. LeP bitte '
      'von Hand anpassen.',
    );
  }
  final kosten = lach ? 0 : eingabe.asp;
  if (eingabe.selbstGewirkt && !lach && zustand.currentAsp < kosten) {
    fehler.add(
      'Zu wenige AsP: ${zustand.currentAsp} vorhanden, $kosten nötig.',
    );
  }

  final lep = _zurueckgegebeneLep(eingabe) ?? 0;
  var vorschlag = 0;
  if (eingabe.wundheilungAngesagt) {
    if (!balsam) {
      fehler.add('Nur Balsam heilt angesagte Wunden.');
    } else {
      vorschlag = lep ~/ kBalsamLepJeWunde;
      final wundenGesamt = zustand.wpiZustand.wundenProZone.values.fold<int>(
        0,
        (summe, n) => summe + n,
      );
      hinweise.add(
        'Die Zauberprobe ist um die doppelte Zahl der Wunden des Patienten '
        'erschwert (jetzt ${2 * wundenGesamt}).',
      );
      final zone = eingabe.zone;
      if (eingabe.wunden > 0) {
        if (zone == null) {
          fehler.add('Für die Wunden eine Zone wählen.');
        } else if (eingabe.wunden > zustand.wpiZustand.wundenInZone(zone)) {
          fehler.add('In dieser Zone sind weniger Wunden eingetragen.');
        }
        if (eingabe.wunden > vorschlag) {
          hinweise.add(
            'Je $kBalsamLepJeWunde zurückgegebene LeP heilen eine Wunde '
            '(hier $vorschlag).',
          );
        }
      }
    }
  } else if (balsam) {
    hinweise.add(
      'Wunden heilt Balsam nur, wenn die Wundheilung angesagt wird.',
    );
  }
  if (!lach) {
    hinweise.add(
      'Die schädliche Wirkung von Giften und Krankheiten stoppt dieser Zauber '
      'nicht.',
    );
  }
  final bisMaximum = math.max(0, maxLep - zustand.currentLep);
  if (fehler.isEmpty && lep > bisMaximum) {
    hinweise.add(
      'Gutgeschrieben werden nur $bisMaximum LeP (bis zum Maximum).',
    );
  }
  return HeilPruefung(
    fehler: List<String>.unmodifiable(fehler),
    hinweise: List<String>.unmodifiable(hinweise),
    lep: lep,
    kosten: kosten,
    wundenVorschlag: vorschlag,
  );
}

/// Ergebnis der Anwendung einer Heilung.
class HeilAnwendung {
  /// Erstellt das Ergebnis.
  const HeilAnwendung({
    required this.zustand,
    required this.lep,
    required this.asp,
    required this.wunden,
    this.istWiederholung = false,
  });

  /// Neuer Zustand.
  final HeroState zustand;

  /// Tatsächlich gutgeschriebene LeP.
  final int lep;

  /// Tatsächlich abgezogene AsP.
  final int asp;

  /// Tatsächlich geschlossene Wunden.
  final int wunden;

  /// `true`, wenn dieselbe Buchung schon gespeichert war.
  final bool istWiederholung;
}

/// Wendet eine **geprüfte** Heilung auf [zustand] an.
///
/// LeP steigen höchstens bis [maxLep]; die AsP des Helden sinken nur bei
/// Selbstwirkung (höchstens bis 0). Wunden werden in der gewählten Zone
/// geschlossen, soweit dort eingetragen. Alle übrigen Felder bleiben
/// unverändert.
HeilAnwendung wendeHeilungAn(
  HeroState zustand,
  HeilEingabe eingabe, {
  required int maxLep,
}) {
  final lepNominal = _zurueckgegebeneLep(eingabe) ?? 0;
  final lepDelta = math.min(
    math.max(0, lepNominal),
    math.max(0, maxLep - zustand.currentLep),
  );
  final aspDelta = eingabe.selbstGewirkt
      ? math.min(math.max(0, eingabe.asp), math.max(0, zustand.currentAsp))
      : 0;
  var wunden = zustand.wpiZustand;
  var geschlossen = 0;
  final zone = eingabe.zone;
  if (eingabe.wundheilungAngesagt &&
      eingabe.zauberId == kBalsamZauberId &&
      zone != null) {
    final moeglich = math.min(eingabe.wunden, wunden.wundenInZone(zone));
    for (var i = 0; i < moeglich; i++) {
      wunden = wunden.mitWundeEntfernt(zone);
    }
    geschlossen = math.max(0, moeglich);
  }
  var neu = zustand.copyWith(
    currentLep: RessourcenAenderung.schritt(lepDelta)
        .wendeAn(zustand.currentLep),
    currentAsp: RessourcenAenderung.schritt(-aspDelta)
        .wendeAn(zustand.currentAsp),
  );
  if (geschlossen > 0) {
    neu = neu.copyWith(wpiZustand: wunden);
  }
  return HeilAnwendung(
    zustand: neu,
    lep: lepDelta,
    asp: aspDelta,
    wunden: geschlossen,
  );
}

/// Hält fest, was [anwendung] am Zustand tatsächlich verändert hat.
ZustandsBuchung heilungsBuchungAus({
  required HeilEingabe eingabe,
  required HeilAnwendung anwendung,
  required String id,
  required DateTime zeitpunkt,
}) {
  return ZustandsBuchung(
    id: id,
    art: ZustandsBuchungsArt.heilung,
    zeitpunkt: zeitpunkt.toUtc(),
    lepDelta: anwendung.lep,
    aspDelta: -anwendung.asp,
    zone: anwendung.wunden > 0 ? eingabe.zone : null,
    wundenDelta: -anwendung.wunden,
  );
}
