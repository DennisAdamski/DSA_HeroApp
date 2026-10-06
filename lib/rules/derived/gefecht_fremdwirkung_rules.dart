import 'package:dsa_heldenverwaltung/domain/gefecht_fremdwirkung.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

import 'gefecht_gegner_rules.dart';

/// Nur die belegte Grundform wird über die stabile Katalog-ID automatisiert.
bool gefechtsFremdprofilUnterstuetzt(String zauberId) =>
    zauberId == 'spell_fulminictus_donnerkeil';

/// LC 91 (MCP 1619): 2W6 + ZfP*, ohne gewöhnlichen RS und ohne Wunden.
GefechtsFremdwirkungswurf gefechtsFulminictusWurf({
  required GefechtsFremdwirkung ziel,
  required ProbeResult probe,
  required int ersterW6,
  required int zweiterW6,
}) {
  if (!gefechtsFremdprofilUnterstuetzt(ziel.zauberId) ||
      probe.request.type != ProbeType.spell ||
      !probe.success) {
    throw StateError('Nur ein erfolgreicher Fulminictus erhält diese Wirkung.');
  }
  if (ziel.gegnerId.isEmpty || ziel.verfuegbareAsp < 0) {
    throw ArgumentError(
      'Ziel und nichtnegative Startenergie sind erforderlich.',
    );
  }
  for (final w6 in [ersterW6, zweiterW6]) {
    if (w6 < 1 || w6 > 6) {
      throw ArgumentError('Schadenswürfel benötigen 1 bis 6.');
    }
  }
  final zfp = probe.remainingPool < 0 ? 0 : probe.remainingPool;
  final roh = ersterW6 + zweiterW6 + zfp;
  final schaden = roh > ziel.verfuegbareAsp ? ziel.verfuegbareAsp : roh;
  return GefechtsFremdwirkungswurf(
    ziel: ziel,
    probe: probe,
    ersterW6: ersterW6,
    zweiterW6: zweiterW6,
    schaden: schaden,
  );
}

/// LC 91 begrenzt SP auf AsP; zur Planung, niemals zum Neuwürfeln bei Retry.
int gefechtsFremdschaden(
  GefechtsFremdwirkungswurf wurf, {
  required int verfuegbareAsp,
}) {
  if (verfuegbareAsp < 0) throw ArgumentError('AsP dürfen nicht negativ sein.');
  return wurf.schaden > verfuegbareAsp ? verfuegbareAsp : wurf.schaden;
}

/// Bucht erst nach bestätigter eigener Kostenzahlung auf die ursprüngliche ID.
Gefechtsbegegnung bucheGefechtsFremdwirkung(
  Gefechtsbegegnung s, {
  required GefechtsFremdwirkungswurf wurf,
  required String buchungId,
  required int schaden,
}) {
  if (schaden != wurf.schaden) {
    throw StateError(
      'Schaden und eingefrorene AsP-Kosten müssen übereinstimmen.',
    );
  }
  return bucheGefechtsGegnerschaden(
    s,
    gegnerId: wurf.ziel.gegnerId,
    buchungId: buchungId,
    tp: schaden,
    direkt: true,
  );
}
