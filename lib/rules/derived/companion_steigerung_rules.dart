/// Steigerungsregeln fuer Vertrautentiere (WdZ S. 125).
///
/// Gesteigert wird nach Komplexitaet F. Eigenschaften, AT, PA, GS und RK
/// steigen direkt (Kosten nach dem aktuellen Wert), LeP, AsP und MR werden
/// wie bei Helden hinzugekauft (Kosten nach der Zahl gekaufter Punkte).
/// Kein Wert darf ueber das Anderthalbfache seines Startwerts steigen,
/// ausgenommen AsP und RK. INI, Loyalitaet und AuP sind nicht steigerbar;
/// in Altdaten gebuchte Stufen zaehlen weiter und bekommen nur einen Hinweis.
library;

import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion_attack.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion_speed.dart';

/// Feste Komplexitaet fuer alle Vertrauten-Steigerungen.
const LearnCost kVertrauterKomplexitaet = LearnCost.f;

/// Verfuegbare AP des Vertrauten.
int companionApVerfuegbar(HeroCompanion c) =>
    (c.apGesamt ?? 0) - (c.apAusgegeben ?? 0);

/// Hoechster Gesamtwert nach WdZ S. 125: das abgerundete Anderthalbfache
/// des Startwerts.
int vertrautenGrenze(int startwert) =>
    startwert <= 0 ? startwert : (startwert * 3) ~/ 2;

/// Hoechster Steigerungsstand ueber dem Startwert [startwert].
int vertrautenMaxStandUeber(int startwert) =>
    math.max(0, vertrautenGrenze(startwert) - startwert);

/// Werte, die nach WdZ S. 125 nicht (mehr) steigerbar sind.
const Set<String> kVertrautenNichtSteigerbar = <String>{
  'ini',
  'loyalitaet',
  'aup',
};

/// Werte ohne Obergrenze (WdZ S. 125: AsP und RK).
const Set<String> kVertrautenUnbegrenzt = <String>{'asp', 'rk'};

/// Ob der Wert [schluessel] nach WdZ gesteigert werden darf.
bool vertrautenWertSteigerbar(String schluessel) =>
    !kVertrautenNichtSteigerbar.contains(schluessel);

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

/// Schluessel der hinzugekauften Werte (Steigerung ab 0 ueber dem
/// Startwert); AuP nur noch fuer Altdaten.
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

/// Wirksame GS einer Geschwindigkeit (Grundwert + gekaufte Steigerung).
int begleiterTempo(HeroCompanionSpeed tempo) => tempo.wert + tempo.steigerung;

/// Hoechster Steigerungsstand des Werts [schluessel] nach WdZ S. 125;
/// `null` heisst unbegrenzt, 0 bei nicht steigerbaren Werten.
///
/// Eigenschaften beziehen sich auf ihren eingetragenen Grundwert, LeP und MR
/// auf ihren festgehaltenen Startwert.
int? vertrautenMaxStand(HeroCompanion c, String schluessel) {
  if (!vertrautenWertSteigerbar(schluessel)) return 0;
  if (kVertrautenUnbegrenzt.contains(schluessel)) return null;
  final start = switch (schluessel) {
    'lep' || 'mr' =>
      companionPoolStartwert(c, schluessel) ??
          companionPoolBasiswert(c, schluessel),
    _ => companionBasiswert(c, schluessel),
  };
  if (start == null) return 0;
  return vertrautenMaxStandUeber(start);
}

/// Hinweis, wenn ein gebuchter Stand [stand] die Regeln nach WdZ S. 125
/// verletzt; `null`, wenn alles passt. Gebuchte Stufen bleiben immer stehen.
String? vertrautenGrenzHinweis({
  required int stand,
  required int? maxStand,
  bool steigerbar = true,
}) {
  if (stand <= 0) return null;
  if (!steigerbar) {
    return 'Nach WdZ S. 125 nicht steigerbar; die gebuchten +$stand bleiben.';
  }
  if (maxStand != null && stand > maxStand) {
    return 'Über der Grenze von 1,5 × Startwert (höchstens +$maxStand); die '
        'gebuchten +$stand bleiben.';
  }
  return null;
}

/// [vertrautenGrenzHinweis] für den Wert [schluessel] des Vertrauten [c].
String? vertrautenSteigerungshinweis(HeroCompanion c, String schluessel) =>
    vertrautenGrenzHinweis(
      stand: companionSteigerung(c, schluessel),
      maxStand: vertrautenMaxStand(c, schluessel),
      steigerbar: vertrautenWertSteigerbar(schluessel),
    );

// Anzeigenamen der Steigerungsschlüssel für Hinweise.
const Map<String, String> _hinweisLabel = <String, String>{
  'mu': 'MU',
  'kl': 'KL',
  'inn': 'IN',
  'ch': 'CH',
  'ff': 'FF',
  'ge': 'GE',
  'ko': 'KO',
  'kk': 'KK',
  'ini': 'INI',
  'loyalitaet': 'Loyalität',
  'lep': 'LeP',
  'aup': 'AuP',
  'asp': 'AsP',
  'mr': 'MR',
  'rk': 'RK',
};

/// Alle Hinweise zu gebuchten Steigerungen, die WdZ S. 125 widersprechen
/// (nur bei Vertrauten), z. B. „INI: Nach WdZ S. 125 nicht steigerbar …“.
List<String> vertrautenSteigerungshinweise(HeroCompanion c) {
  if (c.typ != BegleiterTyp.vertrauter) return const <String>[];
  final hinweise = <String>[];
  for (final eintrag in _hinweisLabel.entries) {
    final hinweis = vertrautenSteigerungshinweis(c, eintrag.key);
    if (hinweis != null) hinweise.add('${eintrag.value}: $hinweis');
  }
  for (final angriff in c.angriffe) {
    for (final (label, basis, stand) in <(String, int?, int)>[
      ('AT', angriff.at, angriff.steigerungAt),
      ('PA', angriff.pa, angriff.steigerungPa),
    ]) {
      final hinweis = vertrautenGrenzHinweis(
        stand: stand,
        maxStand: basis == null ? 0 : vertrautenMaxStandUeber(basis),
      );
      if (hinweis != null) hinweise.add('${angriff.name} $label: $hinweis');
    }
  }
  for (final tempo in c.geschwindigkeiten) {
    final hinweis = vertrautenGrenzHinweis(
      stand: tempo.steigerung,
      maxStand: vertrautenMaxStandUeber(tempo.wert),
    );
    if (hinweis != null) hinweise.add('GS ${tempo.art}: $hinweis');
  }
  return hinweise;
}

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

  /// Steigerung der Geschwindigkeit mit der Bewegungsart [art].
  const factory BegleiterSteigerungsziel.geschwindigkeit(String art) =
      BegleiterTempoSteigerung;

  /// Liest den bisher gekauften Steigerungsstand aus [c].
  int standIn(HeroCompanion c);

  /// Liefert [c] mit dem Steigerungsstand [stand].
  HeroCompanion mitStand(HeroCompanion c, int stand);

  /// Hoechster erlaubter Stand nach WdZ S. 125; `null` heisst unbegrenzt.
  int? maxStandIn(HeroCompanion c);
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
  int? maxStandIn(HeroCompanion c) => vertrautenMaxStand(c, schluessel);

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
  int? maxStandIn(HeroCompanion c) {
    final angriff = _angriff(c);
    final basis = parade ? angriff.pa : angriff.at;
    return basis == null ? 0 : vertrautenMaxStandUeber(basis);
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

/// Ziel einer Geschwindigkeit, siehe
/// [BegleiterSteigerungsziel.geschwindigkeit].
///
/// Geschwindigkeiten haben keine ID; getroffen wird die erste mit der
/// Bewegungsart [art].
final class BegleiterTempoSteigerung extends BegleiterSteigerungsziel {
  /// Erstellt das Ziel für die Bewegungsart [art].
  const BegleiterTempoSteigerung(this.art);

  /// Bewegungsart der Geschwindigkeit.
  final String art;

  @override
  int standIn(HeroCompanion c) => _tempo(c).steigerung;

  @override
  int? maxStandIn(HeroCompanion c) => vertrautenMaxStandUeber(_tempo(c).wert);

  @override
  HeroCompanion mitStand(HeroCompanion c, int stand) {
    _tempo(c);
    var getroffen = false;
    final tempi = c.geschwindigkeiten.map((tempo) {
      if (getroffen || tempo.art != art) return tempo;
      getroffen = true;
      return tempo.copyWith(steigerung: stand);
    }).toList();
    return c.copyWith(geschwindigkeiten: tempi);
  }

  // Die Geschwindigkeit im Stand [c]; fehlt sie, ist nichts buchbar.
  HeroCompanionSpeed _tempo(HeroCompanion c) {
    for (final tempo in c.geschwindigkeiten) {
      if (tempo.art == art) return tempo;
    }
    throw StateError('Die Geschwindigkeit wurde inzwischen geändert.');
  }
}

/// Bucht eine Vertrauten-Steigerung auf den gespeicherten Begleiter
/// (ARCH-05).
///
/// Die AP-Kosten hängen vom Ausgangswert ab, den der Steigerungsdialog
/// gezeigt hat ([erwarteterStand]). Steht im gespeicherten Begleiter ein
/// anderer Stand, wurde er inzwischen anderswo gesteigert; dann wirft die
/// Funktion einen [StateError], statt mit falschen Kosten zu buchen. Eine
/// Erhöhung über die Grenze nach WdZ S. 125 weist sie ebenso ab. Sonst
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
  if (neuerStand > erwarteterStand) {
    final maxStand = ziel.maxStandIn(gespeichert);
    if (maxStand != null && neuerStand > maxStand) {
      throw StateError(
        maxStand == 0
            ? 'Dieser Wert ist nach WdZ S. 125 nicht steigerbar.'
            : 'Höchstens +$maxStand (1,5 × Startwert, WdZ S. 125).',
      );
    }
  }
  final gesteigert = ziel.mitStand(gespeichert, neuerStand);
  return gesteigert.copyWith(
    apAusgegeben: (gespeichert.apAusgegeben ?? 0) + apKosten,
  );
}
