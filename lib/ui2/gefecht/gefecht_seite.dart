import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_gegner_rules.dart'
    show gefechtsAngreifbareGegner;
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ueberzahl_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_seite_provider.dart';

/// Eigene Seite der Begegnung: Helden und Gefährten der Heldengruppe mit
/// ihrer Beteiligung; externe Gefährten wählen hier ihr Ziel.
class GefechtEigeneSeite extends ConsumerWidget {
  /// [onAktion] ist der gemeinsame Guard der Gefechtsansicht.
  const GefechtEigeneSeite({
    super.key,
    required this.heroId,
    required this.gesperrt,
    required this.onAktion,
  });
  final String heroId;
  final bool gesperrt;
  final Future<void> Function(Future<void> Function()) onAktion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seite = ref.watch(gefechtsEigeneSeiteProvider(heroId));
    final ziele = gefechtsAngreifbareGegner(
      ref.watch(gefechtBegegnungProvider),
    );
    final controller = ref.read(gefechtBegegnungProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Eure Seite', style: Theme.of(context).textTheme.titleMedium),
        const Text(
          'Gefährten der Heldengruppe erscheinen automatisch. Nur Nahkämpfer '
          'zählen für die Überzahl; Helden wählen ihr Ziel im eigenen Gefecht.',
        ),
        for (final t in seite)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  [
                    t.id == heroId ? '${t.name} (du)' : t.name,
                    if (t.herkunft == GefechtsTeilnehmerherkunft.extern)
                      'Gruppe',
                    if (t.ini != null) 'INI-Basis ${t.ini}',
                  ].join(' · '),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final b in GefechtsBeteiligung.values)
                      ChoiceChip(
                        key: ValueKey('seite-${t.id}-${b.name}'),
                        label: Text(gefechtsBeteiligungLabel[b]!),
                        selected: t.beteiligung == b,
                        onSelected: gesperrt
                            ? null
                            : (_) => onAktion(
                                () async => controller.beteiligungSetzen(
                                  t.id,
                                  t.name,
                                  b,
                                ),
                              ),
                      ),
                  ],
                ),
                if (t.herkunft != GefechtsTeilnehmerherkunft.held &&
                    t.beteiligung != GefechtsBeteiligung.nichtDabei)
                  DropdownButton<String?>(
                    key: ValueKey('seite-ziel-${t.id}'),
                    isExpanded: true,
                    value: ziele.any((g) => g.id == t.zielId) ? t.zielId : null,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('kein Ziel'),
                      ),
                      for (final g in ziele)
                        DropdownMenuItem<String?>(
                          value: g.id,
                          child: Text(
                            'greift ${g.name} an',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: gesperrt
                        ? null
                        : (z) => onAktion(
                            () async => controller.mitstreiterZielSetzen(
                              t.id,
                              t.name,
                              z,
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
