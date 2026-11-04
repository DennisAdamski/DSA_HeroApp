import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// So viele Würfe zeigt die Spielansicht; der Rest steht im Blatt.
///
/// Am Tisch zählen die letzten Würfe. Das ganze Protokoll (bis zu
/// `HeroState.diceLogMax` Einträge, nach Spielabenden gegliedert) schob die
/// Seite sonst um mehrere Bildschirme nach unten.
const int kProtokollKurz = 5;

/// So viele Würfe zeigt eine weite Kachel (als Tabelle).
const int kProtokollWeit = 8;

/// Kachel „Würfelprotokoll“: die letzten Würfe und der Weg zur ganzen Historie.
///
/// Eine eigene Klasse, damit sie die Größenstufe der umgebenden Kachel lesen
/// kann: in `weit` stehen [kProtokollWeit] statt [kProtokollKurz] Würfe da (der
/// Bestandsbaustein setzt sie dann als Tabelle), und der Knopf „Alle anzeigen“
/// folgt dieser Grenze.
class KartoProtokollAbschnitt extends StatelessWidget {
  /// Erstellt die Kachel für [heroId] aus dem Stand [werte].
  const KartoProtokollAbschnitt({
    super.key,
    required this.heroId,
    required this.werte,
    required this.bestand,
  });

  /// Held, dessen Protokoll das Blatt öffnet.
  final String heroId;

  /// Stand mit dem Würfelprotokoll.
  final HeroComputedSnapshot werte;

  /// Baut das Protokoll aus dem Bestand.
  final KartoBestandsAdapter bestand;

  @override
  Widget build(BuildContext context) {
    final weit =
        KartoKachelSteuerung.groesseVon(context) == KartoKachelGroesse.weit;
    final grenze = weit ? kProtokollWeit : kProtokollKurz;
    final anzahl = werte.state.diceLog.length;
    return KartoAbschnitt(
      titel: 'Würfelprotokoll',
      aktion: anzahl > grenze
          ? TextButton(
              key: const ValueKey<String>('karto-spiel-protokoll-alle'),
              onPressed: () => zeigeWuerfelprotokoll(
                context: context,
                heroId: heroId,
                bestand: bestand,
              ),
              child: Text('Alle anzeigen ($anzahl)'),
            )
          : null,
      child: bestand.spielProtokoll(werte, hoechstens: grenze),
    );
  }
}

/// Öffnet das vollständige Würfelprotokoll samt Filtern als Blatt.
///
/// Das Blatt liest `heroComputedProvider` selbst, damit ein „Nochmal würfeln“
/// darin sofort als neuer Eintrag erscheint, statt einen beim Öffnen
/// erfassten Stand zu zeigen. Es liest nur; geschrieben wird ausschließlich
/// über die Aktionen der Einträge, wie in der Spielansicht.
Future<void> zeigeWuerfelprotokoll({
  required BuildContext context,
  required String heroId,
  required KartoBestandsAdapter bestand,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (blattKontext) => DraggableScrollableSheet(
      key: const ValueKey<String>('karto-spiel-protokoll-blatt'),
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Consumer(
        builder: (context, ref, _) {
          final werte = ref.watch(heroComputedProvider(heroId)).asData?.value;
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(
              Abstand.bahn,
              0,
              Abstand.bahn,
              Abstand.bahn,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Würfelprotokoll',
                      style: Theme.of(context).textTheme.titel,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    onPressed: () => Navigator.of(blattKontext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: Abstand.weit),
              if (werte == null)
                const Center(child: CircularProgressIndicator())
              else
                bestand.spielProtokoll(werte),
            ],
          );
        },
      ),
    ),
  );
}
