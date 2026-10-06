import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

/// Körperliche Lage des Helden im Gefecht (WdS S. 11, MCP 6860).
enum GefechtsLage {
  /// Keine Einschränkung durch LeP oder AuP.
  normal,

  /// AuP 0: handlungsunfähig, bis die Ausdauer zurückkehrt.
  handlungsunfaehig,

  /// LeP 5 oder weniger: kampfunfähig, kaum Zaubern oder Talente.
  kampfunfaehig,

  /// LeP 0 oder weniger: so gut wie tot, sofortige Hilfe nötig (WdS S. 56).
  lebensgefahr,
}

/// Ermittelt die schwerste zutreffende Lage aus den aktuellen Werten.
///
/// Wundbedingte Kampfunfähigkeit sperrt weiterhin über die Wundregeln; diese
/// Lage betrifft ausschließlich LeP und AuP und erscheint als Banner. Sie
/// sperrt keine Aktion, weil Sonderregeln und Meisterentscheide am Tisch
/// fallen und ein Held ohne gespeicherten Zustand 0 LeP zeigt.
GefechtsLage gefechtsLage(HeroComputedSnapshot s) {
  final lep = s.state.currentLep;
  if (lep <= 0) return GefechtsLage.lebensgefahr;
  if (lep <= 5) return GefechtsLage.kampfunfaehig;
  if (s.derivedStats.maxAu > 0 && s.state.currentAu <= 0) {
    return GefechtsLage.handlungsunfaehig;
  }
  return GefechtsLage.normal;
}

/// Sichtbarer Hinweis zur Lage; `null` ohne Einschränkung.
String? gefechtsLagetext(GefechtsLage lage) => switch (lage) {
  GefechtsLage.normal => null,
  GefechtsLage.handlungsunfaehig =>
    'AuP 0: handlungsunfähig, bis die Ausdauer zurückkehrt (WdS S. 11).',
  GefechtsLage.kampfunfaehig =>
    'LeP 5 oder weniger: kampfunfähig – keine Kampfaktionen, kein Zaubern, '
        'kaum Talente (WdS S. 11).',
  GefechtsLage.lebensgefahr =>
    'LeP 0 oder weniger: Lebensgefahr – so gut wie tot, sofortige Hilfe '
        'nötig (WdS S. 11/56).',
};
