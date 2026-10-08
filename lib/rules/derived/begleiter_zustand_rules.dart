// Laufende Werte von Begleitern (LeP, AsP, AuP) im `HeroState`.
//
// Ein Begleiter ohne Eintrag ist „voll“, also gleich dem wirksamen Maximum
// (`begleiterWirksamerPoolwert`: Startwert, Steigerung, Tierausbildung). Wie
// bei den Ressourcen des Helden meldet die Bedienung eine
// [RessourcenAenderung] und nie einen fertigen Wert; angewendet wird sie auf
// den frisch geladenen Zustand (ARCH-05). Ein Wert gleich dem Maximum wird als
// „voll“ (`null`) gespeichert und entfällt im JSON.

import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_wirkwert_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';

/// Untergrenze der Lebenspunkte eines Begleiters beim Bedienen (wie beim
/// Helden: LeP haben keine echte Untergrenze, die Knöpfe enden bei −10).
const int kBegleiterLepUntergrenze = -10;

/// Die drei laufenden Werte eines Begleiters.
enum BegleiterPool {
  /// Lebenspunkte.
  lep,

  /// Astralpunkte.
  asp,

  /// Ausdauer.
  aup;

  /// Kurzbezeichnung für die Oberfläche.
  String get kuerzel => switch (this) {
    BegleiterPool.lep => 'LeP',
    BegleiterPool.asp => 'AsP',
    BegleiterPool.aup => 'AuP',
  };

  /// Schlüssel für `begleiterWirksamerPoolwert`.
  String get poolKey => name;

  /// Untergrenze beim Bedienen.
  int get untergrenze =>
      this == BegleiterPool.lep ? kBegleiterLepUntergrenze : 0;
}

/// Wirksames Maximum des Pools [pool] von [c]; 0, wenn keines hinterlegt ist.
int begleiterPoolMaximum(HeroCompanion c, BegleiterPool pool) =>
    begleiterWirksamerPoolwert(c, pool.poolKey) ?? 0;

/// Gespeicherter Wert von [pool] oder das Maximum, wenn der Begleiter „voll“
/// ist.
int begleiterAktuellerPool(
  HeroCompanion c,
  HeroState state,
  BegleiterPool pool,
) {
  final gespeichert = _gespeichert(state.begleiterZustaende[c.id], pool);
  return gespeichert ?? begleiterPoolMaximum(c, pool);
}

/// Schritt um [schritt] mit den Grenzen des Pools: nach unten
/// [BegleiterPool.untergrenze], nach oben das Maximum [maximum].
RessourcenAenderung begleiterPoolSchritt(
  BegleiterPool pool,
  int maximum,
  int schritt,
) => RessourcenAenderung.schritt(
  schritt,
  untergrenze: pool.untergrenze,
  obergrenze: maximum,
);

/// Wendet [aenderung] auf den gespeicherten Wert von [pool] des Begleiters
/// [c] an.
///
/// Gerechnet wird vom gespeicherten Wert (bei „voll“ vom Maximum), fremde
/// Begleiter und Felder bleiben unberührt. Liefert [state] selbst zurück,
/// wenn sich nichts ändert, damit nichts gespeichert wird.
HeroState mitBegleiterPool(
  HeroState state,
  HeroCompanion c,
  BegleiterPool pool,
  RessourcenAenderung aenderung,
) {
  final maximum = begleiterPoolMaximum(c, pool);
  final alt = begleiterAktuellerPool(c, state, pool);
  final neu = aenderung.wendeAn(alt);
  if (neu == alt) return state;
  return mitBegleiterPoolWert(state, c.id, pool, neu == maximum ? null : neu);
}

/// Setzt den Pool [pool] des Begleiters [begleiterId] auf [wert]; `null` heißt
/// „voll“. Ein dadurch leerer Zustand entfällt.
HeroState mitBegleiterPoolWert(
  HeroState state,
  String begleiterId,
  BegleiterPool pool,
  int? wert,
) {
  final alt = state.begleiterZustaende[begleiterId] ?? const BegleiterZustand();
  final neu = switch (pool) {
    BegleiterPool.lep => alt.copyWith(currentLep: wert),
    BegleiterPool.asp => alt.copyWith(currentAsp: wert),
    BegleiterPool.aup => alt.copyWith(currentAup: wert),
  };
  return state.withBegleiterZustand(begleiterId, neu);
}

int? _gespeichert(BegleiterZustand? zustand, BegleiterPool pool) =>
    switch (pool) {
      BegleiterPool.lep => zustand?.currentLep,
      BegleiterPool.asp => zustand?.currentAsp,
      BegleiterPool.aup => zustand?.currentAup,
    };
