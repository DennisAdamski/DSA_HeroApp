import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vertrauten_spiel_rules.dart';

/// Vertraute, die in der Rast der Hexe regenerieren können.
///
/// Ein Vertrauter mit Lebens- oder Astralenergie nimmt standardmäßig teil
/// (kein Körperkontakt). Das Maximum kommt aus dem gespeicherten Bogen.
List<HeroCompanion> restVertraute(Iterable<HeroCompanion> begleiter) => [
  for (final c in begleiter)
    if (c.typ == BegleiterTyp.vertrauter &&
        (begleiterPoolMaximum(c, BegleiterPool.lep) > 0 ||
            begleiterPoolMaximum(c, BegleiterPool.asp) > 0))
      c,
];

/// Baut die Rastangaben aus der Auswahl [wahl]: kein Eintrag heißt Standard
/// (regeneriert ohne Körperkontakt), ein `null`-Eintrag heißt abgewählt.
List<VertrautenRast> restVertrautenAngaben(
  Iterable<HeroCompanion> vertraute,
  Map<String, VertrautenRast?> wahl,
) => [
  for (final c in vertraute)
    if (wahl.containsKey(c.id))
      ?wahl[c.id]
    else
      VertrautenRast(begleiterId: c.id),
];

/// Abschnitt „Vertraute“ im Rastdialog (WdZ S. 125): je Vertrautem
/// Teilnahme, Körperkontakt und der zusätzliche Punkt.
class RestVertrauteSection extends StatelessWidget {
  /// Erstellt den Abschnitt.
  const RestVertrauteSection({
    super.key,
    required this.vertraute,
    required this.wahl,
    required this.phasen,
    required this.onChanged,
  });

  /// Teilnehmende Vertraute, siehe [restVertraute].
  final List<HeroCompanion> vertraute;

  /// Auswahl je ID, siehe [restVertrautenAngaben].
  final Map<String, VertrautenRast?> wahl;

  /// Anzahl der Regenerationsphasen der gewählten Rast.
  final int phasen;

  /// Meldet den neuen Eintrag für [id]; `null` wählt den Vertrauten ab.
  final void Function(String id, VertrautenRast? neu) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey<String>('rest-vertraute'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vertraute', style: theme.textTheme.titleSmall),
        Text(
          'Jede Regenerationsphase bringt ein aufgerundetes Zehntel der '
          'Maxima; bei Körperkontakt mit der Hexe zusätzlich 1 LeP oder 1 AsP '
          '($phasen ${phasen == 1 ? 'Phase' : 'Phasen'}).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        for (final c in vertraute) _zeile(context, c),
      ],
    );
  }

  Widget _zeile(BuildContext context, HeroCompanion c) {
    final aktuell = wahl.containsKey(c.id)
        ? wahl[c.id]
        : VertrautenRast(begleiterId: c.id);
    final name = c.name.trim().isEmpty ? 'Vertrauter' : c.name.trim();
    final zuwachs = vertrautenRegeneration(c, phasen: phasen);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          key: ValueKey<String>('rest-vertrauter-${c.id}'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: aktuell != null,
          title: Text('$name regeneriert'),
          subtitle: Text('+${zuwachs.lep} LeP · +${zuwachs.asp} AsP'),
          onChanged: (v) => onChanged(
            c.id,
            v == true ? VertrautenRast(begleiterId: c.id) : null,
          ),
        ),
        if (aktuell != null)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  key: ValueKey<String>('rest-vertrauter-kontakt-${c.id}'),
                  label: const Text('Körperkontakt'),
                  selected: aktuell.koerperkontakt,
                  onSelected: (v) => onChanged(
                    c.id,
                    VertrautenRast(
                      begleiterId: c.id,
                      koerperkontakt: v,
                      wahl: aktuell.wahl,
                    ),
                  ),
                ),
                if (aktuell.koerperkontakt)
                  SegmentedButton<KontaktBonus>(
                    key: ValueKey<String>('rest-vertrauter-bonus-${c.id}'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: KontaktBonus.lep,
                        label: Text('+1 LeP'),
                      ),
                      ButtonSegment(
                        value: KontaktBonus.asp,
                        label: Text('+1 AsP'),
                      ),
                    ],
                    selected: {aktuell.wahl},
                    onSelectionChanged: (s) => onChanged(
                      c.id,
                      VertrautenRast(
                        begleiterId: c.id,
                        koerperkontakt: true,
                        wahl: s.first,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
