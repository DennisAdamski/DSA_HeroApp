import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';

import 'companion_steigerung_rules.dart';
import 'ruestung_be_rules.dart';

/// Wirksame AT eines Begleiterangriffs (Basis + gekaufte Steigerung).
int? begleiterAngriffAt(HeroCompanionAttack a) =>
    a.at == null ? null : a.at! + a.steigerungAt;

/// Wirksame PA eines Begleiterangriffs; `null` heißt keine Parade möglich.
int? begleiterAngriffPa(HeroCompanionAttack a) =>
    a.pa == null ? null : a.pa! + a.steigerungPa;

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
  });

  /// Stabile Begleiter-ID; Namen dürfen sich wiederholen.
  final String id;
  final String name, typ;
  final int? ini, mr, lep, aup, asp;
  final int rs, be;
  final List<String> geschwindigkeiten, sonderfertigkeiten, vertrautenmagie;
  final List<BegleiterAngriffsprofil> angriffe;
}

/// Leitet das Kampfprofil eines Begleiters ab, wie es der Begleiter-Tab zeigt.
///
/// LeP/AuP/AsP sind Maximalwerte; einen laufenden Stand führt die App für
/// Begleiter nicht (Gefecht: nur ansehen).
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
      for (final g in c.geschwindigkeiten)
        g.art.trim().isEmpty ? 'GS ${g.wert}' : '${g.art} ${g.wert}',
    ],
    angriffe: [
      for (final a in c.angriffe)
        BegleiterAngriffsprofil(
          name: a.name.trim().isEmpty ? 'Angriff' : a.name,
          at: begleiterAngriffAt(a),
          pa: begleiterAngriffPa(a),
          tp: a.tp,
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
  );
}
