import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_breakpoints.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ressourcenleiste.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielaktionen.dart';

/// Führt eine Laufzeitaktion aus und meldet Fehler sichtbar.
///
/// Der Workspace reicht seinen vorhandenen Re-Entrancy-Guard herein, damit ein
/// Doppelklick keine zwei Dialoge öffnet und die Spielansicht keinen zweiten
/// Fehlerweg aufmacht.
typedef KartoLaufzeitAktion = Future<void> Function(
  Future<void> Function() aktion,
);

/// Spielansicht: Ressourcen, Schnellaktionen, Kampf, Effekte und Protokoll.
///
/// Liest `heroComputedProvider(heroId)` **einmal** und reicht den Snapshot an
/// die darstellenden Abschnitte weiter; dessen vier Ableitungen werden nicht
/// zusätzlich beobachtet. Gezeigt werden ausschließlich gespeicherte Werte,
/// nie der Entwurf einer offenen Steigerungssitzung.
class KartoSpielansicht extends ConsumerWidget {
  /// Bindet die Ansicht an einen Helden und die Bestandsbrücke.
  const KartoSpielansicht({
    super.key,
    required this.heroId,
    required this.bestand,
    required this.aktion,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Übergangsbrücke zu den vorhandenen Fachansichten und Dialogen.
  final KartoBestandsAdapter bestand;

  /// Geschützter Ausführungsweg für Dialoge und Bestandsaktionen.
  final KartoLaufzeitAktion aktion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final berechnet = ref.watch(heroComputedProvider(heroId));
    if (berechnet.hasError) {
      return _meldung(
        context,
        'Spielwerte konnten nicht geladen werden: ${berechnet.error}',
        wiederholen: () => ref.invalidate(heroStateProvider(heroId)),
      );
    }
    final werte = berechnet.asData?.value;
    if (werte == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final breite = kartoBreiteFuer(constraints.maxWidth);
        final haupt = _hauptabschnitte(context, ref, werte);
        final seite = _seitenabschnitte(context, ref, werte);
        final rand = EdgeInsets.all(breite.seitenrand);

        // Ohne Seiteninhalt gäbe eine zweite Spalte nur leere Fläche.
        if (!breite.hatDetailspalte || seite.isEmpty) {
          return SingleChildScrollView(
            padding: rand,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _mitLuecken([...haupt, ...seite]),
            ),
          );
        }
        return SingleChildScrollView(
          padding: rand,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _mitLuecken(haupt),
                ),
              ),
              const SizedBox(width: Abstand.bahn),
              SizedBox(
                width: breite.hatDreiSpalten ? 320 : 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _mitLuecken(seite),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Reihenfolge laut Spezifikation: Ressourcen zuerst, dann Aktionen.
  List<Widget> _hauptabschnitte(
    BuildContext context,
    WidgetRef ref,
    HeroComputedSnapshot werte,
  ) {
    return <Widget>[
      KartoAbschnitt(
        titel: 'Ressourcen',
        hinweis: 'Gespeicherte Werte dieses Helden',
        child: KartoRessourcenleiste(
          werte: werte,
          onBearbeiten: (ressource) => aktion(
            () => bestand.ressourceBearbeiten(
              context: context,
              heroId: heroId,
              ressource: ressource,
            ),
          ),
        ),
      ),
      KartoAbschnitt(
        titel: 'Schnellaktionen',
        hinweis: 'Würfeln und Rasten über die bestehenden Wege',
        child: KartoSpielaktionen(
          kuerzelHinweis: 'Strg K',
          onProbeSuchen: () => aktion(
            () =>
                bestand.probeSuchen(context: context, ref: ref, heroId: heroId),
          ),
          onRast: () =>
              aktion(() => bestand.rast(context: context, heroId: heroId)),
        ),
      ),
      KartoAbschnitt(
        titel: 'Eigenschaften',
        hinweis: 'Ein Tippen würfelt die Probe',
        child: bestand.spielEigenschaftsproben(heroId: heroId, werte: werte),
      ),
    ];
  }

  // Auf breiten Fenstern steht diese Spalte neben den Spielaktionen; auf
  // schmalen folgt sie ihnen in derselben Reihenfolge.
  List<Widget> _seitenabschnitte(
    BuildContext context,
    WidgetRef ref,
    HeroComputedSnapshot werte,
  ) {
    return <Widget>[
      KartoAbschnitt(
        titel: 'Kampf',
        hinweis: 'Schnellproben aus der vorhandenen Vorschau',
        child: bestand.spielKampfproben(heroId: heroId, werte: werte),
      ),
      KartoAbschnitt(
        titel: 'Zustand',
        hinweis: 'Belastung, Wunden und Statuswerte',
        child: bestand.spielZustand(heroId: heroId, werte: werte),
      ),
    ];
  }

  // Abschnitte bekommen einen gleichmäßigen Abstand statt eigener Ränder.
  List<Widget> _mitLuecken(List<Widget> abschnitte) {
    final ergebnis = <Widget>[];
    for (var i = 0; i < abschnitte.length; i++) {
      if (i > 0) ergebnis.add(const SizedBox(height: Abstand.bahn));
      ergebnis.add(abschnitte[i]);
    }
    return ergebnis;
  }

  // Fehlertexte bleiben auch bei großer Schrift erreichbar.
  Widget _meldung(
    BuildContext context,
    String text, {
    required VoidCallback wiederholen,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Abstand.bahn),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          TextButton(onPressed: wiederholen, child: const Text('Wiederholen')),
        ],
      ),
    ),
  );
}
