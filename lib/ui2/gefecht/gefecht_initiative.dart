import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';

/// Gemeinsame Phase, Teilnehmer und ausdrücklich bestätigte Gegnerzeitpunkte.
class GefechtInitiativkarte extends ConsumerWidget {
  /// Der aktuelle Held tritt nur durch ausdrückliche Auswahl bei.
  const GefechtInitiativkarte({
    super.key,
    required this.heroId,
    required this.gesperrt,
  });
  final String heroId;
  final bool gesperrt;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gruppe = ref.watch(gefechtInitiativeProvider);
    final offen = ref.watch(gefechtsZeitpunkteProvider);
    final datenSperre = ref.watch(gefechtInitiativSperreProvider);
    final c = ref.read(gefechtInitiativeProvider.notifier);
    final phase = gruppe.phase ?? offen.firstOrNull?.ini;
    final dabei = gruppe.helden.contains(heroId);
    Future<void> ausfuehren(VoidCallback aktion) async {
      try {
        aktion();
      } catch (fehler) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$fehler')));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Gemeinsame Initiative · Runde ${gruppe.runde}'),
            if (!dabei)
              TextButton(
                onPressed: gesperrt
                    ? null
                    : () async {
                        final vorbei = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Held zur Initiative hinzufügen'),
                            content: const Text(
                              'Ist der eigene Zeitpunkt in dieser Runde bereits verstrichen?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Bereits verstrichen'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Noch offen'),
                              ),
                            ],
                          ),
                        );
                        if (vorbei != null) {
                          await ausfuehren(
                            () =>
                                c.hinzufuegen(heroId, zeitpunktVorbei: vorbei),
                          );
                        }
                      },
                child: const Text('+ Held'),
              ),
            if (dabei) ...[
              if (datenSperre != null) Text(datenSperre),
              Text(
                phase == null
                    ? 'Keine offene Phase'
                    : 'Aktuelle Phase: INI $phase',
              ),
              const Text(
                'Gleiche reguläre Zeitpunkte am Tisch ordnen. '
                'Umgewandelte Aktionen folgen danach. Abwehr bleibt reaktiv.',
              ),
              for (final z in offen)
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${z.name} · INI ${z.ini}${z.umgewandelt ? " · umgewandelt" : ""}',
                    ),
                    if (z.ini == phase)
                      TextButton(
                        onPressed: gesperrt
                            ? null
                            : () => ausfuehren(() => c.abschliessen(z.id)),
                        child: const Text('Zeitpunkt abgewickelt'),
                      ),
                    if (z.ini != phase)
                      TextButton(
                        onPressed: gesperrt
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Zeitpunkt klären'),
                                    content: Text(
                                      'Offenen Zeitpunkt von ${z.name} bei INI ${z.ini} '
                                      'jetzt abwickeln? Keine bereits gebuchten Aktionen werden zurückgenommen.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Abbrechen'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Am Tisch bestätigt'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await ausfuehren(() => c.phaseSetzen(z.ini));
                                }
                              },
                        child: const Text('Zeitpunkt klären'),
                      ),
                  ],
                ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: gesperrt
                        ? null
                        : () => ausfuehren(c.naechsteRunde),
                    child: const Text('Gemeinsame nächste Runde'),
                  ),
                  TextButton(
                    onPressed: gesperrt
                        ? null
                        : () => ausfuehren(() => c.entfernen(heroId)),
                    child: const Text('Gruppe verlassen'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
