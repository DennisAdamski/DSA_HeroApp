// AP des Vertrauten: Anteil an den Abenteuer-AP der Hexe und Übertragung
// (WdZ S. 124 f., Nutzerentscheidung 8. Oktober 2026).
//
// Der Vertraute erhält fest ein Viertel der AP, die die Hexe durch
// Abenteuerabschluss und Reisebericht bekommt, ohne Abzug bei ihr. Der
// Zähler `abenteuerApErfasst` rechnet ab dem Einrichten exakt: Gutgeschrieben
// wird jeweils ⌊neu / 4⌋ − ⌊alt / 4⌋, eine Rücknahme zieht ebenso ab.
// Übertragene AP zahlt die Hexe als ausgegebene AP; je volle 50 steigt die
// Loyalität um 1, höchstens auf 25.

import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/catalog/vertrauten_katalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_aenderung_rules.dart';

/// Anteil des Vertrauten an [abenteuerAp] Abenteuer-AP der Hexe.
int vertrautenApAnteil(int abenteuerAp) =>
    abenteuerAp <= 0 ? 0 : abenteuerAp ~/ kVertrautenApAnteilNenner;

/// Verteilt eine Änderung der Abenteuer-AP der Hexe um [deltaAbenteuerAp]
/// auf alle Vertrauten mit eingerichtetem Anteil.
///
/// Aufgerufen von Abenteuerabschluss und Reisebericht samt Rücknahmen, damit
/// jeder Weg, der Abenteuer-AP bucht, den Anteil mitbucht. Der Zähler sinkt
/// nie unter 0; AP, die vor dem Einrichten gebucht wurden, nimmt eine
/// Rücknahme dem Vertrauten deshalb nicht weg.
HeroSheet mitVertrautenApAnteil(HeroSheet held, int deltaAbenteuerAp) {
  if (deltaAbenteuerAp == 0) return held;
  var geaendert = false;
  final begleiter = held.companions.map((c) {
    final bindung = c.vertrautenBindung;
    final alt = bindung?.abenteuerApErfasst;
    if (c.typ != BegleiterTyp.vertrauter || bindung == null || alt == null) {
      return c;
    }
    final neu = math.max(0, alt + deltaAbenteuerAp);
    final gutschrift = vertrautenApAnteil(neu) - vertrautenApAnteil(alt);
    geaendert = true;
    return c.copyWith(
      apGesamt: math.max(0, (c.apGesamt ?? 0) + gutschrift),
      vertrautenBindung: bindung.copyWith(abenteuerApErfasst: neu),
    );
  }).toList();
  if (!geaendert) return held;
  return held.copyWith(companions: List<HeroCompanion>.unmodifiable(begleiter));
}

/// Vorschlag für den einmaligen Nachtrag: ein Viertel der bisher gebuchten
/// Abenteuer-AP (angewendete Abenteuerbelohnungen) und [reiseberichtAp].
int vertrautenNachtragsvorschlag(HeroSheet held, {int reiseberichtAp = 0}) {
  var summe = reiseberichtAp;
  for (final abenteuer in held.adventures) {
    if (abenteuer.rewardsApplied && abenteuer.apReward > 0) {
      summe += abenteuer.apReward;
    }
  }
  return vertrautenApAnteil(summe);
}

/// Richtet den AP-Anteil des Vertrauten [begleiterId] ein und schreibt
/// einmalig [nachtragAp] gut.
///
/// Ab jetzt bucht [mitVertrautenApAnteil] automatisch. Wirft einen
/// [StateError] ohne Bindung oder wenn der Anteil schon eingerichtet ist.
HeroSheet richteVertrautenApAnteilEin(
  HeroSheet held, {
  required String begleiterId,
  required int nachtragAp,
}) {
  if (nachtragAp < 0) {
    throw StateError('Der Nachtrag darf nicht negativ sein.');
  }
  return ersetzeBegleiter(held, begleiterId, (gespeichert) {
    final bindung = _bindung(gespeichert);
    if (bindung.abenteuerApErfasst != null) {
      throw StateError('Der AP-Anteil ist inzwischen schon eingerichtet.');
    }
    return gespeichert.copyWith(
      apGesamt: (gespeichert.apGesamt ?? 0) + nachtragAp,
      vertrautenBindung: bindung.copyWith(abenteuerApErfasst: 0),
    );
  });
}

/// Loyalität nach einer Übertragung von [altUebertragen] auf
/// [neuUebertragen] AP: je volle 50 AP +1, höchstens 25 (WdZ S. 124).
///
/// Eine schon höhere Loyalität sinkt nicht.
int? vertrautenLoyalitaetNachUebertragung(
  int? loyalitaet, {
  required int altUebertragen,
  required int neuUebertragen,
}) {
  final schritte =
      neuUebertragen ~/ kVertrautenApJeLoyalitaet -
      altUebertragen ~/ kVertrautenApJeLoyalitaet;
  if (schritte <= 0) return loyalitaet;
  final basis = loyalitaet ?? kVertrautenStartLoyalitaet;
  if (basis >= kVertrautenMaxLoyalitaet) return basis;
  return math.min(kVertrautenMaxLoyalitaet, basis + schritte);
}

/// Überträgt [ap] AP der Hexe auf den Vertrauten [begleiterId] (WdZ S. 125).
///
/// Die Hexe zahlt sie als ausgegebene AP, der Vertraute erhält sie zu seinen
/// Gesamt-AP, und die Loyalität steigt je volle 50 übertragene AP. Wirft einen
/// [StateError] ohne Bindung, bei geändertem Übertragungsstand
/// ([erwartetUebertragen]) oder zu wenig freien AP der Hexe.
HeroSheet uebertrageApAufVertrauten(
  HeroSheet held, {
  required String begleiterId,
  required int ap,
  required int erwartetUebertragen,
}) {
  if (ap <= 0) throw StateError('Bitte eine positive AP-Zahl angeben.');
  final frei = held.apTotal - held.apSpent;
  if (frei < ap) {
    throw StateError('Die Hexe hat nur $frei AP frei.');
  }
  final uebertragen = ersetzeBegleiter(held, begleiterId, (gespeichert) {
    final bindung = _bindung(gespeichert);
    if (bindung.apUebertragen != erwartetUebertragen) {
      throw StateError('Inzwischen wurden AP übertragen. Bitte erneut öffnen.');
    }
    final neu = bindung.apUebertragen + ap;
    return gespeichert.copyWith(
      apGesamt: (gespeichert.apGesamt ?? 0) + ap,
      loyalitaet: vertrautenLoyalitaetNachUebertragung(
        gespeichert.loyalitaet,
        altUebertragen: bindung.apUebertragen,
        neuUebertragen: neu,
      ),
      vertrautenBindung: bindung.copyWith(apUebertragen: neu),
    );
  });
  return mitApSchritt(uebertragen, ApKonto.ausgegeben, ap);
}

VertrautenBindung _bindung(HeroCompanion c) {
  final bindung = c.vertrautenBindung;
  if (c.typ != BegleiterTyp.vertrauter || bindung == null) {
    throw StateError('Der Vertraute ist noch nicht gebunden.');
  }
  return bindung;
}
