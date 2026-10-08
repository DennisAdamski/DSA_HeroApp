import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_kampfprofil_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_ausbildung_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';

/// Begleiter, Tiere und Vertraute zum Nachschlagen im Gefecht.
///
/// Reine Anzeige (Nutzerentscheidung): keine Proben, kein Schreibweg. Die
/// laufenden Werte (V2) erscheinen neben den Maxima; bedient werden sie in der
/// Spielansicht. Handelnde Begleiter kommen erst mit V3. Ohne Begleiter
/// entfällt der Abschnitt vollständig.
class GefechtBegleiter extends StatelessWidget {
  /// Zeigt je Begleiter ein einklappbares Kampfprofil.
  const GefechtBegleiter({
    super.key,
    required this.begleiter,
    this.zustaende = const <String, BegleiterZustand>{},
  });

  /// Begleiter des Helden in gespeicherter Reihenfolge.
  final List<HeroCompanion> begleiter;

  /// Laufende Werte je Begleiter-ID; fehlende Einträge sind „voll“.
  final Map<String, BegleiterZustand> zustaende;

  @override
  Widget build(BuildContext context) {
    if (begleiter.isEmpty) return const SizedBox.shrink();
    return KartoAbschnitt(
      titel: 'Begleiter',
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in begleiter)
              _Profil(profil: begleiterKampfprofil(c), laufend: _laufend(c)),
          ],
        ),
      ),
    );
  }

  // „LeP 19/24 · AsP 3/10 · AuP 40/40“ nur für Werte mit Maximum.
  String _laufend(HeroCompanion c) {
    final zustand = zustaende[c.id] ?? const BegleiterZustand();
    return [
      for (final pool in BegleiterPool.values)
        if (begleiterPoolMaximum(c, pool) > 0)
          '${pool.kuerzel} ${_aktuell(zustand, pool) ?? begleiterPoolMaximum(c, pool)}/${begleiterPoolMaximum(c, pool)}',
    ].join(' · ');
  }

  static int? _aktuell(BegleiterZustand zustand, BegleiterPool pool) =>
      switch (pool) {
        BegleiterPool.lep => zustand.currentLep,
        BegleiterPool.asp => zustand.currentAsp,
        BegleiterPool.aup => zustand.currentAup,
      };
}

// Kopfzeile mit den häufigsten Werten, Details nach dem Aufklappen.
class _Profil extends StatelessWidget {
  const _Profil({required this.profil, required this.laufend});
  final BegleiterKampfprofil profil;

  /// Aktuelle Werte der Pools, leer ohne Maxima.
  final String laufend;

  @override
  Widget build(BuildContext context) {
    final p = profil;
    final kopf = [
      p.typ,
      if (p.ini != null) 'INI ${p.ini}',
      'RS ${p.rs}',
      if (p.lep != null) 'LeP ${p.lep}',
    ].join(' · ');
    return ExpansionTile(
      key: ValueKey('gefecht-begleiter-${p.id}'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(p.name),
      subtitle: Text(kopf),
      children: [
        if (laufend.isNotEmpty)
          Text(
            'Aktuell: $laufend',
            key: ValueKey('gefecht-begleiter-laufend-${p.id}'),
          ),
        for (final a in p.angriffe)
          Text(
            [
              a.name,
              if (a.at != null) 'AT ${a.at}',
              if (a.pa != null) 'PA ${a.pa}' else 'keine PA',
              if (a.tp.trim().isNotEmpty) 'TP ${a.tp}',
              if (a.dk.trim().isNotEmpty) 'DK ${a.dk}',
            ].join(' · '),
          ),
        Text(
          [
            if (p.mr != null) 'MR ${p.mr}',
            'BE ${p.be}',
            if (p.aup != null) 'AuP ${p.aup}',
            if (p.asp != null && p.asp! > 0) 'AsP ${p.asp}',
            ...p.geschwindigkeiten,
          ].join(' · '),
        ),
        if (p.reittier != null) Text(reittierProfilText(p.reittier!)),
        if (p.sonderfertigkeiten.isNotEmpty)
          Text('Sonderfertigkeiten: ${p.sonderfertigkeiten.join(', ')}'),
        if (p.vertrautenmagie.isNotEmpty)
          Text('Vertrautenmagie: ${p.vertrautenmagie.join(', ')}'),
      ],
    );
  }
}
