import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/entwicklung/karto_ap_uebersicht.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_breakpoints.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Unter dieser Höhe bliebe vom Katalog keine bedienbare Zeile übrig.
const double _kMindestKatalogHoehe = 160;

/// Ordnet Katalog, AP-Vorschau und Historie als Kartograph-Arbeitsbereich an.
///
/// Die vorhandenen Advancement-Widgets bleiben die fachlichen Eigentümer von
/// Erwerb, Varianten, Voraussetzungen, Auswirkungen und Historieneinträgen.
class KartoEntwicklungsansicht extends ConsumerWidget {
  /// Bindet den Bereich an die laufende Sitzung und die begrenzte Bestandsbrücke.
  const KartoEntwicklungsansicht({
    super.key,
    required this.heroId,
    required this.bestand,
  });

  /// Held, für den der Workspace die Sitzung bereits gestartet hat.
  final String heroId;

  /// Liefert vollständigen Katalog und vollständige Historie aus dem Bestand.
  final KartoBestandsAdapter bestand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(advancementSessionProvider(heroId));
    if (session == null) {
      return const Center(child: Text('Keine Steigerungsrunde geöffnet.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final breite = kartoBreiteFuer(constraints.maxWidth);
        final hatKontext = breite.hatDetailspalte;
        final katalog = bestand.planKatalog(heroId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wie im Katalog: der AP-Kopf behält seine natürliche Höhe, solange
            // sie passt. Bei 320 dp und Textskalierung 2 bricht der Wrap in so
            // viele Zeilen um, dass er sonst die ganze Fläche überliefe.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight.isFinite
                    ? math.max(
                        constraints.maxHeight - _kMindestKatalogHoehe,
                        0.0,
                      )
                    : double.infinity,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    breite.seitenrand,
                    Abstand.normal,
                    breite.seitenrand,
                    Abstand.block,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KartoApUebersicht(session: session),
                      if (!hatKontext) ...[
                        const SizedBox(height: Abstand.normal),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const ValueKey('karto-plan-details'),
                            onPressed: () => _zeigePlanHistorie(context),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('AP und Historie'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: hatKontext
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: katalog),
                        VerticalDivider(
                          width: Strich.hoehenlinie,
                          thickness: Strich.hoehenlinie,
                          color: context.karto.hoehenlinie,
                        ),
                        SizedBox(
                          width: breite.hatDreiSpalten ? 336 : 304,
                          // Begleitspalte auf der zurueckgesetzten Flaeche,
                          // wie die Kontextspalte der Spielansicht. Ohne
                          // Radius, weil sie ueber die volle Hoehe laeuft und
                          // eine Kachel waere.
                          child: ColoredBox(
                            color: context.karto.senke,
                            child: bestand.planHistorie(heroId),
                          ),
                        ),
                      ],
                    )
                  : katalog,
            ),
          ],
        );
      },
    );
  }

  // Das begrenzte Sheet vermeidet auf schmalen Geräten konkurrierende Spalten.
  void _zeigePlanHistorie(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: bestand.planHistorie(heroId),
      ),
    );
  }
}
