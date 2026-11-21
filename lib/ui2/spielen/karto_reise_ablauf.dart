import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_unterwegs.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisezeit_rules.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_routen_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_datum_felder.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_held_schreiben.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_reiseplaner.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_bestaetigen.dart';

/// Schreibt Reise und Standort im Laufzeitzustand (ein Dokument); verdrahtet
/// die Spielansicht über `KartoBestandsAdapter.reiseZustandSetzen`.
typedef KartoReiseZustandSetzer = Future<bool> Function({
  required HeroUnterwegs? unterwegs,
  String? standort,
});

/// Satz während einer offenen Planung.
const String kReisePlanungsSperre =
    'Während einer Planung ist die Reiseroute gesperrt.';

// Die Abläufe einer Reise. Jeder Schritt schreibt ein Dokument: zuerst den
// Bogen frisch (Stationen, Abenteuerdatum), dann den Zustand (Reise,
// Standort). Scheitert der Bogen, bleibt der Zustand unberührt.

Future<bool> _bogen(
  BuildContext context,
  WidgetRef ref,
  String heroId,
  HeroSheet Function(HeroSheet held) aenderung,
) async {
  final bote = ScaffoldMessenger.maybeOf(context);
  try {
    await aendereHeldAusserhalbPlanung(
      ref,
      heroId,
      aenderung,
      sperre: kReisePlanungsSperre,
    );
    return true;
  } catch (error) {
    bote?.showSnackBar(
      SnackBar(
        content: Text('Reise nicht gespeichert: ${schreibFehlerText(error)}'),
      ),
    );
    return false;
  }
}

/// Öffnet den Reiseplaner am Standort und führt das Ergebnis aus.
///
/// [ziel] belegt das Ziel vor (Ort der Karte).
Future<void> reisePlanen(
  BuildContext context,
  WidgetRef ref, {
  required String heroId,
  required KartoReiseZustandSetzer zustandSetzen,
  ReiseOrt? ziel,
}) async {
  final werte = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (werte == null) return;
  final ergebnis = await zeigeReiseplaner(
    context,
    held: werte.hero,
    standort: werte.state.standort,
    ziel: ziel,
  );
  if (ergebnis == null || !context.mounted) return;
  await reiseAusfuehren(
    context,
    ref,
    heroId: heroId,
    ergebnis: ergebnis,
    zustandSetzen: zustandSetzen,
  );
}

/// Führt ein Planergebnis aus: sofort ankommen oder aufbrechen.
Future<void> reiseAusfuehren(
  BuildContext context,
  WidgetRef ref, {
  required String heroId,
  required KartoReiseplanErgebnis ergebnis,
  required KartoReiseZustandSetzer zustandSetzen,
}) async {
  final uuid = const Uuid();
  final ausgangsId = uuid.v4();
  final jetzt = DateTime.now();
  if (ergebnis.aufbrechen) {
    final ok = await _bogen(
      context,
      ref,
      heroId,
      (held) => reiseMitAusgangsstation(
        held: held,
        von: ergebnis.von,
        abreise: ergebnis.anreise.abreise,
        adventureId: ergebnis.adventureId,
        id: ausgangsId,
        jetzt: jetzt,
      ),
    );
    if (!ok) return;
    await zustandSetzen(
      unterwegs: unterwegsFuer(
        von: ergebnis.von,
        nach: ergebnis.nach,
        anreise: ergebnis.anreise,
        adventureId: ergebnis.adventureId,
      ),
    );
    return;
  }
  final zielId = uuid.v4();
  final ok = await _bogen(
    context,
    ref,
    heroId,
    (held) => reiseAntreten(
      held: held,
      von: ergebnis.von,
      nach: ergebnis.nach,
      anreise: ergebnis.anreise,
      ankunft: ergebnis.ankunft,
      adventureId: ergebnis.adventureId,
      ausgangsId: ausgangsId,
      zielId: zielId,
      jetzt: jetzt,
      abenteuerDatumSetzen: ergebnis.abenteuerDatumSetzen,
    ),
  );
  if (!ok) return;
  await zustandSetzen(unterwegs: null, standort: ergebnis.nach.name);
}

/// Das heutige Datum der Kampagne (laufendes Abenteuer, sonst letzte
/// Station).
HeroAdventureDateValue reiseHeute(HeroSheet held) =>
    reiseAbreiseVorschlag(held);

/// Beendet die laufende Reise [u] mit der Ankunft am Ziel.
///
/// Fragt nach dem tatsächlichen Ankunftsdatum. Vorgabe ist heute; steht das
/// Datum der Kampagne noch am Tag der Abreise, die Planankunft.
Future<void> reiseAngekommen(
  BuildContext context,
  WidgetRef ref, {
  required String heroId,
  required HeroUnterwegs u,
  required KartoReiseZustandSetzer zustandSetzen,
}) async {
  final werte = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (werte == null) return;
  final heute = reiseHeute(werte.hero);
  final seitAbreise = reiseTageZwischenDaten(u.anreise.abreise, heute);
  final planAnkunft = unterwegsPlanAnkunft(u);
  final vorgabe =
      (seitAbreise == null || seitAbreise <= 0) && planAnkunft != null
      ? planAnkunft
      : heute;
  final eingabe = await showDialog<(HeroAdventureDateValue, bool)>(
    context: context,
    builder: (_) => _AnkunftDialog(
      ziel: u.ziel,
      vorgabe: vorgabe,
      mitAbenteuer: u.adventureId.isNotEmpty,
    ),
  );
  if (eingabe == null || !context.mounted) return;
  final (ankunft, datumSetzen) = eingabe;
  final uuid = const Uuid();
  final ausgangsId = uuid.v4();
  final zielId = uuid.v4();
  final jetzt = DateTime.now();
  final ok = await _bogen(
    context,
    ref,
    heroId,
    (held) => reiseAntreten(
      held: held,
      von: unterwegsVon(u),
      nach: unterwegsZiel(u),
      anreise: u.anreise,
      ankunft: ankunft,
      adventureId: u.adventureId,
      ausgangsId: ausgangsId,
      zielId: zielId,
      jetzt: jetzt,
      abenteuerDatumSetzen: datumSetzen,
    ),
  );
  if (!ok) return;
  await zustandSetzen(unterwegs: null, standort: u.ziel);
}

/// Hält die Reise [u] unterwegs an: Raststation an der geschätzten Lage,
/// Standort auf die Rast.
Future<void> reiseAnhalten(
  BuildContext context,
  WidgetRef ref, {
  required String heroId,
  required HeroUnterwegs u,
  required KartoReiseZustandSetzer zustandSetzen,
}) async {
  final werte = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (werte == null) return;
  final heute = reiseHeute(werte.hero);
  final anfrage = unterwegsAnfrage(u);
  final weg = anfrage == null
      ? null
      : (ref.read(avesmapsReisewegeProvider).asData?.value ??
            const <String, AvesmapsRoute>{})[anfrage.schluessel];
  final lage = unterwegsLage(
    u,
    heute: heute,
    linie: weg?.linie ?? const <(double, double)>[],
  );
  final ja = await kartoBestaetigen(
    context,
    titel: 'Unterwegs anhalten?',
    text:
        '„${reiseRastName(u)}“ wird als Station angelegt und zum Standort. '
        'Die Reise nach ${u.ziel} endet; weiter geht es mit einer neuen '
        'Planung.',
    bestaetigen: 'Anhalten',
  );
  if (!ja || !context.mounted) return;
  final uuid = const Uuid();
  final ausgangsId = uuid.v4();
  final rastId = uuid.v4();
  final jetzt = DateTime.now();
  final ok = await _bogen(
    context,
    ref,
    heroId,
    (held) => reiseUnterwegsAnhalten(
      held: held,
      u: u,
      lage: lage,
      heute: heute,
      ausgangsId: ausgangsId,
      rastId: rastId,
      jetzt: jetzt,
    ),
  );
  if (!ok) return;
  await zustandSetzen(unterwegs: null, standort: reiseRastName(u));
}

/// Bricht die Reise ab; der Held bleibt am Ausgangsort, nichts am Bogen.
Future<void> reiseAbbrechen(
  BuildContext context, {
  required HeroUnterwegs u,
  required KartoReiseZustandSetzer zustandSetzen,
}) async {
  final ja = await kartoBestaetigen(
    context,
    titel: 'Reise abbrechen?',
    text: 'Die Reise nach ${u.ziel} wird verworfen.',
    bestaetigen: 'Abbrechen',
    abbrechen: 'Weiterreisen',
  );
  if (!ja) return;
  await zustandSetzen(unterwegs: null);
}

class _AnkunftDialog extends StatefulWidget {
  const _AnkunftDialog({
    required this.ziel,
    required this.vorgabe,
    required this.mitAbenteuer,
  });

  final String ziel;
  final HeroAdventureDateValue vorgabe;
  final bool mitAbenteuer;

  @override
  State<_AnkunftDialog> createState() => _AnkunftDialogState();
}

class _AnkunftDialogState extends State<_AnkunftDialog> {
  late HeroAdventureDateValue _ankunft = widget.vorgabe;
  bool _datumSetzen = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Angekommen in ${widget.ziel}'),
      content: SizedBox(
        width: Breite.klein,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KartoDatumFelder(
              kennung: 'karto-reise-ankunft',
              initial: widget.vorgabe,
              onChanged: (d) => setState(() => _ankunft = d),
            ),
            if (widget.mitAbenteuer)
              CheckboxListTile(
                key: const ValueKey<String>('karto-reise-ankunft-datum'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _datumSetzen,
                onChanged: (v) => setState(() => _datumSetzen = v ?? false),
                title: const Text('Abenteuerdatum auf die Ankunft setzen'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-reise-ankunft-ok'),
          onPressed: _ankunft.hasContent
              ? () => Navigator.of(context).pop((_ankunft, _datumSetzen))
              : null,
          child: const Text('Ankommen'),
        ),
      ],
    );
  }
}
