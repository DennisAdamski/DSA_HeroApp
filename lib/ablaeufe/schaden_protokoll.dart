import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_ruecknahme_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';

/// Titel des Protokolleintrags einer Schadensbuchung.
const String schadenProtokollTitel = 'Schaden erhalten';

/// Titel des Protokolleintrags einer Rücknahme.
const String schadenRuecknahmeProtokollTitel = 'Schaden zurückgenommen';

/// Baut den Würfelprotokolleintrag einer Schadensbuchung.
///
/// Der Eintrag macht die Buchung nachvollziehbar, damit sie von Hand
/// korrigiert werden kann: TP, RS, SP (bei TP(A) SP(A) und die echten SP
/// auf LeP), Zone, tatsächlich eingetragene Wunden, Zusatzschaden und
/// INI-Wurf. Er nutzt die vorhandene Probeart [ProbeType.damage], damit
/// ältere App-Versionen keinen unbekannten Typ lesen. `total` ist der
/// LeP-Verlust. [buchungId] verbindet den Eintrag mit seiner Buchung in
/// `HeroState.buchungen`, über die er sich zurücknehmen lässt (ARCH-06).
DiceLogEntry baueSchadensProtokoll({
  required SchadensBuchung buchung,
  required int hinzugefuegteWunden,
  required DateTime zeitpunkt,
  String? buchungId,
}) {
  final ausdauer = buchung.art == SchadensArt.ausdauer;
  final teile = <String>[
    '${ausdauer ? 'TP(A)' : 'TP'} ${buchung.tp} − RS ${buchung.rs} = '
        '${buchung.sp} ${ausdauer ? 'SP(A)' : 'SP'}',
    if (ausdauer) '${buchung.echteSp} SP auf LeP',
  ];
  final zone = buchung.zone;
  if (zone != null) {
    teile.add(wundZoneLabel[zone]!);
  }
  if (buchung.angriffsModifikator != 0) {
    final vorzeichen = buchung.angriffsModifikator > 0 ? '+' : '−';
    teile.add('WS $vorzeichen${buchung.angriffsModifikator.abs()}');
  }
  if (hinzugefuegteWunden > 0) {
    teile.add(
      hinzugefuegteWunden == 1 ? '1 Wunde' : '$hinzugefuegteWunden Wunden',
    );
  }
  if (buchung.zusatzSchaden > 0) {
    teile.add('+${buchung.zusatzSchaden} SP Zusatz');
  }
  if (buchung.kopfIniWurf > 0 && hinzugefuegteWunden > 0) {
    teile.add('INI −${buchung.kopfIniWurf}');
  }
  return diceLogEntryFromRoll(
    title: schadenProtokollTitel,
    subtitle: teile.join(' · '),
    diceValues: const <int>[],
    type: ProbeType.damage,
    total: buchung.verlust,
    timestamp: zeitpunkt,
    buchungId: buchungId,
  );
}

/// Baut den Würfelprotokolleintrag einer Rücknahme (ARCH-06).
///
/// Nennt, was zurückkam und was nicht mehr umkehrbar war; `total` sind die
/// zurückgegebenen LeP. Der Eintrag trägt die ID der Gegenbuchung, die
/// selbst nicht zurücknehmbar ist.
DiceLogEntry baueRuecknahmeProtokoll({
  required SchadensRuecknahmePlan plan,
  required String gegenbuchungId,
  required DateTime zeitpunkt,
}) {
  final teile = <String>[
    if (plan.lepPlus > 0) '+${plan.lepPlus} LeP',
    if (plan.auPlus > 0) '+${plan.auPlus} AuP',
  ];
  final zone = plan.zone;
  if (zone != null && plan.wundenEntfernt > 0) {
    final wunden = plan.wundenEntfernt == 1
        ? '1 Wunde'
        : '${plan.wundenEntfernt} Wunden';
    teile.add('$wunden ${wundZoneLabel[zone]} entfernt');
  }
  if (plan.wundenNichtMehrVorhanden > 0) {
    teile.add('${plan.wundenNichtMehrVorhanden} bereits geheilt');
  }
  if (plan.zoneUnbekannt) {
    teile.add('Wunden unverändert');
  }
  if (plan.kopfIniMalusMinus > 0) {
    teile.add('INI +${plan.kopfIniMalusMinus}');
  }
  return diceLogEntryFromRoll(
    title: schadenRuecknahmeProtokollTitel,
    subtitle: teile.join(' · '),
    diceValues: const <int>[],
    type: ProbeType.damage,
    total: plan.lepPlus,
    timestamp: zeitpunkt,
    buchungId: gegenbuchungId,
  );
}
