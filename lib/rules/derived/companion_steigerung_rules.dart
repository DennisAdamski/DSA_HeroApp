/// Steigerungsregeln fuer Vertrautentiere.
///
/// Alle Werte des Vertrauten werden nach Komplexitaet F gesteigert.
/// Bei LeP, AuP, AsP und MR wird ab 0 gesteigert; das Maximum liegt bei
/// 1,5 × Startwert.
library;

import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion.dart';

/// Feste Komplexitaet fuer alle Vertrauten-Steigerungen.
const LearnCost kVertrauterKomplexitaet = LearnCost.f;

/// Verfuegbare AP des Vertrauten.
int companionApVerfuegbar(HeroCompanion c) =>
    (c.apGesamt ?? 0) - (c.apAusgegeben ?? 0);

/// Maximale Steigerungsstufe fuer Pool-Werte (LeP, AuP, AsP, MR).
///
/// Steigerung beginnt bei 0. Das Maximum ist `(1.5 * startwert).floor()`.
int poolMaxSteigerung(int startwert) => (startwert * 1.5).floor();

/// Maximale Steigerungsstufe fuer regulaere Werte, begrenzt durch
/// verfuegbare AP.
int regMaxSteigerung({
  required int aktuellerSteigerungswert,
  required int verfuegbareAp,
}) {
  var max = aktuellerSteigerungswert;
  var restAp = verfuegbareAp;
  while (true) {
    final kosten = kVertrauterKomplexitaet.costForStep(max);
    if (kosten > restAp) return max;
    restAp -= kosten;
    max++;
  }
}

/// Schluessel aller steigerbaren Companion-Eigenschaften.
const List<(String label, String key)> kCompanionEigenschaftKeys = [
  ('MU', 'mu'),
  ('KL', 'kl'),
  ('IN', 'inn'),
  ('CH', 'ch'),
  ('FF', 'ff'),
  ('GE', 'ge'),
  ('KO', 'ko'),
  ('KK', 'kk'),
];

/// Schluessel aller steigerbaren Companion-Kampfwerte (ohne Angriffe).
const List<(String label, String key)> kCompanionKampfwertKeys = [
  ('INI', 'ini'),
  ('Loyalität', 'loyalitaet'),
];

/// Schluessel der Pool-Werte (Steigerung ab 0, Max = 1,5 × Startwert).
const List<(String label, String key)> kCompanionPoolKeys = [
  ('LeP', 'lep'),
  ('AuP', 'aup'),
  ('AsP', 'asp'),
  ('MR', 'mr'),
];

/// Liest den Basiswert einer regulaeren Eigenschaft/Kampfwert vom Companion.
int? companionBasiswert(HeroCompanion c, String key) {
  return switch (key) {
    'mu' => c.mu,
    'kl' => c.kl,
    'inn' => c.inn,
    'ch' => c.ch,
    'ff' => c.ff,
    'ge' => c.ge,
    'ko' => c.ko,
    'kk' => c.kk,
    'ini' => c.ini,
    'loyalitaet' => c.loyalitaet,
    _ => null,
  };
}

/// Liest den Pool-Startwert (einmalig festgehaltener Ausgangswert).
int? companionPoolStartwert(HeroCompanion c, String key) {
  return switch (key) {
    'lep' => c.startLep,
    'aup' => c.startAup,
    'asp' => c.startAsp,
    'mr' => c.startMr,
    _ => null,
  };
}

/// Liest den aktuellen Pool-Basiswert (vor Steigerung).
int? companionPoolBasiswert(HeroCompanion c, String key) {
  return switch (key) {
    'lep' => c.maxLep,
    'aup' => c.maxAup,
    'asp' => c.maxAsp,
    'mr' => c.magieresistenz,
    _ => null,
  };
}

/// Gekaufte Steigerungen fuer einen Schluessel.
int companionSteigerung(HeroCompanion c, String key) =>
    c.steigerungen[key] ?? 0;

/// Effektiver Wert einer regulaeren Eigenschaft (Basis + Steigerung).
int? companionEffektivwert(HeroCompanion c, String key) {
  final basis = companionBasiswert(c, key);
  if (basis == null) return null;
  return basis + companionSteigerung(c, key);
}

/// Effektiver Pool-Wert (Startwert + Steigerung).
///
/// Faellt auf den aktuellen Basiswert zurueck, wenn noch kein Startwert
/// festgehalten wurde.
int? companionEffektiverPoolwert(HeroCompanion c, String key) {
  final startwert = companionPoolStartwert(c, key) ??
      companionPoolBasiswert(c, key);
  if (startwert == null) return null;
  return startwert + companionSteigerung(c, key);
}

/// Effektiver RK-Wert (Basis-RK + Steigerung).
int companionEffektiverRk(HeroCompanion c, int basisRk) =>
    basisRk + companionSteigerung(c, 'rk');
