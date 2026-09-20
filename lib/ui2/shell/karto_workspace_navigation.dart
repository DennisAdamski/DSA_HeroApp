part of 'karto_workspace.dart';

enum _PlanEntscheidung { weiter, verwerfen, uebernehmen }

/// Bündelt alle Verlassenwege und serialisiert asynchrone Entscheidungen.
extension _KartoWorkspaceNavigation on _KartoWorkspaceState {
  // Eine laufende Prüfung darf weder doppelte Dialoge noch konkurrierende Saves erzeugen.
  Future<void> _geschuetzt(Future<void> Function() aktion) async {
    if (_navigiert) return;
    _navigiert = true;
    try {
      await aktion();
    } catch (error) {
      _zeigeFehler(error);
    } finally {
      _navigiert = false;
    }
  }

  // Editor und Plan bleiben getrennt: ein Moduswechsel beendet keine Sitzung.
  Future<void> _wechsleBereich(KartoArbeitsbereich ziel) =>
      _geschuetzt(() async {
        if (ziel == _bereich) return;
        if (!await _pruefeEditor() || !mounted) return;
        _setBereich(ziel);
      });

  // Die Registrierung bleibt auch dann gültig, wenn die Verwaltung offstage ist.
  Future<bool> _pruefeEditor() async =>
      await _verwaltungVerlassen?.call() ?? true;

  Future<void> _zurHeldenwahl() => _verlassen(
    () => ref.read(selectedHeroSelectionActionsProvider).clearSelection(),
  );

  // Externe Wege können Oberflächen, Konto oder Held wechseln und prüfen daher beides.
  Future<void> _verlassen(Future<void> Function() aktion) =>
      _geschuetzt(() async {
        if (!await _pruefeEditor() || !mounted) return;
        if (!await _pruefePlan() || !mounted) return;
        await aktion();
      });

  // Aufgelegte Screens bauen den Workspace nicht ab: die Sitzung liegt im
  // gemeinsamen ProviderScope und überlebt sie. Nur der Editor wird geprüft,
  // sonst müsste man für einen Blick in die Einstellungen den Plan aufgeben.
  Future<void> _aufgelegt(Future<void> Function() aktion) =>
      _geschuetzt(() async {
        if (!await _pruefeEditor() || !mounted) return;
        await aktion();
      });

  Future<void> _menueAktion(String aktion) async {
    switch (aktion) {
      case 'helden':
        await _verlassen(() => widget.bestand.heldenVerwalten(context));
      case 'einstellungen':
        await _aufgelegt(() => widget.bestand.einstellungen(context));
      case 'bestand':
        await _verlassen(
          () => ref
              .read(settingsActionsProvider)
              .setOberflaeche(Oberflaeche.codex),
        );
      case 'token':
        await _aufgelegt(
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const KartoTokenSheet()),
          ),
        );
    }
  }

  // Dialogwerte steuern nur den Sitzungscontroller, keine eigene Fachprüfung.
  Future<bool> _pruefePlan() async {
    final provider = advancementSessionProvider(widget.heroId);
    final session = ref.read(provider);
    if (session == null) return true;
    if (session.isSaving) return false;
    final entscheidung = await showDialog<_PlanEntscheidung>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entwicklung noch in Planung'),
        content: const Text(
          'Die Planung ist noch nicht übernommen. '
          'Möchtest du weiterplanen, den Entwurf verwerfen oder übernehmen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _PlanEntscheidung.weiter),
            child: const Text('Weiterplanen'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _PlanEntscheidung.verwerfen),
            child: const Text('Verwerfen'),
          ),
          FilledButton(
            onPressed: session.canCommit
                ? () => Navigator.pop(context, _PlanEntscheidung.uebernehmen)
                : null,
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    final aktuell = ref.read(provider);
    if (aktuell == null) return true;
    if (aktuell.sessionId != session.sessionId || aktuell.isSaving) {
      return false;
    }
    if (entscheidung == _PlanEntscheidung.uebernehmen) return _speicherePlan();
    if (entscheidung != _PlanEntscheidung.verwerfen) return false;
    ref.read(provider.notifier).discard();
    // Ein offener externer Screen darf beim Rebuild keine neue Sitzung starten.
    _setBereich(KartoArbeitsbereich.spielen);
    return true;
  }

  Future<void> _uebernehmePlan() => _geschuetzt(() async {
    await _speicherePlan();
  });

  // Erfolg wird erst nach abgeschlossenem Write gemeldet; Fehler erhalten den Entwurf.
  Future<bool> _speicherePlan() async {
    try {
      await ref
          .read(advancementSessionProvider(widget.heroId).notifier)
          .commit();
      if (!mounted) return false;
      _setBereich(KartoArbeitsbereich.spielen);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entwicklung übernommen.')));
      return true;
    } catch (error) {
      _zeigeFehler(error);
      return false;
    }
  }

  Future<void> _verwirfPlan() => _geschuetzt(() async {
    await _pruefePlan();
  });

  // Laufzeitaktionen verändern nur ihren bestehenden Bereich und lassen Pläne offen.
  Future<void> _laufzeitAktion(Future<void> Function() aktion) =>
      _geschuetzt(aktion);

  void _zeigeFehler(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Aktion fehlgeschlagen: $error')));
  }
}
