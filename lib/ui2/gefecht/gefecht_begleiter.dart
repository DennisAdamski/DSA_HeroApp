import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_gefecht_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_kampfprofil_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_ausbildung_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_herleitung_schritte.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';

/// Begleiter, Tiere und Vertraute zum Nachschlagen im Gefecht.
///
/// Die laufenden Werte (V2) erscheinen neben den Maxima; bedient werden sie in
/// der Spielansicht. Mit [onProbe] (V3a) hat jeder Angriff Würfelhilfen für
/// AT, PA und TP aus dem Kampfprofil. Das sind nur Würfel: Der Begleiter hat
/// keine Aktionen pro Runde, keine Initiative und keine Buchung am Gegner,
/// Treffer und Schaden überträgt der Spieler selbst; ein Schreibweg entsteht
/// nicht. Ohne Begleiter entfällt der Abschnitt vollständig.
class GefechtBegleiter extends StatelessWidget {
  /// Zeigt je Begleiter ein einklappbares Kampfprofil.
  const GefechtBegleiter({
    super.key,
    required this.begleiter,
    this.zustaende = const <String, BegleiterZustand>{},
    this.onProbe,
    this.gesperrt = false,
  });

  /// Begleiter des Helden in gespeicherter Reihenfolge.
  final List<HeroCompanion> begleiter;

  /// Laufende Werte je Begleiter-ID; fehlende Einträge sind „voll“.
  final Map<String, BegleiterZustand> zustaende;

  /// Würfelt eine Probe des Begleiters (Dialog und Protokoll liegen bei der
  /// Brücke); ohne Rückruf entfallen die Würfelknöpfe.
  final Future<void> Function(ResolvedProbeRequest request)? onProbe;

  /// Sperrt die Würfelknöpfe, solange ein anderer Gefechtsschritt läuft.
  final bool gesperrt;

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
              _Profil(
                profil: begleiterKampfprofil(c),
                herleitung: begleiterHerleitungen(c),
                laufend: _laufend(c),
                onProbe: onProbe,
                gesperrt: gesperrt,
              ),
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
  const _Profil({
    required this.profil,
    required this.herleitung,
    required this.laufend,
    required this.onProbe,
    required this.gesperrt,
  });
  final BegleiterKampfprofil profil;

  /// Würfelt eine Probe; `null` ohne Würfelknöpfe.
  final Future<void> Function(ResolvedProbeRequest request)? onProbe;

  /// Ob die Würfelknöpfe gesperrt sind.
  final bool gesperrt;

  /// Herleitungen der Werte, die das Profil zeigt.
  final BegleiterHerleitungen herleitung;

  /// Aktuelle Werte der Pools, leer ohne Maxima.
  final String laufend;

  // INI, die Pools und je Angriff AT und PA, soweit sie Schritte haben.
  Iterable<Herleitung> get _herleitungen sync* {
    for (final h in [
      herleitung.werte['ini'],
      for (final (_, key) in kBegleiterPools) herleitung.pools[key],
    ]) {
      if (h != null && h.sichtbareSchritte.length > 1) yield h;
    }
    for (final a in herleitung.angriffe) {
      for (final (art, h) in [('AT', a.at), ('PA', a.pa)]) {
        if (h != null) {
          yield Herleitung(bezeichnung: '$art ${a.name}', schritte: h.schritte);
        }
      }
    }
  }

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
        for (final (i, a) in p.angriffe.indexed) ...[
          Text(
            [
              a.name,
              if (a.at != null) 'AT ${a.at}',
              if (a.pa != null) 'PA ${a.pa}' else 'keine PA',
              if (a.tp.trim().isNotEmpty) 'TP ${a.tp}',
              if (a.dk.trim().isNotEmpty) 'DK ${a.dk}',
            ].join(' · '),
          ),
          if (onProbe != null)
            Wrap(
              spacing: 8,
              children: [
                for (final (art, request) in [
                  ('at', begleiterAngriffProbe(p, a)),
                  ('pa', begleiterParadeProbe(p, a)),
                  ('tp', begleiterSchadenProbe(p, a)),
                ])
                  if (request != null)
                    TextButton(
                      key: ValueKey('gefecht-begleiter-${p.id}-$i-$art'),
                      onPressed: gesperrt ? null : () => onProbe!(request),
                      child: Text('${art.toUpperCase()} würfeln'),
                    ),
              ],
            ),
          if (onProbe != null &&
              a.tp.trim().isNotEmpty &&
              begleiterSchadenProbe(p, a) == null)
            Text(
              'TP „${a.tp.trim()}“ lässt sich nicht als Würfel lesen: am Tisch '
              'würfeln.',
              key: ValueKey('gefecht-begleiter-${p.id}-$i-tp-hinweis'),
            ),
        ],
        if (p.angriffeMagisch)
          Text(
            kBegleiterMagischHinweis,
            key: ValueKey('gefecht-begleiter-${p.id}-magisch'),
          ),
        if (p.kampfregeln.isNotEmpty)
          Text(
            'Kampfregeln (WdZ S. 124): ${p.kampfregeln.join(' · ')}',
            key: ValueKey('gefecht-begleiter-${p.id}-kampfregeln'),
          ),
        if (begleiterAurapanzerText(p) case final panzer?)
          Text(panzer, key: ValueKey('gefecht-begleiter-${p.id}-aurapanzer')),
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
        ExpansionTile(
          key: ValueKey('gefecht-begleiter-berechnung-${p.id}'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: const Text('Berechnung'),
          children: [
            for (final h in _herleitungen)
              GefechtHerleitungSchritte(herleitung: h),
          ],
        ),
      ],
    );
  }
}
