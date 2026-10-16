import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';

import 'gefecht_vorgaben_rules.dart';
import 'schaden_rules.dart' show berechneSchadenspunkte, schlageWundenVor;
import 'wund_rules.dart' show computeWundschwellenStufen;

/// WdS S. 97: Zuschlag der Zielgröße im Fernkampf (winzig +8 … sehr groß −2).
int gefechtsZielgroesseZuschlag(GefechtsGroesse g) => switch (g) {
  GefechtsGroesse.winzig => 8,
  GefechtsGroesse.sehrKlein => 6,
  GefechtsGroesse.klein => 4,
  GefechtsGroesse.mittel => 2,
  GefechtsGroesse.gross => 0,
  GefechtsGroesse.sehrGross => -2,
};

/// Ein neuer Gegnerkontakt verwirft Angriffsdaten und bezahltes altes Zielen.
///
/// Sichtbare Vorgaben aus dem Gegner: die zuletzt für diese Paarung gesetzte
/// DK (sonst [startDk]), die Zielgröße als Zielsituation, „sehr groß“ und
/// Kampfgetümmel, wenn der Gegner jemand anderen als [heldId] bindet. Alles
/// bleibt im Gefecht änderbar.
Gefechtszustand waehleGefechtsgegner(
  Gefechtszustand s,
  Gefechtsgegner g, {
  required String startDk,
  String? heldId,
}) {
  if (s.auftrag != null || s.handlung != null) {
    throw StateError('Laufende Handlung zuerst abschließen oder abbrechen.');
  }
  if (!gefechtsGegnerAngreifbar(g)) {
    throw StateError('Tote oder geflohene Gegner sind kein Ziel mehr.');
  }
  if (s.kontext.gegnerId == g.id) return s;
  final alt = s.kontext.gegnerId;
  final dk = s.dk;
  return s.copyWith(
    dk: s.dkJeGegner[g.id] ?? startDk,
    dkJeGegner: alt == null || dk == null
        ? null
        : Map.unmodifiable({...s.dkJeGegner, alt: dk}),
    ohneZielstand: true,
    kontext: gefechtsKontextMitVorgaben(
      Gefechtskontext(
        kontakt: g.name,
        gegnerId: g.id,
        situationsZuschlag: gefechtsZielgroesseZuschlag(g.groesse),
        sehrGross: g.groesse == GefechtsGroesse.sehrGross,
        getuemmel: g.bindet != null && g.bindet != heldId,
      ),
    ),
  );
}

/// WdS S. 109: Jede Körperzone kann höchstens drei Wunden erleiden.
const int kGefechtsWundenJeZone = 3;

/// Abgeleitete Wirkung eines einzelnen Treffers.
class GefechtsgegnerTrefferwirkung {
  /// [sp] ist `null`, solange der RS eines gewöhnlichen Treffers fehlt.
  const GefechtsgegnerTrefferwirkung({
    required this.treffer,
    required this.sp,
    required this.wunden,
    required this.wundenBerechnet,
  });
  final Gefechtsgegnertreffer treffer;
  final int? sp;

  /// Wunden dieses Treffers vor der Zonenobergrenze.
  final int wunden;

  /// `true`, wenn SP und KO bekannt sind; sonst gelten manuelle Wunden.
  final bool wundenBerechnet;
}

/// Schadens- und Wundstand eines Gegners aus seinen Treffern.
class Gefechtsgegnerstand {
  /// Wird ausschließlich von [gefechtsGegnerstand] gebildet.
  const Gefechtsgegnerstand({
    required this.sp,
    required this.tpOhneRs,
    required this.lep,
    required this.wunden,
    required this.wundenNachZone,
    required this.wundenOhneZone,
    required this.wirkungen,
    required this.wundschwellen,
  });

  /// Verrechnete SP aller Treffer mit bekanntem Ergebnis.
  final int sp;

  /// TP gewöhnlicher Treffer, deren RS noch unbekannt ist.
  final int tpOhneRs;

  /// Verbleibende LeP; `null`, wenn Start-LeP oder ein RS fehlen.
  final int? lep;

  /// Alle wirksamen Wunden (mit Zonenobergrenze).
  final int wunden;
  final Map<WundZone, int> wundenNachZone;

  /// Wunden aus Treffern ohne Zone (Spiel ohne Trefferzonen).
  final int wundenOhneZone;
  final List<GefechtsgegnerTrefferwirkung> wirkungen;

  /// Schwellen bei 0,5 KO, KO und 1,5 KO; `null` ohne KO.
  final List<int>? wundschwellen;
}

/// WdS S. 56: RS mindert TP, direkte SP umgehen den Rüstungsschutz.
int? gefechtsGegnerSp(Gefechtsgegner g, Gefechtsgegnertreffer t) {
  if (t.direkt) return t.tp;
  final rs = g.rs;
  return rs == null ? null : berechneSchadenspunkte(tp: t.tp, rs: rs);
}

/// WdS S. 57: eine Wunde über KO/2, zwei über KO, drei über 1,5 × KO.
///
/// Ohne bekannte SP oder KO zählen nur die von Hand bestätigten Wunden.
GefechtsgegnerTrefferwirkung gefechtsGegnerTrefferwirkung(
  Gefechtsgegner g,
  Gefechtsgegnertreffer t,
) {
  final sp = gefechtsGegnerSp(g, t);
  final ko = g.ko;
  if (sp != null && ko != null) {
    final vorschlag = schlageWundenVor(
      sp: sp,
      stufen: computeWundschwellenStufen(ko: ko),
    );
    return GefechtsgegnerTrefferwirkung(
      treffer: t,
      sp: sp,
      wunden: vorschlag.wunden,
      wundenBerechnet: true,
    );
  }
  return GefechtsgegnerTrefferwirkung(
    treffer: t,
    sp: sp,
    wunden: t.wunden ?? 0,
    wundenBerechnet: false,
  );
}

/// Leitet SP, verbleibende LeP und Wunden je Zone frisch aus den Treffern ab.
Gefechtsgegnerstand gefechtsGegnerstand(Gefechtsgegner g) {
  var sp = 0, tpOhneRs = 0, ohneZone = 0;
  final zonen = <WundZone, int>{};
  final wirkungen = <GefechtsgegnerTrefferwirkung>[];
  for (final t in g.treffer) {
    final w = gefechtsGegnerTrefferwirkung(g, t);
    wirkungen.add(w);
    if (w.sp == null) {
      tpOhneRs += t.tp;
    } else {
      sp += w.sp!;
    }
    final zone = t.zone;
    if (zone == null) {
      ohneZone += w.wunden;
    } else if (w.wunden > 0) {
      final neu = (zonen[zone] ?? 0) + w.wunden;
      zonen[zone] = neu > kGefechtsWundenJeZone ? kGefechtsWundenJeZone : neu;
    }
  }
  final ko = g.ko;
  final stufen = ko == null ? null : computeWundschwellenStufen(ko: ko);
  final start = g.lep;
  return Gefechtsgegnerstand(
    sp: sp,
    tpOhneRs: tpOhneRs,
    lep: start == null || tpOhneRs > 0 ? null : start - sp,
    wunden: ohneZone + zonen.values.fold(0, (a, b) => a + b),
    wundenNachZone: Map.unmodifiable(zonen),
    wundenOhneZone: ohneZone,
    wirkungen: List.unmodifiable(wirkungen),
    wundschwellen: stufen == null
        ? null
        : List.unmodifiable([stufen.halbKo, stufen.ko, stufen.einhalbKo]),
  );
}

/// Hängt einen bestätigten Treffer an; LeP dürfen rechnerisch negativ werden.
Gefechtsgegner gefechtsGegnerschaden(
  Gefechtsgegner g,
  Gefechtsgegnertreffer t,
) {
  if (t.tp < 0) throw ArgumentError('Schaden darf nicht negativ sein.');
  if (t.wunden != null && (t.wunden! < 0 || t.wunden! > 3)) {
    throw ArgumentError('Wunden je Treffer liegen zwischen 0 und 3.');
  }
  return g.copyWith(treffer: List.unmodifiable([...g.treffer, t]));
}

/// Erfasst oder korrigiert einen Gegner, ohne gleichnamige Gegner zu ersetzen.
Gefechtsbegegnung speichereGefechtsgegner(
  Gefechtsbegegnung s,
  Gefechtsgegner g,
) {
  if (g.id.isEmpty || g.name.trim().isEmpty) {
    throw ArgumentError('Name und ID sind erforderlich.');
  }
  if ((g.rs ?? 0) < 0 || (g.lep ?? 1) < 1 || (g.ko ?? 1) < 1) {
    throw ArgumentError('RS mindestens 0; LeP und KO mindestens 1.');
  }
  return s.copyWith(gegner: Map.unmodifiable({...s.gegner, g.id: g}));
}

/// Übernimmt bearbeitete Grundwerte auf den **frischen** Gegner.
///
/// Treffer, Status, Bindung und Manöverfolgen aus der Zwischenzeit bleiben
/// erhalten; ein neuer Gegner wird unverändert erfasst.
Gefechtsbegegnung speichereGefechtsgegnerprofil(
  Gefechtsbegegnung s,
  Gefechtsgegner profil,
) {
  final frisch = s.gegner[profil.id];
  if (frisch == null) return speichereGefechtsgegner(s, profil);
  return speichereGefechtsgegner(
    s,
    frisch.copyWith(
      name: profil.name,
      lep: profil.lep,
      rs: profil.rs,
      ko: profil.ko,
      ini: profil.ini,
      groesse: profil.groesse,
      koerperbau: profil.koerperbau,
    ),
  );
}

/// Verbraucht eine konkrete bestätigte Schadensübernahme höchstens einmal.
Gefechtsbegegnung bucheGefechtsGegnerschaden(
  Gefechtsbegegnung s, {
  required String gegnerId,
  required String buchungId,
  required int tp,
  bool direkt = false,
  WundZone? zone,
  int? wunden,
  int? runde,
  String von = '',
}) {
  if (s.buchungen.contains(buchungId)) return s;
  if (buchungId.isEmpty) throw ArgumentError('Buchungs-ID fehlt.');
  final g = s.gegner[gegnerId];
  if (g == null) throw StateError('Der ursprüngliche Gegner fehlt.');
  final neu = gefechtsGegnerschaden(
    g,
    Gefechtsgegnertreffer(
      buchungId: buchungId,
      tp: tp,
      direkt: direkt,
      zone: zone,
      wunden: wunden,
      runde: runde,
      von: von,
    ),
  );
  return s.copyWith(
    gegner: Map.unmodifiable({...s.gegner, gegnerId: neu}),
    buchungen: Set.unmodifiable({...s.buchungen, buchungId}),
  );
}

/// Nimmt einen Treffer zurück; die Buchungs-ID bleibt verbraucht.
///
/// So kann dieselbe Angriffsrückmeldung nicht erneut gebucht werden.
Gefechtsbegegnung nimmGefechtsGegnertrefferZurueck(
  Gefechtsbegegnung s, {
  required String gegnerId,
  required String buchungId,
}) {
  final g = s.gegner[gegnerId];
  if (g == null || !g.treffer.any((t) => t.buchungId == buchungId)) return s;
  final neu = g.copyWith(
    treffer: List.unmodifiable(
      g.treffer.where((t) => t.buchungId != buchungId),
    ),
  );
  return s.copyWith(gegner: Map.unmodifiable({...s.gegner, gegnerId: neu}));
}

/// Basis S. 139: Kampfunfähige handeln nicht; nur kämpfende Gegner haben
/// einen INI-Zeitpunkt.
bool gefechtsGegnerHandelt(Gefechtsgegner g) =>
    g.status == GefechtsgegnerStatus.kaempft;

/// Tote und geflohene Gegner sind kein Ziel mehr; Kampfunfähige bleiben
/// angreifbar.
bool gefechtsGegnerAngreifbar(Gefechtsgegner g) =>
    g.status == GefechtsgegnerStatus.kaempft ||
    g.status == GefechtsgegnerStatus.kampfunfaehig;

/// Angreifbare Gegner, kämpfende vor kampfunfähigen, sonst in Erfassungsfolge.
List<Gefechtsgegner> gefechtsAngreifbareGegner(Gefechtsbegegnung s) {
  final ziele = s.gegner.values.where(gefechtsGegnerAngreifbar);
  return List.unmodifiable([
    ...ziele.where(gefechtsGegnerHandelt),
    ...ziele.where((g) => !gefechtsGegnerHandelt(g)),
  ]);
}

/// Ein Vorschlag für den Status; die App setzt ihn nie selbst.
class GefechtsgegnerStatusvorschlag {
  /// [grund] nennt den Wert und die Regelstelle in Worten.
  const GefechtsgegnerStatusvorschlag(this.status, this.grund);
  final GefechtsgegnerStatus status;
  final String grund;
}

/// Schlägt aus den verbleibenden LeP einen ernsteren Status vor.
///
/// Basis S. 139: 5 LeP oder weniger kampfunfähig (außer Zäher Hund, Eisern),
/// 0 oder weniger lebensbedrohlich, unter −KO tot. WdS S. 114: Tiere fliehen
/// meist, wenn ihre LeP auf ein Drittel gesunken sind, und sind bei 0 LeP
/// kampfunfähig und tödlich verwundet. Ohne bekannte LeP gibt es keinen
/// Vorschlag; Geflohene und Tote bleiben unberührt.
GefechtsgegnerStatusvorschlag? gefechtsGegnerStatusvorschlag(Gefechtsgegner g) {
  if (g.status == GefechtsgegnerStatus.tot ||
      g.status == GefechtsgegnerStatus.geflohen) {
    return null;
  }
  final start = g.lep;
  final lep = gefechtsGegnerstand(g).lep;
  if (start == null || lep == null) return null;
  final ko = g.ko;
  final tier = g.koerperbau == GefechtsKoerperbau.tier;
  GefechtsgegnerStatusvorschlag? vorschlag;
  if (ko != null && lep < -ko) {
    vorschlag = GefechtsgegnerStatusvorschlag(
      GefechtsgegnerStatus.tot,
      'LeP $lep liegen unter −KO.',
    );
  } else if (lep <= 0) {
    vorschlag = GefechtsgegnerStatusvorschlag(
      GefechtsgegnerStatus.kampfunfaehig,
      tier
          ? 'LeP $lep: Tiere sind kampfunfähig und tödlich verwundet.'
          : 'LeP $lep: lebensbedrohlich verletzt und bewusstlos.',
    );
  } else if (tier && lep * 3 <= start) {
    vorschlag = GefechtsgegnerStatusvorschlag(
      GefechtsgegnerStatus.geflohen,
      'Noch $lep von $start LeP: Tiere fliehen meist ab einem Drittel.',
    );
  } else if (!tier && lep <= 5) {
    vorschlag = GefechtsgegnerStatusvorschlag(
      GefechtsgegnerStatus.kampfunfaehig,
      'Noch $lep LeP: kampfunfähig, außer mit Zäher Hund oder Eisern.',
    );
  }
  if (vorschlag == null || vorschlag.status == g.status) return null;
  if (g.status == GefechtsgegnerStatus.kampfunfaehig &&
      vorschlag.status == GefechtsgegnerStatus.geflohen) {
    return null;
  }
  return vorschlag;
}

/// Setzt den bestätigten Status auf dem frischen Gegner.
Gefechtsbegegnung setzeGefechtsgegnerStatus(
  Gefechtsbegegnung s, {
  required String gegnerId,
  required GefechtsgegnerStatus status,
}) {
  final g = s.gegner[gegnerId];
  if (g == null) throw StateError('Der Gegner fehlt.');
  if (g.status == status) return s;
  return s.copyWith(
    gegner: Map.unmodifiable({
      ...s.gegner,
      gegnerId: g.copyWith(status: status),
    }),
  );
}

/// Setzt, wen der Gegner im Nahkampf bindet (`null`: niemanden).
Gefechtsbegegnung setzeGefechtsgegnerBindung(
  Gefechtsbegegnung s, {
  required String gegnerId,
  required String? teilnehmerId,
}) {
  final g = s.gegner[gegnerId];
  if (g == null) throw StateError('Der Gegner fehlt.');
  if (teilnehmerId != null && teilnehmerId.isEmpty) {
    throw ArgumentError('Teilnehmer-ID fehlt.');
  }
  if (g.bindet == teilnehmerId) return s;
  return s.copyWith(
    gegner: Map.unmodifiable({
      ...s.gegner,
      gegnerId: g.copyWith(bindet: teilnehmerId),
    }),
  );
}
