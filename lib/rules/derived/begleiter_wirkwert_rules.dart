/// Wirksame Werte eines Begleiters: Grundwert + gekaufte Steigerung +
/// Ausbildung.
///
/// Die Reittier-Ausbildung wirkt nur bei Reittieren mit erfasstem
/// Ausbildungsstand (`istReittierMitAusbildung`), die Tierausbildung nur bei
/// gebundenen Vertrauten (`vertrautenAusbildungsModifikationen`).
/// `companionEffektivwert` bleibt bewusst ohne Ausbildung, weil die
/// Vertrauten-Steigerung auf ihm aufbaut.
library;

import 'package:dsa_heldenverwaltung/catalog/reittier_ausbildung_typen.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';

import 'companion_steigerung_rules.dart';
import 'reittier_ausbildung_rules.dart';
import 'tp_ausdruck_rules.dart';
import 'vertrauten_ausbildung_rules.dart';

/// Wirksame Ausbildungsmodifikationen des Begleiters (keine, wenn er kein
/// Reittier mit Ausbildung ist).
ReittierModifikationen begleiterAusbildungsModifikationen(HeroCompanion c) {
  final ausbildung = c.reittierAusbildung;
  if (!istReittierMitAusbildung(c) || ausbildung == null) {
    return ReittierModifikationen.keine;
  }
  return reittierAusbildungsModifikationen(ausbildung);
}

/// Wirksamer Wert einer Eigenschaft oder eines Kampfwerts
/// (Schlüssel wie in `companion_steigerung_rules.dart`).
///
/// Die Reittier-Ausbildung ändert KK und Loyalität, die Tierausbildung eines
/// Vertrauten Eigenschaften und INI; alle übrigen Werte entsprechen
/// `companionEffektivwert`.
int? begleiterWirksamerWert(HeroCompanion c, String key) {
  final basis = companionEffektivwert(c, key);
  if (basis == null) {
    return null;
  }
  final mods = begleiterAusbildungsModifikationen(c);
  final vertraut = vertrautenAusbildungsModifikationen(c).wert(key);
  return switch (key) {
    'kk' => basis + mods.kk + vertraut,
    'loyalitaet' => basis + mods.lo,
    _ => basis + vertraut,
  };
}

/// Wirksamer LeP-, AuP-, AsP- oder MR-Wert: Startwert + Steigerung +
/// Tierausbildung eines Vertrauten (LeP, AuP).
int? begleiterWirksamerPoolwert(HeroCompanion c, String key) {
  final basis = companionEffektiverPoolwert(c, key);
  if (basis == null) return null;
  return basis + vertrautenAusbildungsModifikationen(c).wert(key);
}

/// Wirksame AT eines Angriffs; die Ausbildung wirkt auf alle Angriffe.
int? begleiterWirksamerAngriffAt(HeroCompanion c, HeroCompanionAttack a) {
  final at = begleiterAngriffAt(a);
  return at == null
      ? null
      : at +
            begleiterAusbildungsModifikationen(c).at +
            vertrautenAusbildungsModifikationen(c).at;
}

/// Wirksame PA eines Angriffs; `null` heißt keine Parade möglich.
int? begleiterWirksamerAngriffPa(HeroCompanion c, HeroCompanionAttack a) {
  final pa = begleiterAngriffPa(a);
  return pa == null ? null : pa + vertrautenAusbildungsModifikationen(c).pa;
}

/// Wirksame TP eines Angriffs; der Reittier-Bonus „TP (Tritt)“ wirkt nur
/// auf Tritte und Hufschläge, ein TP-Bonus der Tierausbildung auf alle.
String begleiterWirksamerAngriffTp(HeroCompanion c, HeroCompanionAttack a) {
  final tritt = istTrittAngriff(a)
      ? begleiterAusbildungsModifikationen(c).tpTritt
      : 0;
  final zuschlag = tritt + vertrautenAusbildungsModifikationen(c).tp;
  if (zuschlag == 0) {
    return a.tp;
  }
  return tpMitZuschlag(a.tp, zuschlag);
}

/// `true`, wenn der Angriff ein Tritt oder Hufschlag ist (am Namen erkannt).
bool istTrittAngriff(HeroCompanionAttack a) {
  final name = a.name.toLowerCase();
  return name.contains('tritt') || name.contains('huf');
}

/// Geschwindigkeiten mit gekauften Steigerungen (Vertraute) und
/// Ausbildungsmodifikationen für Trab und Galopp.
///
/// Gangarten werden am Namen erkannt; nicht erkannte Angaben bleiben
/// unverändert. Im Ergebnis steckt die Steigerung im Wert.
List<HeroCompanionSpeed> begleiterWirksameGeschwindigkeiten(HeroCompanion c) {
  final mods = begleiterAusbildungsModifikationen(c);
  final gsVertraut = vertrautenAusbildungsModifikationen(c).gs;
  final gesteigert = c.geschwindigkeiten.any((s) => s.steigerung != 0);
  if (mods.gsTrab == 0 &&
      mods.gsGalopp == 0 &&
      gsVertraut == 0 &&
      !gesteigert) {
    return c.geschwindigkeiten;
  }
  return <HeroCompanionSpeed>[
    for (final s in c.geschwindigkeiten)
      s.copyWith(
        wert:
            begleiterTempo(s) +
            gsVertraut +
            switch (reittierGangart(s)) {
              ReittierGangart.trab => mods.gsTrab,
              ReittierGangart.galopp => mods.gsGalopp,
              _ => 0,
            },
        steigerung: 0,
      ),
  ];
}

/// Trag- bzw. Zugkraftangabe mit Ausbildungsfaktor.
///
/// Ein lesbarer Faktor („×5“) wird erhöht; sonst bleibt der Text und der
/// Zuschlag steht dahinter, damit er sichtbar bleibt.
String begleiterWirksameKraft(String text, int faktorZuschlag) {
  if (faktorZuschlag == 0) {
    return text;
  }
  final faktor = kraftFaktor(text);
  if (faktor == null) {
    final rest = text.trim().isEmpty ? '' : '${text.trim()} ';
    return '$rest(+$faktorZuschlag×KK durch Ausbildung)';
  }
  return '×${faktor + faktorZuschlag}';
}
