part of 'gefecht_ansicht.dart';

/// Schnellleiste, Rundenwechsel und Begleitabschnitte der Gefechtsansicht.
///
/// Ausgelagert, damit die Ansicht übersichtlich bleibt; alle Aufrufe laufen
/// weiterhin über denselben Guard `_run` und dieselben Prüfungen.
extension _GefechtAnsichtTeile on _GefechtAnsichtState {
  // Dieselbe Prüfung wie der Abschnittsknopf, ohne Dialogvorbelegung.
  Gefechtspruefung? _schnellpruefung(
    Gefechtszustand s,
    HeroComputedSnapshot snapshot,
    RulesCatalog? katalog,
    Gefechtsaktion aktion,
  ) => katalog == null
      ? null
      : pruefeGefechtAuftrag(
          s,
          snapshot,
          katalog,
          GefechtAuftrag(
            aktion: aktion,
            titel: '',
            zuschlag: 0,
            dk: s.dk,
            dauer: 1,
            kosten: 1,
          ),
        );

  // Häufigste Handlungen bleiben auf schmalen Fenstern immer erreichbar.
  Widget _schnellleiste(
    Gefechtszustand s,
    HeroComputedSnapshot snapshot,
    RulesCatalog? k,
  ) {
    VoidCallback? oeffnen(Gefechtsaktion aktion, String titel) =>
        _busy || k == null
        ? null
        : () => _run(() => _aktion(s, snapshot, k, aktion, titel));
    return GefechtSchnellleiste(
      aktionen: [
        GefechtSchnellaktion(
          titel: 'Attacke',
          symbol: Icons.sports_martial_arts,
          schluessel: 'gefecht-leiste-attacke',
          pruefung: _schnellpruefung(s, snapshot, k, Gefechtsaktion.angriff),
          onPressed: oeffnen(Gefechtsaktion.angriff, 'Angreifen'),
        ),
        GefechtSchnellaktion(
          titel: 'Parade',
          symbol: Icons.shield_outlined,
          schluessel: 'gefecht-leiste-parade',
          pruefung: _schnellpruefung(s, snapshot, k, Gefechtsaktion.parade),
          onPressed: oeffnen(Gefechtsaktion.parade, 'Parieren'),
        ),
        GefechtSchnellaktion(
          titel: 'Ausweichen',
          symbol: Icons.directions_run,
          schluessel: 'gefecht-leiste-ausweichen',
          pruefung: _schnellpruefung(
            s,
            snapshot,
            k,
            Gefechtsaktion.freiesAusweichen,
          ),
          onPressed: oeffnen(
            Gefechtsaktion.freiesAusweichen,
            'Freies Ausweichen',
          ),
        ),
        GefechtSchnellaktion(
          titel: 'Probe',
          symbol: Icons.search,
          schluessel: 'gefecht-leiste-probe',
          onPressed: _busy ? null : _probe,
        ),
        GefechtSchnellaktion(
          titel: 'Neue Runde',
          symbol: Icons.update,
          schluessel: 'gefecht-leiste-runde',
          onPressed: _busy ? null : () => _run(() async => _naechsteRunde(s)),
        ),
      ],
    );
  }

  // Talent- und Eigenschaftsproben laufen über denselben Guard wie Aktionen.
  void _probe() => _run(
    () => zeigeGefechtsTalentprobe(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      bestand: _bruecke,
    ),
  );

  // Rundenwechsel für Leiste und Rundenleiste mit denselben Sperren.
  void _naechsteRunde(Gefechtszustand s) {
    if (gefechtFolgewuerfeOffen(
      ref.read(gefechtPatzerProvider(widget.heroId)),
    )) {
      throw StateError('Offene Patzer-/Bruchfolgen zuerst abschließen.');
    }
    if (s.gemeinsameInitiative) {
      ref.read(gefechtInitiativeProvider.notifier).naechsteRunde();
    } else {
      _controller.setzen(naechsteGefechtsrunde(s));
    }
  }

  // Fachdialoge behalten die vorhandenen Schreibwege und den gemeinsamen Guard.
  Widget _vitalwerte(HeroComputedSnapshot snapshot) => GefechtVitalwerte(
    heroId: widget.heroId,
    werte: snapshot,
    child: Column(
      children: [
        KartoRessourcenleiste(
          werte: snapshot,
          onBearbeiten: (r) => _run(
            () => widget.bestand.ressourceBearbeiten(
              context: context,
              heroId: widget.heroId,
              ressource: r,
            ),
          ),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => widget.bestand.schadenErhalten(
                    context: context,
                    ref: ref,
                    heroId: widget.heroId,
                  ),
                ),
          child: const Text('Schaden erhalten'),
        ),
        widget.bestand.spielZustand(heroId: widget.heroId, werte: snapshot),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => widget.bestand.effekte(
                    context: context,
                    heroId: widget.heroId,
                  ),
                ),
          child: const Text('Effekte verwalten'),
        ),
        widget.bestand.spielEffekte(heroId: widget.heroId, werte: snapshot),
      ],
    ),
  );
  Widget _ausruestung(HeroComputedSnapshot snapshot) => KartoAbschnitt(
    titel: 'Geführte Ausrüstung',
    aktion: TextButton(
      onPressed: _busy
          ? null
          : () => _run(
              () => zeigeGefechtsausruestung(
                context: context,
                ref: ref,
                heroId: widget.heroId,
                bestand: _bruecke,
              ),
            ),
      child: const Text('Wechseln'),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(gefechtsHandbelegung(snapshot.hero.combatConfig)),
        Text(
          'RS ${snapshot.combatPreviewStats.rsTotal} · BE ${snapshot.combatPreviewStats.beKampf}',
        ),
        const Text('Waffen und Rüstungsteile im Ausrüstungspopup wechseln.'),
      ],
    ),
  );
}
