/// Steigerungsregeln fuer Vertrautentiere.
///
/// Alle Werte des Vertrauten werden nach Komplexitaet F gesteigert.
/// Bei LeP, AuP, AsP und MR wird ab 0 gesteigert; das Maximum liegt bei
/// 1,5 × Startwert.
library;

import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion_attack.dart';

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
  final startwert =
      companionPoolStartwert(c, key) ?? companionPoolBasiswert(c, key);
  if (startwert == null) return null;
  return startwert + companionSteigerung(c, key);
}

/// Wirksame AT eines Begleiterangriffs (Basis + gekaufte Steigerung).
int? begleiterAngriffAt(HeroCompanionAttack a) =>
    a.at == null ? null : a.at! + a.steigerungAt;

/// Wirksame PA eines Begleiterangriffs; `null` heißt keine Parade möglich.
int? begleiterAngriffPa(HeroCompanionAttack a) =>
    a.pa == null ? null : a.pa! + a.steigerungPa;

/// Effektiver RK-Wert (Basis-RK + Steigerung).
int companionEffektiverRk(HeroCompanion c, int basisRk) =>
    basisRk + companionSteigerung(c, 'rk');

/// Was eine Vertrauten-Steigerung erhöht und wo ihr Steigerungsstand steht.
sealed class BegleiterSteigerungsziel {
  const BegleiterSteigerungsziel();

  /// Steigerung eines Werts aus `steigerungen` (Eigenschaft, Kampfwert,
  /// Pool-Wert oder `rk`).
  const factory BegleiterSteigerungsziel.wert(String schluessel) =
      BegleiterWertSteigerung;

  /// Steigerung von AT bzw. PA ([parade]) des Angriffs [angriffId].
  const factory BegleiterSteigerungsziel.angriff(
    String angriffId, {
    required bool parade,
  }) = BegleiterAngriffSteigerung;

  /// Liest den bisher gekauften Steigerungsstand aus [c].
  int standIn(HeroCompanion c);

  /// Liefert [c] mit dem Steigerungsstand [stand].
  HeroCompanion mitStand(HeroCompanion c, int stand);
}

/// Ziel eines Werts aus `steigerungen`, siehe
/// [BegleiterSteigerungsziel.wert].
final class BegleiterWertSteigerung extends BegleiterSteigerungsziel {
  /// Erstellt das Ziel für [schluessel].
  const BegleiterWertSteigerung(this.schluessel);

  /// Schlüssel in `HeroCompanion.steigerungen`.
  final String schluessel;

  @override
  int standIn(HeroCompanion c) => companionSteigerung(c, schluessel);

  @override
  HeroCompanion mitStand(HeroCompanion c, int stand) {
    final steigerungen = Map<String, int>.of(c.steigerungen);
    steigerungen[schluessel] = stand;
    return c.copyWith(steigerungen: steigerungen);
  }
}

/// Ziel eines Angriffswerts, siehe [BegleiterSteigerungsziel.angriff].
final class BegleiterAngriffSteigerung extends BegleiterSteigerungsziel {
  /// Erstellt das Ziel für AT bzw. PA des Angriffs [angriffId].
  const BegleiterAngriffSteigerung(this.angriffId, {required this.parade});

  /// ID des Angriffs.
  final String angriffId;

  /// `true` für PA, `false` für AT.
  final bool parade;

  @override
  int standIn(HeroCompanion c) {
    final angriff = _angriff(c);
    return parade ? angriff.steigerungPa : angriff.steigerungAt;
  }

  @override
  HeroCompanion mitStand(HeroCompanion c, int stand) {
    _angriff(c);
    final angriffe = c.angriffe.map((angriff) {
      if (angriff.id != angriffId) {
        return angriff;
      }
      return parade
          ? angriff.copyWith(steigerungPa: stand)
          : angriff.copyWith(steigerungAt: stand);
    }).toList();
    return c.copyWith(angriffe: angriffe);
  }

  // Der Angriff im Stand [c]; fehlt er, ist die Steigerung nicht buchbar.
  HeroCompanionAttack _angriff(HeroCompanion c) {
    for (final angriff in c.angriffe) {
      if (angriff.id == angriffId) {
        return angriff;
      }
    }
    throw StateError('Der Angriff wurde inzwischen entfernt.');
  }
}

/// Bucht eine Vertrauten-Steigerung auf den gespeicherten Begleiter
/// (ARCH-05).
///
/// Die AP-Kosten hängen vom Ausgangswert ab, den der Steigerungsdialog
/// gezeigt hat ([erwarteterStand]). Steht im gespeicherten Begleiter ein
/// anderer Stand, wurde er inzwischen anderswo gesteigert; dann wirft die
/// Funktion einen [StateError], statt mit falschen Kosten zu buchen. Sonst
/// setzt sie [neuerStand] und addiert [apKosten] auf die ausgegebenen AP des
/// Vertrauten.
HeroCompanion steigereBegleiter(
  HeroCompanion gespeichert, {
  required BegleiterSteigerungsziel ziel,
  required int erwarteterStand,
  required int neuerStand,
  required int apKosten,
}) {
  if (ziel.standIn(gespeichert) != erwarteterStand) {
    throw StateError(
      'Der Vertraute wurde inzwischen gesteigert. Bitte die Steigerung '
      'erneut öffnen.',
    );
  }
  final gesteigert = ziel.mitStand(gespeichert, neuerStand);
  return gesteigert.copyWith(
    apAusgegeben: (gespeichert.apAusgegeben ?? 0) + apKosten,
  );
}
