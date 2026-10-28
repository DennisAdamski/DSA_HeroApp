import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

/// So viele zuletzt gewürfelte Proben zeigt die Spielansicht höchstens.
///
/// Sechs passen in einer Zeile auf ein Tablet und decken die Handvoll Proben
/// ab, die ein Abend tatsächlich wiederholt.
const int kZuletztGewuerfeltMax = 6;

/// Titelpräfix, mit dem die Probensuche die Probe des [typ] benennt.
///
/// `null` für Würfe, die die Probensuche nicht erzeugt (Initiative, Schaden,
/// freie Würfe).
String? probenTitelPraefix(ProbeType typ) => switch (typ) {
  ProbeType.attribute => 'Eigenschaftsprobe: ',
  ProbeType.talent => 'Talentprobe: ',
  ProbeType.spell => 'Zauberprobe: ',
  ProbeType.combatAttack ||
  ProbeType.combatParry ||
  ProbeType.dodge => 'Schnellprobe: ',
  _ => null,
};

/// Ob sich ein Protokolleintrag über die Probensuche wiederholen lässt.
///
/// Nur die Proben, die die Probensuche selbst erzeugt: Eigenschafts-, Talent-
/// und Zauberproben sowie die Kampf-Schnellproben. Schaden, Rast, Gefechts-
/// aufträge, Summenwürfe und Buchungen haben keinen eigenen Probendialog.
bool probeEintragIstWiederholbar(DiceLogEntry eintrag) {
  if (eintrag.isNeutral || eintrag.buchungId != null) return false;
  final praefix = probenTitelPraefix(eintrag.type);
  return praefix != null && eintrag.title.startsWith(praefix);
}

/// Kurzname einer wiederholbaren Probe ohne das Titelpräfix, etwa `Klettern`.
///
/// Bei Kampf-Schnellproben bleibt `AT`, `PA` oder `AW` übrig.
String probenKurzname(DiceLogEntry eintrag) {
  final praefix = probenTitelPraefix(eintrag.type);
  if (praefix == null || !eintrag.title.startsWith(praefix)) {
    return eintrag.title;
  }
  return eintrag.title.substring(praefix.length);
}

/// Die zuletzt gewürfelten, **verschiedenen** Proben des Protokolls.
///
/// Neueste zuerst, höchstens [hoechstens]. Dieselbe Probe (Art und Titel)
/// erscheint nur einmal, mit ihrem jüngsten Wurf; das Protokoll darf in
/// beliebiger Reihenfolge vorliegen, geordnet wird nach Zeitstempel (bei
/// gleichem Zeitstempel gilt der spätere Eintrag als jünger). Nicht
/// wiederholbare Einträge werden übersprungen. Die Eingabe bleibt unverändert.
List<DiceLogEntry> zuletztGewuerfelteProben(
  List<DiceLogEntry> protokoll, {
  int hoechstens = kZuletztGewuerfeltMax,
}) {
  final geordnet =
      [for (var i = 0; i < protokoll.length; i++) (i, protokoll[i])]
        ..sort((a, b) {
          final zeit = b.$2.timestamp.compareTo(a.$2.timestamp);
          return zeit != 0 ? zeit : b.$1.compareTo(a.$1);
        });

  final gesehen = <String>{};
  final ergebnis = <DiceLogEntry>[];
  for (final (_, eintrag) in geordnet) {
    if (ergebnis.length >= hoechstens) break;
    if (!probeEintragIstWiederholbar(eintrag)) continue;
    if (!gesehen.add('${eintrag.type.name}|${eintrag.title}')) continue;
    ergebnis.add(eintrag);
  }
  return List<DiceLogEntry>.unmodifiable(ergebnis);
}
