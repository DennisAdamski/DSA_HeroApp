import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_initiative_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_magie_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

/// Führt Abwarten, ausdrückliche Freigabe und Verlust einer bezahlten Reserve.
class GefechtReservekarte extends ConsumerWidget {
  /// Proben und Buchungen verwenden die vorhandene Bestandsbrücke.
  const GefechtReservekarte({
    super.key,
    required this.heroId,
    required this.bestand,
    required this.gesperrt,
    required this.onAktion,
  });
  final String heroId;

  /// Löst die Gefechtsbrücke erst beim Bedienen auf; die Anzeige braucht sie nicht.
  final KartoGefechtsAdapter Function() bestand;
  final bool gesperrt;
  final Future<void> Function(Future<void> Function()) onAktion;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gefechtMitInitiativeProvider(heroId));
    final snap = ref.watch(heroComputedProvider(heroId)).asData?.value;
    final k = ref.watch(rulesCatalogProvider).asData?.value;
    if (s == null || snap == null) return const SizedBox.shrink();
    final blockiert = gesperrt || s.auftrag != null || s.handlung != null;
    final ctl = ref.read(gefechtProvider(heroId).notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.reserveIni == null)
              TextButton(
                onPressed: blockiert
                    ? null
                    : () => onAktion(() async {
                        ctl.setzen(
                          reserviereGefechtsaktion(
                            s,
                            gefechtswerteFuer(snap, katalog: k),
                          ),
                        );
                      }),
                child: const Text('Abwarten · reguläre Aktion reservieren'),
              )
            else ...[
              Text('Verzögerte Aktion · ursprüngliche INI ${s.reserveIni}'),
              const Text(
                'Keine weitere AT/PA während Abwarten; Bewegung höchstens halbe GS. '
                'Erzwungene Abwehr verwirft die Reserve ohne Erstattung.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: blockiert
                        ? null
                        : () => ctl.setzen(s.copyWith(reserveBereit: true)),
                    child: const Text('Reserve jetzt ausführen'),
                  ),
                  TextButton(
                    onPressed: blockiert
                        ? null
                        : () => ctl.setzen(verwerfeGefechtsreserve(s)),
                    child: const Text('Reserve für Abwehr verwerfen'),
                  ),
                  TextButton(
                    onPressed: blockiert || k == null
                        ? null
                        : () => onAktion(() async {
                            final eingabe = TextEditingController();
                            final form = GlobalKey<FormState>();
                            final sp = await showDialog<int>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Schaden während Abwarten'),
                                content: Form(
                                  key: form,
                                  child: TextFormField(
                                    controller: eingabe,
                                    decoration: const InputDecoration(
                                      labelText: 'Tatsächlich erlittene SP',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      final n = int.tryParse(v ?? '');
                                      return n == null || n < 1
                                          ? 'SP mindestens 1 eingeben.'
                                          : null;
                                    },
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Abbrechen'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      if (form.currentState!.validate()) {
                                        Navigator.pop(
                                          context,
                                          int.parse(eingabe.text),
                                        );
                                      }
                                    },
                                    child: const Text(
                                      'Selbstbeherrschung prüfen',
                                    ),
                                  ),
                                ],
                              ),
                            );
                            await Future<void>.delayed(
                              const Duration(milliseconds: 300),
                            );
                            eingabe.dispose();
                            if (sp == null || !context.mounted) return;
                            final frisch = ref
                                .read(heroComputedProvider(heroId))
                                .asData
                                ?.value;
                            final aktuell = ref.read(
                              gefechtMitInitiativeProvider(heroId),
                            );
                            final talent = k.talents
                                .where((t) => t.id == 'tal_selbstbeherrschung')
                                .firstOrNull;
                            if (frisch == null ||
                                aktuell?.reserveIni == null ||
                                talent == null) {
                              return;
                            }
                            final request = gefechtsTalentprobe(frisch, talent);
                            if (request == null) {
                              throw StateError(
                                'Selbstbeherrschungsprofil fehlt.',
                              );
                            }
                            final id = UniqueKey().toString();
                            if (!ctl.reservieren(id)) return;
                            try {
                              await bestand().gefechtsProbe(
                                context: context,
                                ref: ref,
                                heroId: heroId,
                                request: gefechtsProbeMitBonus(
                                  modifiziereGefechtsWirkprobe(request, sp),
                                  aktuell!.mirakelbonus,
                                  ansageFolgemalus: aktuell.ansageFolgemalus,
                                ),
                                onResolved: (result) {
                                  final jetzt = ref.read(
                                    gefechtMitInitiativeProvider(heroId),
                                  );
                                  if (jetzt?.auftrag != id) return;
                                  ctl.abbrechen(id);
                                  var neu = jetzt!.copyWith(ohneAuftrag: true);
                                  if (!result.success) {
                                    neu = verwerfeGefechtsreserve(neu);
                                  }
                                  if (gefechtsBonusPasst(
                                    request,
                                    aktuell.mirakelbonus,
                                  )) {
                                    neu = neu.copyWith(ohneMirakelbonus: true);
                                  }
                                  ctl.setzen(neu);
                                },
                              );
                            } finally {
                              ctl.abbrechen(id);
                            }
                          }),
                    child: const Text('Schaden während Abwarten'),
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
