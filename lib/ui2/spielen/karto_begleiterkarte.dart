import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Meldet einen Schritt oder ein Setzen für einen laufenden Wert.
typedef KartoBegleiterWert = void Function(
  HeroCompanion begleiter,
  BegleiterPool pool,
  RessourcenAenderung aenderung,
);

/// Abschnitt „Begleiter“ der Spielansicht: laufende LeP, AsP und AuP.
///
/// Darstellend: Die Karten zeigen die gespeicherten Werte aus dem einen
/// `HeroComputedSnapshot` der Ansicht (Begleiter und
/// `HeroState.begleiterZustaende`) und melden Bedienung als
/// `RessourcenAenderung`, nie als fertigen Wert. Ohne Begleiter entfällt der
/// Abschnitt. Der Abschnitt steht in der Seitenspalte hinter „Zustand“: es
/// sind Laufzeitwerte wie dort, und das Würfelprotokoll bleibt der letzte
/// Abschnitt beider Anordnungen.
class KartoBegleiterAbschnitt extends StatelessWidget {
  /// Erstellt den Abschnitt für [begleiter].
  const KartoBegleiterAbschnitt({
    super.key,
    required this.begleiter,
    required this.zustaende,
    required this.onWert,
    required this.onVertrautenAktionen,
  });

  /// Begleiter des Helden in gespeicherter Reihenfolge.
  final List<HeroCompanion> begleiter;

  /// Laufende Werte je Begleiter-ID; fehlende Einträge sind „voll“.
  final Map<String, BegleiterZustand> zustaende;

  /// Meldet die Bedienung eines Werts.
  final KartoBegleiterWert onWert;

  /// Öffnet die Vertrautenaktionen eines gebundenen Vertrauten.
  final void Function(HeroCompanion vertrauter) onVertrautenAktionen;

  @override
  Widget build(BuildContext context) {
    if (begleiter.isEmpty) return const SizedBox.shrink();
    return KartoAbschnitt(
      titel: 'Begleiter',
      stufe: KartoFlaechenstufe.senke,
      symbol: Icons.pets_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < begleiter.length; i++) ...[
            if (i > 0) const SizedBox(height: Abstand.normal),
            _Karte(
              begleiter: begleiter[i],
              zustand: zustaende[begleiter[i].id] ?? const BegleiterZustand(),
              onWert: onWert,
              onVertrautenAktionen: onVertrautenAktionen,
            ),
          ],
        ],
      ),
    );
  }
}

class _Karte extends StatelessWidget {
  const _Karte({
    required this.begleiter,
    required this.zustand,
    required this.onWert,
    required this.onVertrautenAktionen,
  });

  final HeroCompanion begleiter;
  final BegleiterZustand zustand;
  final KartoBegleiterWert onWert;
  final void Function(HeroCompanion vertrauter) onVertrautenAktionen;

  static String _typ(BegleiterTyp typ) => switch (typ) {
    BegleiterTyp.vertrauter => 'Vertrauter',
    BegleiterTyp.reittier => 'Reittier',
    BegleiterTyp.sonstigerBegleiter => 'Begleiter',
  };

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final karto = context.karto;
    final name = begleiter.name.trim().isEmpty
        ? _typ(begleiter.typ)
        : begleiter.name.trim();
    final pools = <BegleiterPool>[
      for (final pool in BegleiterPool.values)
        if (begleiterPoolMaximum(begleiter, pool) > 0) pool,
    ];
    final vertrauterGebunden =
        begleiter.typ == BegleiterTyp.vertrauter &&
        begleiter.vertrautenBindung != null;
    return KartoFlaeche(
      key: ValueKey<String>('karto-begleiter-${begleiter.id}'),
      stufe: KartoFlaechenstufe.blatt,
      innen: const EdgeInsets.all(Abstand.normal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: texte.titleSmall?.copyWith(color: karto.schrift),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _typ(begleiter.typ),
                style: texte.etikett.copyWith(color: karto.schriftLeise),
              ),
            ],
          ),
          for (final pool in pools)
            _PoolZeile(
              schluessel: 'karto-begleiter-${begleiter.id}-${pool.name}',
              pool: pool,
              aktuell: _aktuell(pool),
              maximum: begleiterPoolMaximum(begleiter, pool),
              onSchritt: (schritt) => onWert(
                begleiter,
                pool,
                begleiterPoolSchritt(
                  pool,
                  begleiterPoolMaximum(begleiter, pool),
                  schritt,
                ),
              ),
            ),
          if (pools.isEmpty)
            Text(
              'Keine Maximalwerte eingetragen.',
              style: texte.bodySmall?.copyWith(color: karto.schriftLeise),
            ),
          if (vertrauterGebunden)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: ValueKey<String>(
                  'karto-begleiter-${begleiter.id}-aktionen',
                ),
                onPressed: () => onVertrautenAktionen(begleiter),
                child: const Text('Vertrautenaktionen'),
              ),
            ),
        ],
      ),
    );
  }

  int _aktuell(BegleiterPool pool) =>
      (switch (pool) {
        BegleiterPool.lep => zustand.currentLep,
        BegleiterPool.asp => zustand.currentAsp,
        BegleiterPool.aup => zustand.currentAup,
      }) ??
      begleiterPoolMaximum(begleiter, pool);
}

class _PoolZeile extends StatelessWidget {
  const _PoolZeile({
    required this.schluessel,
    required this.pool,
    required this.aktuell,
    required this.maximum,
    required this.onSchritt,
  });

  final String schluessel;
  final BegleiterPool pool;
  final int aktuell;
  final int maximum;
  final void Function(int schritt) onSchritt;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    Widget knopf(int schritt) => InkWell(
      key: ValueKey<String>(
        '$schluessel-${schritt > 0 ? 'plus' : 'minus'}-${schritt.abs()}',
      ),
      onTap: () => onSchritt(schritt),
      borderRadius: BorderRadius.circular(kKartoRadiusKlein),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Text(
            schritt > 0 ? '+$schritt' : '−${schritt.abs()}',
            style: texte.etikett.copyWith(color: karto.schrift),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: Abstand.knapp),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              pool.kuerzel,
              style: texte.etikett.copyWith(color: karto.schriftLeise),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: texte.wert.copyWith(color: karto.schrift),
                children: <InlineSpan>[
                  TextSpan(text: '$aktuell'),
                  TextSpan(
                    text: ' / $maximum',
                    style: texte.wert.copyWith(color: karto.schriftStumm),
                  ),
                ],
              ),
              key: ValueKey<String>('$schluessel-wert'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          knopf(-5),
          knopf(-1),
          knopf(1),
          knopf(5),
        ],
      ),
    );
  }
}
