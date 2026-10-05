import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_angriff_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import 'gefecht_manoeverfolge.dart';

/// Zeigt Erfolgsfolgen und würfelt nur das eingefrorene Profil dieses Angriffs.
class GefechtAngriffsergebnisAnzeige extends ConsumerWidget {
  /// Allgemeine Schadensproben verwenden dieses Ergebnis nicht.
  const GefechtAngriffsergebnisAnzeige({
    super.key,
    required this.ergebnis,
    required this.heroId,
    required this.bestand,
    required this.gesperrt,
    required this.onAktion,
  });
  final Gefechtsangriffsergebnis ergebnis;
  final String heroId;
  final KartoGefechtsAdapter bestand;
  final bool gesperrt;
  final Future<void> Function(Future<void> Function()) onAktion;

  /// Die Ergebnis-ID hält selbst doppelte Rückmeldungen beim richtigen Angriff.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = gefechtsSchadenFuerAngriff(ergebnis);
    final gegner = ref
        .watch(gefechtBegegnungProvider)
        .gegner[ergebnis.gegnerId];
    final tp = ergebnis.gewuerfelteTp;
    final besondereTp = {
      'man_hammerschlag',
      'man_todesstos',
      'man_gezielter_stich',
      'man_niederwerfen',
    }.contains(ergebnis.manoeverId);
    // Würfelabschluss und manuelle Abwicklung entfernen dieselbe konkrete ID.
    void abschliessen() {
      final s = ref.read(gefechtMitInitiativeProvider(heroId));
      if (s == null) return;
      ref
          .read(gefechtProvider(heroId).notifier)
          .setzen(entferneGefechtsAngriffsergebnis(s, ergebnis.auftragId));
    }

    final titel = ergebnis.manoevername.isEmpty
        ? 'Erfolgreicher Angriff'
        : '${ergebnis.manoevername} gelungen';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$titel · ${ergebnis.waffenname}'),
        if (ergebnis.gegnerId != null)
          Text(
            'Ziel: ${gegner?.name ?? "Ursprünglicher Gegner nicht vorhanden"}',
          ),
        Text('Gegnerische Abwehr: +${ergebnis.abwehrmalus}'),
        if (request != null)
          Text('TP-Bonus: +${ergebnis.tpBonus}')
        else if (ergebnis.tpBonus != 0)
          Text('TP-Ansage: +${ergebnis.tpBonus} · Folgen manuell festlegen'),
        Text(ergebnis.hinweis),
        if (request != null && tp == null)
          TextButton(
            key: const ValueKey('gefecht-angriffsschaden'),
            onPressed: gesperrt
                ? null
                : () => onAktion(() async {
                    await bestand.gefechtsProbe(
                      context: context,
                      ref: ref,
                      heroId: heroId,
                      request: request,
                      onResolved: (result) {
                        if (ergebnis.gegnerId == null) {
                          abschliessen();
                          return;
                        }
                        final s = ref.read(
                          gefechtMitInitiativeProvider(heroId),
                        );
                        if (s == null) return;
                        ref
                            .read(gefechtProvider(heroId).notifier)
                            .setzen(
                              friereGefechtsAngriffsschadenEin(
                                s,
                                ergebnis.auftragId,
                                result.total,
                              ),
                            );
                      },
                    );
                  }),
            child: Text('Schaden dieses Angriffs · ${request.diceSpec.label}'),
          )
        else if (request != null)
          Wrap(
            spacing: 8,
            children: [
              Text('Gewürfelt: $tp TP · RS ${gegner?.rs ?? "?"}'),
              FilledButton(
                onPressed: gesperrt || gegner == null || besondereTp
                    ? null
                    : () {
                        ref
                            .read(gefechtBegegnungProvider.notifier)
                            .schaden(
                              gegnerId: ergebnis.gegnerId!,
                              buchungId: '$heroId:${ergebnis.auftragId}',
                              tp: tp!,
                            );
                        abschliessen();
                      },
                child: const Text('Nicht abgewehrt · Treffer übernehmen'),
              ),
              if (besondereTp)
                TextButton(
                  onPressed: gesperrt || gegner == null
                      ? null
                      : () => onAktion(() async {
                          final eingabe = TextEditingController();
                          final form = GlobalKey<FormState>();
                          final sp = await showDialog<int>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Besondere Trefferfolge'),
                              content: SingleChildScrollView(
                                child: Form(
                                  key: form,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Gewürfelt: $tp TP. ${ergebnis.hinweis} '
                                        'Tatsächlichen Treffer, besonderen TP-Faktor, natürlichen RS '
                                        'und Wunden am Tisch klären. Danach die endgültigen SP eingeben.',
                                      ),
                                      TextFormField(
                                        controller: eingabe,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Bestätigte Schadenspunkte',
                                        ),
                                        validator: (v) =>
                                            (int.tryParse(v ?? '') ?? -1) < 0
                                            ? 'SP mindestens 0.'
                                            : null,
                                      ),
                                    ],
                                  ),
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
                                    'Nicht abgewehrt · SP bestätigt',
                                  ),
                                ),
                              ],
                            ),
                          );
                          await Future<void>.delayed(
                            const Duration(milliseconds: 300),
                          );
                          eingabe.dispose();
                          if (sp == null) return;
                          ref
                              .read(gefechtBegegnungProvider.notifier)
                              .schaden(
                                gegnerId: ergebnis.gegnerId!,
                                buchungId: '$heroId:${ergebnis.auftragId}',
                                tp: sp,
                                direkt: true,
                              );
                          abschliessen();
                        }),
                  child: const Text('Besondere Folgen klären · SP übernehmen'),
                ),
              TextButton(
                onPressed: gesperrt ? null : abschliessen,
                child: const Text('Abgewehrt · kein Schaden'),
              ),
            ],
          )
        else if (ergebnis.gegnerId != null &&
            {'man_entwaffnen', 'man_umreissen'}.contains(ergebnis.manoeverId))
          GefechtManoeverfolge(
            heroId: heroId,
            e: ergebnis,
            bestand: bestand,
            gesperrt: gesperrt,
            onAktion: onAktion,
          )
        else
          TextButton(
            key: const ValueKey('gefecht-angriffsfolgen-abschliessen'),
            onPressed: gesperrt ? null : abschliessen,
            child: Text(
              ergebnis.schadensfolge == GefechtsSchadensfolge.keinSchaden
                  ? 'Folgen am Tisch abgewickelt'
                  : 'Manuelle Folgen erledigt',
            ),
          ),
      ],
    );
  }
}
