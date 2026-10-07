/// Wirksame Werte eines Begleiters: Grundwert + gekaufte Steigerung +
/// Ausbildung.
///
/// Die Ausbildung wirkt nur bei Reittieren mit erfasstem Ausbildungsstand
/// (`istReittierMitAusbildung`). `companionEffektivwert` bleibt bewusst ohne
/// Ausbildung, weil die Vertrauten-Steigerung auf ihm aufbaut.
library;

import 'package:dsa_heldenverwaltung/catalog/reittier_ausbildung_typen.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';

import 'companion_steigerung_rules.dart';
import 'reittier_ausbildung_rules.dart';
import 'tp_ausdruck_rules.dart';

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
/// Die Ausbildung ändert KK und Loyalität; alle übrigen Werte entsprechen
/// `companionEffektivwert`.
int? begleiterWirksamerWert(HeroCompanion c, String key) {
  final basis = companionEffektivwert(c, key);
  if (basis == null) {
    return null;
  }
  final mods = begleiterAusbildungsModifikationen(c);
  return switch (key) {
    'kk' => basis + mods.kk,
    'loyalitaet' => basis + mods.lo,
    _ => basis,
  };
}

/// Wirksame AT eines Angriffs; die Ausbildung wirkt auf alle Pferdeangriffe.
int? begleiterWirksamerAngriffAt(HeroCompanion c, HeroCompanionAttack a) {
  final at = begleiterAngriffAt(a);
  return at == null ? null : at + begleiterAusbildungsModifikationen(c).at;
}

/// Wirksame TP eines Angriffs; der Ausbildungsbonus „TP (Tritt)“ wirkt nur
/// auf Tritte und Hufschläge.
String begleiterWirksamerAngriffTp(HeroCompanion c, HeroCompanionAttack a) {
  final zuschlag = begleiterAusbildungsModifikationen(c).tpTritt;
  if (zuschlag == 0 || !istTrittAngriff(a)) {
    return a.tp;
  }
  return tpMitZuschlag(a.tp, zuschlag);
}

/// `true`, wenn der Angriff ein Tritt oder Hufschlag ist (am Namen erkannt).
bool istTrittAngriff(HeroCompanionAttack a) {
  final name = a.name.toLowerCase();
  return name.contains('tritt') || name.contains('huf');
}

/// Geschwindigkeiten mit Ausbildungsmodifikationen für Trab und Galopp.
///
/// Gangarten werden am Namen erkannt; nicht erkannte Angaben bleiben
/// unverändert.
List<HeroCompanionSpeed> begleiterWirksameGeschwindigkeiten(HeroCompanion c) {
  final mods = begleiterAusbildungsModifikationen(c);
  if (mods.gsTrab == 0 && mods.gsGalopp == 0) {
    return c.geschwindigkeiten;
  }
  return <HeroCompanionSpeed>[
    for (final s in c.geschwindigkeiten)
      switch (reittierGangart(s)) {
        ReittierGangart.trab => s.copyWith(wert: s.wert + mods.gsTrab),
        ReittierGangart.galopp => s.copyWith(wert: s.wert + mods.gsGalopp),
        _ => s,
      },
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
