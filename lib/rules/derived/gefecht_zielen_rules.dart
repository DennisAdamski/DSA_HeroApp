import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_ansage_rules.dart';
import 'gefecht_held_rules.dart';

/// WdS 98: Scharf-/Meisterschützen benötigen eine statt zwei Aktionen pro Punkt.
int gefechtsOptionaleZieldauer(
  int erleichterung, {
  bool scharfschuetze = false,
  bool meisterschuetze = false,
}) => erleichterung * (scharfschuetze || meisterschuetze ? 1 : 2);

/// Optionales Zielen senkt ausschließlich aktuelle sonstige FK-Zuschläge.
/// Ansage, Gezielter Schuss, Heldenmali und andere Boni bleiben getrennt.
Gefechtspruefung ergaenzeGefechtsZielen(
  Gefechtspruefung p,
  Gefechtszustand s,
  HeroComputedSnapshot snap,
  GefechtAuftrag a,
) {
  final n = a.zielErleichterung;
  if (n == 0) return p;
  final sperren = [...p.sperrgruende];
  final fehlend = [...p.fehlendeAngaben];
  final hinweise = [...p.hinweise];
  final w = gefechtswerteFuer(snap, kampfmittel: p.kampfmittel);
  if (n < 0 || n > 4) {
    sperren.add('Optionales Zielen erlaubt 0 bis 4 Punkte Erleichterung.');
  }
  if (!w.fernkampf ||
      a.aktion != Gefechtsaktion.angriff ||
      a.manuell ||
      a.probe != null ||
      a.distanzSchritte != 0) {
    sperren.add('Optionales Zielen benötigt einen einzelnen Fernkampfangriff.');
  }
  final optionaleDauer = gefechtsOptionaleZieldauer(
    n,
    scharfschuetze: w.scharfschuetze,
    meisterschuetze: w.meisterschuetze,
  );
  final ansageDauer = gefechtsFernkampfansage(
    a.fernkampfansage,
    taw: snap.hero.talents[w.waffe?.talentId]?.talentValue ?? 0,
    fk: w.at,
    scharfschuetze: w.scharfschuetze,
    meisterschuetze: w.meisterschuetze,
  ).zielaktionen;
  final dauer = optionaleDauer + ansageDauer;
  final z = s.zielstand;
  final passend =
      z != null &&
      z.kampfmittel.id == p.kampfmittel?.id &&
      z.kampfmittel.art == p.kampfmittel?.art &&
      z.zielkontakt == (a.kontext ?? s.kontext).kontakt &&
      z.zielkontakt.trim().isNotEmpty &&
      z.ansage == a.fernkampfansage &&
      z.zielErleichterung == n &&
      z.geschossId.isNotEmpty &&
      z.geschossId == w.waffe?.rangedProfile.selectedProjectileOrNull?.id &&
      w.waffe != null &&
      z.waffenprofilKey == gefechtsZielprofilKey(w.waffe!) &&
      z.bezahlteAktionen >= dauer;
  if (!passend && n > 0) {
    fehlend.add(
      'Optionales Zielen benötigt $dauer bezahlte zusätzliche '
      'Zielaktionen für diese Waffe und dieses Ziel.',
    );
  }
  const abbaubareNamen = {'Entfernung', 'Zielsituation', 'Kampfgetümmel'};
  var zuschlag = a.zuschlag;
  for (final mod in p.modifikatoren) {
    if (abbaubareNamen.contains(mod.name)) zuschlag += mod.wert;
  }
  final vorhanden = zuschlag > 0 ? zuschlag : 0;
  final reduziert = n > 0 ? (n < vorhanden ? n : vorhanden) : 0;
  hinweise.add(
    'Optionales Zielen: $optionaleDauer zusätzliche Aktionen für '
    'bis zu $n Punkte; aktuell $reduziert Punkte abbaubar. '
    'Ansage und Gezielter Schuss bleiben unverändert.',
  );
  return Gefechtspruefung(
    aktion: p.aktion,
    status: sperren.isNotEmpty
        ? Gefechtsfreigabe.gesperrt
        : fehlend.isNotEmpty
        ? Gefechtsfreigabe.pruefen
        : p.status,
    gruende: [...sperren, ...fehlend, ...p.entscheidungen, ...hinweise],
    sperrgruende: sperren,
    fehlendeAngaben: fehlend,
    entscheidungen: p.entscheidungen,
    hinweise: hinweise,
    zielwert: p.zielwert == null ? null : p.zielwert! + reduziert,
    erschwernis: p.erschwernis - reduziert,
    modifikatoren: [
      ...p.modifikatoren,
      if (reduziert > 0) Gefechtsmodifikator('Optionales Zielen', -reduziert),
    ],
    angriffe: p.angriffe,
    paraden: p.paraden,
    freie: p.freie,
    zusatz: p.zusatz,
    kampfmittel: p.kampfmittel,
    ausruestungspaar: p.ausruestungspaar,
    mitAnsage: p.mitAnsage,
    probenart: p.probenart,
  );
}
