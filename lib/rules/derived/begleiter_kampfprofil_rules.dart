import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';

import 'begleiter_wirkwert_rules.dart';
import 'companion_steigerung_rules.dart';
import 'reittier_ausbildung_rules.dart';
import 'ruestung_be_rules.dart';

export 'companion_steigerung_rules.dart'
    show begleiterAngriffAt, begleiterAngriffPa;

/// Ein Angriffsmodus des Begleiters mit wirksamen Werten.
class BegleiterAngriffsprofil {
  /// Hält Name, wirksame AT/PA, TP und Distanzklasse.
  const BegleiterAngriffsprofil({
    required this.name,
    required this.at,
    required this.pa,
    required this.tp,
    required this.dk,
  });
  final String name, tp, dk;
  final int? at, pa;
}

/// Ausbildungsstand eines Reittiers, wie das Gefecht ihn zeigt.
class ReittierProfil {
  /// Hält Stufe, Art, Variante und die Reiten-Modifikatoren.
  const ReittierProfil({
    required this.stufe,
    required this.art,
    required this.variante,
    required this.kampfpferd,
    required this.reitenNormal,
    required this.reitenImKampf,
    required this.reiterKampfErschwernis,
  });

  /// Anzeigename der aktuellen Stufe.
  final String stufe;

  /// Anzeigename der aktuellen Ausbildungsart.
  final String art;

  /// Name der Ausbildungsvariante; leer ohne Variante.
  final String variante;

  /// Gilt als geschultes Kampfpferd.
  final bool kampfpferd;

  /// Modifikator der Reiten-Probe außerhalb des Kampfes (positiv erschwert).
  final int reitenNormal;

  /// Modifikator der Reiten-Probe im Kampf (positiv erschwert).
  final int reitenImKampf;

  /// Zusatzerschwernis der Kampfhandlungen des Reiters.
  final int reiterKampfErschwernis;
}

/// Kampfrelevante Werte eines Begleiters zum Nachschlagen im Gefecht.
class BegleiterKampfprofil {
  /// Alle Werte sind bereits mit Steigerungen und Rüstung verrechnet.
  const BegleiterKampfprofil({
    required this.id,
    required this.name,
    required this.typ,
    required this.ini,
    required this.mr,
    required this.rs,
    required this.be,
    required this.lep,
    required this.aup,
    required this.asp,
    required this.geschwindigkeiten,
    required this.angriffe,
    required this.sonderfertigkeiten,
    required this.vertrautenmagie,
    this.reittier,
  });

  /// Stabile Begleiter-ID; Namen dürfen sich wiederholen.
  final String id;
  final String name, typ;
  final int? ini, mr, lep, aup, asp;
  final int rs, be;
  final List<String> geschwindigkeiten, sonderfertigkeiten, vertrautenmagie;
  final List<BegleiterAngriffsprofil> angriffe;

  /// Ausbildungsstand, falls der Begleiter ein Reittier mit Ausbildung ist.
  final ReittierProfil? reittier;
}

/// Leitet das Kampfprofil eines Begleiters ab, wie es der Begleiter-Tab zeigt.
///
/// LeP/AuP/AsP sind Maximalwerte; einen laufenden Stand führt die App für
/// Begleiter nicht (Gefecht: nur ansehen). INI, Angriffe und
/// Geschwindigkeiten enthalten bei Reittieren die Ausbildung.
BegleiterKampfprofil begleiterKampfprofil(HeroCompanion c) {
  final ruestung = c.ruestungsTeile.where((p) => p.isActive).toList();
  final be = computeBeKampf(
    computeBeTotalRaw(ruestung),
    computeRgReduction(
      globalArmorTrainingLevel: c.ruestungsgewoehnung,
      activePieces: ruestung,
    ),
  );
  return BegleiterKampfprofil(
    id: c.id,
    name: c.name.trim().isEmpty ? 'Unbenannter Begleiter' : c.name,
    typ: c.typ.label,
    ini: companionEffektivwert(c, 'ini'),
    mr: companionEffektiverPoolwert(c, 'mr'),
    rs: computeRsTotal(ruestung),
    be: be,
    lep: companionEffektiverPoolwert(c, 'lep'),
    aup: companionEffektiverPoolwert(c, 'aup'),
    asp: companionEffektiverPoolwert(c, 'asp'),
    geschwindigkeiten: [
      for (final g in begleiterWirksameGeschwindigkeiten(c))
        g.art.trim().isEmpty ? 'GS ${g.wert}' : '${g.art} ${g.wert}',
    ],
    angriffe: [
      for (final a in c.angriffe)
        BegleiterAngriffsprofil(
          name: a.name.trim().isEmpty ? 'Angriff' : a.name,
          at: begleiterWirksamerAngriffAt(c, a),
          pa: begleiterAngriffPa(a),
          tp: begleiterWirksamerAngriffTp(c, a),
          dk: a.dk,
        ),
    ],
    sonderfertigkeiten: [
      for (final s in c.sonderfertigkeiten)
        if (s.name.trim().isNotEmpty) s.name,
    ],
    vertrautenmagie: [
      for (final k in c.ritualCategories)
        for (final r in k.rituals)
          if (r.name.trim().isNotEmpty) r.name,
    ],
    reittier: _reittierProfil(c),
  );
}

// Profil der Ausbildung; `null` ohne erfasste Reittier-Ausbildung.
ReittierProfil? _reittierProfil(HeroCompanion c) {
  final a = c.reittierAusbildung;
  if (!istReittierMitAusbildung(c) || a == null) {
    return null;
  }
  final imKampf = reitenProbenModifikator(c, imKampf: true);
  return ReittierProfil(
    stufe: aktuelleStufe(a).label,
    art: aktuelleArt(a).label,
    variante: gewaehlteVariante(a)?.name ?? '',
    kampfpferd: istGeschultesKampfpferd(a),
    reitenNormal: reitenProbenModifikator(c, imKampf: false).erschwernis,
    reitenImKampf: imKampf.erschwernis,
    reiterKampfErschwernis: imKampf.reiterKampfErschwernis,
  );
}
