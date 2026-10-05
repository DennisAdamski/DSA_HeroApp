import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_kampfprofil_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';

/// Begleiter, Tiere und Vertraute zum Nachschlagen im Gefecht.
///
/// Reine Anzeige (Nutzerentscheidung): keine Proben, keine LeP-Zählung, kein
/// Schreibweg. Ohne Begleiter entfällt der Abschnitt vollständig.
class GefechtBegleiter extends StatelessWidget {
  /// Zeigt je Begleiter ein einklappbares Kampfprofil.
  const GefechtBegleiter({super.key, required this.begleiter});

  /// Begleiter des Helden in gespeicherter Reihenfolge.
  final List<HeroCompanion> begleiter;

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
            for (final c in begleiter) _Profil(profil: begleiterKampfprofil(c)),
          ],
        ),
      ),
    );
  }
}

// Kopfzeile mit den häufigsten Werten, Details nach dem Aufklappen.
class _Profil extends StatelessWidget {
  const _Profil({required this.profil});
  final BegleiterKampfprofil profil;

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
        if (p.sonderfertigkeiten.isNotEmpty)
          Text('Sonderfertigkeiten: ${p.sonderfertigkeiten.join(', ')}'),
        if (p.vertrautenmagie.isNotEmpty)
          Text('Vertrautenmagie: ${p.vertrautenmagie.join(', ')}'),
      ],
    );
  }
}
