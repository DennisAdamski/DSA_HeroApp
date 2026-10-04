import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

import 'gefecht_ladedialog.dart';

/// Erfragt den unbekannten Anfang und prüft vor echter Ladezahlung erneut.
Future<void> zeigeGefechtsLaden({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required GefechtsKampfmittelwahl kampfmittel,
}) async {
  final s = ref.read(gefechtProvider(heroId));
  final snap = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (s == null || snap == null) return;
  final anfang = await showDialog<bool>(
    context: context,
    builder: (_) =>
        GefechtLadedialog(zustand: s, snapshot: snap, kampfmittel: kampfmittel),
  );
  if (anfang == null || !context.mounted) return;
  final aktuell = ref.read(gefechtProvider(heroId));
  final frisch = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (aktuell == null || frisch == null) return;
  ref
      .read(gefechtProvider(heroId).notifier)
      .setzen(
        beginneGefechtsLaden(
          aktuell,
          frisch,
          kampfmittel,
          anfangGeladen: anfang,
        ),
      );
}

/// Fortsetzen bleibt synchron und schreibt weder gespeicherte Ausrüstung noch Würfe.
void setzeGefechtsVorbereitungFort(WidgetRef ref, String heroId) {
  final s = ref.read(gefechtProvider(heroId));
  final snap = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (s == null || snap == null || s.handlung?.vorbereitung == null) return;
  ref
      .read(gefechtProvider(heroId).notifier)
      .setzen(bezahleGefechtsVorbereitung(s, snap));
}
