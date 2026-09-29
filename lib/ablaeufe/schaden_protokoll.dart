import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';

/// Titel des Protokolleintrags einer Schadensbuchung.
const String schadenProtokollTitel = 'Schaden erhalten';

/// Baut den Würfelprotokolleintrag einer Schadensbuchung.
///
/// Der Eintrag macht die Buchung nachvollziehbar, damit sie von Hand
/// korrigiert werden kann: TP, RS, SP, Zone, tatsächlich eingetragene
/// Wunden, Zusatzschaden und INI-Wurf. Er nutzt die vorhandene Probeart
/// [ProbeType.damage], damit ältere App-Versionen keinen unbekannten Typ
/// lesen. `total` ist der Gesamtverlust der Ressource.
DiceLogEntry baueSchadensProtokoll({
  required SchadensBuchung buchung,
  required int hinzugefuegteWunden,
  required DateTime zeitpunkt,
}) {
  final ausdauer = buchung.art == SchadensArt.ausdauer;
  final teile = <String>[
    '${ausdauer ? 'TP(A)' : 'TP'} ${buchung.tp} − RS ${buchung.rs} = '
        '${buchung.sp} ${ausdauer ? 'SP(A)' : 'SP'}',
  ];
  final zone = buchung.zone;
  if (!ausdauer && zone != null) {
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
  );
}
