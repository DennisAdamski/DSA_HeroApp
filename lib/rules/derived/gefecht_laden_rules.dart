import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_laden.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_ablauf_rules.dart';
import 'gefecht_ansage_rules.dart';
import 'gefecht_auftrag_rules.dart';
import 'gefecht_held_rules.dart';
import 'gefecht_kampfmittel_rules.dart';
import 'gefecht_rules.dart';
import 'gefecht_ladezustand_rules.dart';

export 'gefecht_ladezustand_rules.dart';

/// Aktuelle Dauer, erhaltene Zahlung und unmittelbar erklärbare Fortsetzung.
class Gefechtsvorbereitungspruefung {
  /// Trennt Profilprüfung und echte reguläre Aktionskosten von Anzeigewerten.
  const Gefechtsvorbereitungspruefung({
    required this.dauer,
    required this.bezahlt,
    required this.rest,
    required this.buchung,
    required this.gruende,
    this.hinweise = const [],
  });
  final int dauer, bezahlt, rest;
  final Gefechtspruefung buchung;
  final List<String> gruende, hinweise;

  /// Keine Zahlung oder Abschlusswirkung ohne aktuelle Profile und Freigabe.
  bool get ausfuehrbar => gruende.isEmpty && buchung.ausfuehrbar;
}

// Nur bestätigte aktuell geführte Fernkampfwaffen dürfen vorbereitet werden.
List<String> _profilgruende(
  HeroComputedSnapshot snap,
  GefechtsKampfmittelwahl wahl,
) {
  final profil = gefechtsKampfmittelFuer(snap, wahl);
  final w = profil?.waffe;
  final g = w?.rangedProfile.selectedProjectileOrNull;
  return [
    if (profil == null) 'Gewählte Waffe wird inzwischen nicht mehr geführt.',
    if (profil != null) ...profil.sperren,
    if (w == null || w.combatType != WeaponCombatType.ranged)
      'Geführtes Fernkampfprofil fehlt.',
    if (wahl.id.isEmpty || w?.id.isEmpty == true)
      'Stabile Waffen-ID fehlt; Ausrüstung korrigieren.',
    if (g == null || g.id.isEmpty) 'Geschossprofil mit stabiler ID auswählen.',
    if (g != null && g.count <= 0) 'Keine Munition verfügbar.',
  ];
}

// Vorschau enthält bereits SF, Effekte und Waffenmeister; keine zweite Formel.
int _ladezeit(HeroComputedSnapshot snap, GefechtsKampfmittelwahl wahl) =>
    wahl.art == GefechtsKampfmittelArt.nebenwaffe
    ? snap.combatPreviewStats.offhandPreview?.reloadTime ?? 0
    : snap.combatPreviewStats.reloadTime;

/// Die Zusatzzeit folgt derselben Ansageregel wie die Schussfreigabe.
int gefechtsZieldauer(HeroComputedSnapshot snap, GefechtAuftrag a) {
  final w = gefechtswerteFuer(snap, kampfmittel: a.kampfmittel);
  return gefechtsFernkampfansage(
    a.fernkampfansage,
    taw: snap.hero.talents[w.waffe?.talentId]?.talentValue ?? 0,
    fk: w.at,
    scharfschuetze: w.scharfschuetze,
    meisterschuetze: w.meisterschuetze,
  ).zielaktionen;
}

/// Prüft nur den Beginn bezahlten Zielens; dieser Nachweis erlaubt keinen Schuss.
Gefechtspruefung pruefeGefechtsZielbeginn(
  Gefechtszustand s,
  HeroComputedSnapshot snap,
  RulesCatalog k,
  GefechtAuftrag a,
) {
  final wahl = a.kampfmittel ?? gefechtsStandardKampfmittel(snap, a.aktion);
  final w = gefechtsKampfmittelFuer(snap, wahl)?.waffe;
  final z = w == null || wahl == null
      ? null
      : Gefechtszielstand(
          kampfmittel: wahl,
          zielkontakt: a.kontext?.kontakt ?? s.kontext.kontakt,
          ansage: a.fernkampfansage,
          bezahlteAktionen: gefechtsZieldauer(snap, a),
          geschossId: w.rangedProfile.selectedProjectileOrNull?.id ?? '',
          waffenprofilKey: gefechtsZielprofilKey(w),
        );
  // Vorschau ignoriert nur die Schussmarke; Zielzahlung prüft ihr eigenes Budget.
  final p = pruefeGefechtAuftrag(
    s.copyWith(angriffeVerbraucht: 0, paradenVerbraucht: 0, zielstand: z),
    snap,
    k,
    a,
  );
  final zahlen = pruefeManuelleGefechtsaktion(
    s,
    gefechtswerteFuer(snap, kampfmittel: wahl),
    kosten: 1,
  );
  final gruende = [
    ...p.sperrgruende,
    ...p.fehlendeAngaben,
    ...p.entscheidungen,
    ...zahlen.sperrgruende,
    if (a.fernkampfansage <= 0)
      'Positive Fernkampfansage für Zusatz-Zielen erforderlich.',
    if (wahl != null) ..._profilgruende(snap, wahl),
  ];
  return Gefechtspruefung(
    aktion: Gefechtsaktion.handlung,
    status: gruende.isEmpty
        ? Gefechtsfreigabe.bereit
        : Gefechtsfreigabe.gesperrt,
    gruende: gruende,
    sperrgruende: gruende,
    zielwert: null,
    angriffe: zahlen.angriffe,
    paraden: zahlen.paraden,
  );
}

/// Beginnt einen Ladeauftrag oder bestätigt die ausdrücklich bekannte Ladung.
Gefechtszustand beginneGefechtsLaden(
  Gefechtszustand s,
  HeroComputedSnapshot snap,
  GefechtsKampfmittelwahl wahl, {
  bool? anfangGeladen,
}) {
  final gruende = _profilgruende(snap, wahl);
  if (s.handlung != null || s.auftrag != null) {
    gruende.add('Andere Handlung läuft.');
  }
  if (gruende.isNotEmpty) throw StateError(gruende.join(' '));
  final w = gefechtsKampfmittelFuer(snap, wahl)!.waffe!;
  final geladen = gefechtsLadezustand(s, w) ?? anfangGeladen;
  if (geladen == null) {
    throw StateError('Anfänglichen Ladezustand dieser Waffe bestätigen.');
  }
  final stand = bestaetigeGefechtsLadung(s, w, geladen);
  if (geladen) return stand;
  final v = Gefechtsvorbereitung(
    kampfmittel: wahl,
    waffenprofilKey: gefechtsLadeprofilKey(w),
    geschossId: w.rangedProfile.selectedProjectileOrNull!.id,
    bezahlteAktionen: 0,
    anfangsdauer: _ladezeit(snap, wahl),
  );
  return bezahleGefechtsVorbereitung(
    stand.copyWith(
      handlung: Gefechtshandlung(
        titel: '${w.name} laden / vorbereiten',
        verbleibend: v.anfangsdauer,
        art: Gefechtshandlungsart.laden,
        vorbereitung: v,
      ),
    ),
    snap,
  );
}

/// Zielen bucht eine wirkliche reguläre Aktion und hält den Schussauftrag fest.
Gefechtszustand beginneGefechtsZielen(
  Gefechtszustand s,
  HeroComputedSnapshot snap,
  RulesCatalog k,
  GefechtAuftrag a,
) {
  final p = pruefeGefechtsZielbeginn(s, snap, k, a);
  if (!p.ausfuehrbar) throw StateError(p.gruende.join(' '));
  final wahl = a.kampfmittel ?? gefechtsStandardKampfmittel(snap, a.aktion)!;
  final w = gefechtsKampfmittelFuer(snap, wahl)!.waffe!;
  final stand = gefechtsLadezustand(s, w);
  if (stand == false || (stand == null && a.kontext?.geladen != true)) {
    throw StateError('Waffe zuerst laden / vorbereiten.');
  }
  final v = Gefechtsvorbereitung(
    kampfmittel: wahl,
    waffenprofilKey: gefechtsZielprofilKey(w),
    geschossId: w.rangedProfile.selectedProjectileOrNull!.id,
    bezahlteAktionen: 0,
    anfangsdauer: gefechtsZieldauer(snap, a),
    schussauftrag: a,
  );
  final neu = bestaetigeGefechtsLadung(s, w, true).copyWith(
    kontext: a.kontext,
    ohneZielstand: true,
    handlung: Gefechtshandlung(
      titel: '${w.name} · Zusatz-Zielen',
      verbleibend: v.anfangsdauer,
      art: Gefechtshandlungsart.zielen,
      vorbereitung: v,
    ),
  );
  return bezahleGefechtsVorbereitung(neu, snap);
}

/// Berechnet Rest = max(0, aktuelle Dauer minus tatsächlich bezahlte Aktionen).
Gefechtsvorbereitungspruefung pruefeGefechtsVorbereitung(
  Gefechtszustand s,
  HeroComputedSnapshot snap,
) {
  final h = s.handlung!;
  final v = h.vorbereitung!;
  final w = gefechtsKampfmittelFuer(snap, v.kampfmittel)?.waffe;
  final laden = h.art == Gefechtshandlungsart.laden;
  final dauer = laden
      ? _ladezeit(snap, v.kampfmittel)
      : gefechtsZieldauer(snap, v.schussauftrag!);
  final rest = dauer > v.bezahlteAktionen ? dauer - v.bezahlteAktionen : 0;
  final gruende = _profilgruende(snap, v.kampfmittel);
  if (w != null) {
    final key = laden ? gefechtsLadeprofilKey(w) : gefechtsZielprofilKey(w);
    if (key != v.waffenprofilKey ||
        w.rangedProfile.selectedProjectileOrNull?.id != v.geschossId) {
      gruende.add(
        'Waffen-/Geschossprofil oder Bestand geändert; Vorbereitung abbrechen und neu beginnen.',
      );
    }
  }
  if (!laden && s.kontext.kontakt != v.schussauftrag!.kontext?.kontakt) {
    gruende.add(
      'Zielkontakt geändert; bezahltes Zielen gilt nur für das ursprüngliche Ziel.',
    );
  }
  final p = pruefeManuelleGefechtsaktion(
    s,
    gefechtswerteFuer(snap, kampfmittel: v.kampfmittel),
    kosten: rest == 0 ? 0 : 1,
    handlungFortsetzen: true,
  );
  return Gefechtsvorbereitungspruefung(
    dauer: dauer,
    bezahlt: v.bezahlteAktionen,
    rest: rest,
    buchung: p,
    gruende: [...gruende, ...p.sperrgruende],
    hinweise: [
      if (dauer != v.anfangsdauer)
        'Dauer geändert: ${v.anfangsdauer} → $dauer Aktionen; ${v.bezahlteAktionen} bezahlte Aktionen bleiben erhalten.',
    ],
  );
}

/// Bucht ausschließlich reguläre Marken; Abschluss ohne Rest fordert keine neue.
Gefechtszustand bezahleGefechtsVorbereitung(
  Gefechtszustand s,
  HeroComputedSnapshot snap,
) {
  final p = pruefeGefechtsVorbereitung(s, snap);
  if (!p.ausfuehrbar) throw StateError(p.gruende.join(' '));
  final h = s.handlung!;
  final v = h.vorbereitung!;
  final bezahlt = p.bezahlt + (p.rest > 0 ? 1 : 0);
  final rest = p.dauer > bezahlt ? p.dauer - bezahlt : 0;
  final w = gefechtsKampfmittelFuer(snap, v.kampfmittel)!.waffe!;
  // Eine PA-Marke für Vorbereitung wickelt keinen gegnerischen Angriff ab.
  final neu = p.rest == 0
      ? s
      : verbraucheGefechtsaktion(
          s,
          gefechtswerteFuer(snap, kampfmittel: v.kampfmittel),
          p.buchung,
        ).copyWith(kontext: s.kontext);
  if (h.art == Gefechtshandlungsart.laden && rest == 0) {
    return bestaetigeGefechtsLadung(neu, w, true).copyWith(ohneHandlung: true);
  }
  final z = h.art != Gefechtshandlungsart.zielen
      ? null
      : Gefechtszielstand(
          kampfmittel: v.kampfmittel,
          zielkontakt: v.schussauftrag!.kontext!.kontakt,
          ansage: v.schussauftrag!.fernkampfansage,
          bezahlteAktionen: bezahlt,
          geschossId: v.geschossId,
          waffenprofilKey: v.waffenprofilKey,
        );
  return neu.copyWith(
    zielstand: z,
    handlung: h.copyWith(
      verbleibend: rest,
      vorbereitung: v.mitZahlung(bezahlt),
    ),
  );
}

/// Ein vorbereiteter Schuss prüft erneut sein eigenes Budget und alle Angaben.
Gefechtspruefung pruefeGefechtsZielschuss(
  Gefechtszustand s,
  HeroComputedSnapshot snap,
  RulesCatalog k,
) {
  final zeit = pruefeGefechtsVorbereitung(s, snap);
  if (!zeit.ausfuehrbar || zeit.rest > 0) {
    final gruende = [
      ...zeit.gruende,
      if (zeit.rest > 0) 'Noch ${zeit.rest} zusätzliche Zielaktionen bezahlen.',
    ];
    return Gefechtspruefung(
      aktion: Gefechtsaktion.angriff,
      status: Gefechtsfreigabe.gesperrt,
      gruende: gruende,
      sperrgruende: gruende,
      zielwert: null,
    );
  }
  return pruefeGefechtAuftrag(
    s.copyWith(ohneHandlung: true),
    snap,
    k,
    gefechtsAktuellerZielauftrag(s),
  );
}

/// Erhält den gebundenen Schuss, nutzt aber aktuellen DK- und Sitzungskontext.
GefechtAuftrag gefechtsAktuellerZielauftrag(Gefechtszustand s) {
  final a = s.handlung!.vorbereitung!.schussauftrag!;
  return GefechtAuftrag(
    aktion: a.aktion,
    titel: a.titel,
    zuschlag: a.zuschlag,
    dk: s.dk,
    dauer: a.dauer,
    kosten: a.kosten,
    zielwert: a.zielwert,
    manoever: a.manoever,
    probe: a.probe,
    manuell: a.manuell,
    grosserGegner: a.grosserGegner,
    grosserSchild: a.grosserSchild,
    zusatzParade: a.zusatzParade,
    kontext: s.kontext,
    distanzSchritte: a.distanzSchritte,
    kampfmittel: a.kampfmittel,
    eingabefehler: a.eingabefehler,
    bestaetigteEntscheidungen: a.bestaetigteEntscheidungen,
    finte: a.finte,
    wuchtschlag: a.wuchtschlag,
    fernkampfansage: a.fernkampfansage,
    meisterparadeAnsage: a.meisterparadeAnsage,
    schildAnsagegrenze: a.schildAnsagegrenze,
    manuelleKampfaktion: a.manuelleKampfaktion,
  );
}
