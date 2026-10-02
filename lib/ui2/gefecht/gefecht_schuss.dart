import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_fernkampf_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

/// Übernimmt die Munition eines bereits gewürfelten Schusses ohne zweite Probe.
Future<void> uebernimmGefechtsSchuss({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
}) async {
  final c = ref.read(gefechtProvider(heroId).notifier);
  final h = ref.read(gefechtProvider(heroId))?.handlung;
  if (h?.waffe == null || h?.ergebnis == null) return;
  final id = UniqueKey().toString();
  if (!c.reservieren(id)) return;
  try {
    final ok = await bestand.gefechtsAusruestung(
      context: context,
      ref: ref,
      heroId: heroId,
      aenderung: (config) => verbraucheGefechtsGeschoss(config, h!.waffe!),
    );
    if (!ok) {
      throw StateError(
        'Munition nicht übernommen. Übernahme erneut versuchen; nicht erneut würfeln.',
      );
    }
    c.abbrechen(id);
    final s = ref.read(gefechtProvider(heroId));
    if (s != null) {
      c.setzen(
        s.copyWith(
          ohneHandlung: true,
          kontext: s.kontext.copyWith(
            geladen: false,
            weitereRegelnGeprueft: false,
          ),
        ),
      );
    }
  } finally {
    c.abbrechen(id);
  }
}
