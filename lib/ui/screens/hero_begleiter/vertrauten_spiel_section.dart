part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Vertrautenaktionen am Spieltisch (WdZ S. 124–128) – V2
// ---------------------------------------------------------------------------

/// Vereinigung, versäumtes Treffen, Loyalität, Vertrautenzauber und
/// Tierproben eines gebundenen Vertrauten.
///
/// Liest immer den gespeicherten Bogen und Zustand. LO-Buchungen schreiben den
/// Bogen und ruhen deshalb ([sofort] `false`), solange der Tab ungespeicherte
/// Änderungen hält oder eine Planung offen ist; alles andere schreibt nur den
/// Laufzeitzustand.
class _VertrautenSpielSection extends ConsumerStatefulWidget {
  const _VertrautenSpielSection({
    required this.heroId,
    required this.companionId,
    required this.sofort,
  });

  final String heroId;
  final String companionId;
  final bool sofort;

  @override
  ConsumerState<_VertrautenSpielSection> createState() =>
      _VertrautenSpielSectionState();
}

class _VertrautenSpielSectionState
    extends ConsumerState<_VertrautenSpielSection> {
  HeroCompanion? get _vertrauter => ref
      .read(heroByIdProvider(widget.heroId))
      ?.companions
      .where((c) => c.id == widget.companionId)
      .firstOrNull;

  HeroState get _zustand =>
      ref.read(heroStateProvider(widget.heroId)).valueOrNull ??
      const HeroState.empty();

  String _name(HeroCompanion c) =>
      c.name.trim().isEmpty ? 'Vertrauter' : c.name.trim();

  // Letzte Meldung; steht zusätzlich im Abschnitt, weil eine Snackbar hinter
  // einem Dialog läge (Aufruf aus der Spielansicht).
  String? _letzteMeldung;

  void _melde(String text) {
    if (!mounted) return;
    setState(() => _letzteMeldung = text);
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  // ---- Vereinigung -------------------------------------------------------

  Future<void> _vereinige() async {
    final c = _vertrauter;
    if (c == null) return;
    final zustand = _zustand;
    final wurf = await showAdaptiveInputDialog<(int, int)>(
      context: context,
      builder: (_) => _VereinigungsDialog(
        name: _name(c),
        aspHexe: zustand.currentAsp,
        aspVertrauter: begleiterAktuellerPool(c, zustand, BegleiterPool.asp),
      ),
    );
    if (wurf == null || !mounted) return;
    try {
      final e = await ref
          .read(vertrautenVereinigungProvider)
          .vereinige(
            heroId: widget.heroId,
            begleiterId: c.id,
            wurfHexe: wurf.$1,
            wurfVertrauter: wurf.$2,
          );
      _melde(
        'Vereinigung: Hexe −${e.verlustHexe} AsP, '
        '${_name(c)} −${e.verlustVertrauter} AsP',
      );
    } catch (fehler) {
      _melde('Vereinigung nicht gespeichert: ${_fehlertext(fehler)}');
    }
  }

  // ---- Versäumtes Treffen -----------------------------------------------

  Future<void> _treffenVersaeumt() async {
    final c = _vertrauter;
    if (c == null) return;
    final lo = c.loyalitaet ?? 0;
    final wahl = await showAdaptiveInputDialog<(bool, bool)>(
      context: context,
      builder: (_) => _TreffenVersaeumtDialog(loyalitaet: lo),
    );
    if (wahl == null || !mounted) return;
    var lepGebucht = false;
    if (wahl.$1) {
      final z = await aendereZustandMitMeldung(
        context: context,
        ref: ref,
        heroId: widget.heroId,
        was: 'LeP',
        aenderung: (aktuell) => mitVersaeumtemTreffenLep(aktuell, c),
      );
      if (z == null || !mounted) return;
      lepGebucht = true;
    }
    if (wahl.$2) {
      final gespeichert = await aendereHeldMitMeldung(
        context: context,
        ref: ref,
        heroId: widget.heroId,
        was: 'Loyalität',
        aenderung: (held) => mitVersaeumtemTreffenLo(
          held,
          begleiterId: c.id,
          erwarteteLoyalitaet: lo,
        ),
      );
      if (gespeichert == null) {
        _melde(
          lepGebucht
              ? '−1 LeP ist gebucht, −1 LO fehlt noch: „Treffen versäumt“ '
                    'erneut öffnen und nur LO wählen.'
              : '−1 LO nicht gebucht.',
        );
        return;
      }
    }
    _melde('Treffen als versäumt gebucht.');
  }

  // ---- CH-Probe für LO +1 ---------------------------------------------

  Future<void> _loyalitaetProbe() async {
    final c = _vertrauter;
    final snapshot = ref.read(heroComputedProvider(widget.heroId)).valueOrNull;
    if (c == null || snapshot == null) {
      _melde('Heldenwerte werden noch geladen.');
      return;
    }
    bool? erfolg;
    await showLoggedProbeDialog(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      request: vertrautenChProbe(snapshot.probenEigenschaften),
      onResolved: (ergebnis) => erfolg = ergebnis.success,
    );
    if (erfolg != true || !mounted) return;
    final lo = c.loyalitaet ?? 0;
    final ja = await showAdaptiveInputDialog<bool>(
      context: context,
      builder: (_) => _VertrautenBestaetigenDialog(
        titel: 'Loyalität erhöhen',
        text:
            'Die CH-Probe ist gelungen: Die Loyalität von ${_name(c)} steigt '
            'von $lo auf ${lo + 1} (höchstens $kVertrautenMaxLoyalitaet).',
        aktion: 'LO +1 buchen',
      ),
    );
    if (ja != true || !mounted) return;
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Loyalität',
      aenderung: (held) => mitLoyalitaetPlusEins(
        held,
        begleiterId: c.id,
        erwarteteLoyalitaet: lo,
      ),
    );
    if (gespeichert != null) _melde('Loyalität auf ${lo + 1} erhöht.');
  }

  // ---- Vertrautenzauber würfeln ---------------------------------------

  Future<void> _wuerfleZauber() async {
    final c = _vertrauter;
    final snapshot = ref.read(heroComputedProvider(widget.heroId)).valueOrNull;
    if (c == null || snapshot == null) {
      _melde('Heldenwerte werden noch geladen.');
      return;
    }
    final kategorie = c.ritualCategories
        .where((k) => k.id == 'vertrautenmagie')
        .firstOrNull;
    if (kategorie == null) {
      _melde('Der Vertraute hat noch keine Vertrautenmagie.');
      return;
    }
    final wahl = await showAdaptiveInputDialog<(HeroRitualEntry, bool)>(
      context: context,
      builder: (_) => _ZauberWahlDialog(kategorie: kategorie),
    );
    if (wahl == null || !mounted) return;
    final request = vertrautenRitualProbe(
      vertrauter: c,
      kategorie: kategorie,
      ritual: wahl.$1,
      hexeProbenEigenschaften: snapshot.probenEigenschaften,
      koerperkontakt: wahl.$2,
    );
    if (request == null) {
      _melde('${wahl.$1.name} hat keine Ritualprobe mit drei Eigenschaften.');
      return;
    }
    bool? erfolg;
    await showLoggedProbeDialog(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      request: request,
      onResolved: (ergebnis) => erfolg = ergebnis.success,
    );
    if (!mounted) return;
    final vorrat = begleiterAktuellerPool(c, _zustand, BegleiterPool.asp);
    final asp = await showAdaptiveInputDialog<int>(
      context: context,
      builder: (_) => _ZauberKostenDialog(
        ritual: wahl.$1,
        vorrat: vorrat,
        gelungen: erfolg,
      ),
    );
    if (asp == null || !mounted) return;
    await aendereBegleiterPool(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      begleiter: c,
      pool: BegleiterPool.asp,
      aenderung: RessourcenAenderung.schritt(-asp, untergrenze: 0),
    );
  }

  // ---- Tierproben --------------------------------------------------------

  Future<void> _tierprobe(ResolvedProbeRequest Function(HeroCompanion) bau) {
    final c = _vertrauter;
    if (c == null) return Future<void>.value();
    return showLoggedProbeDialog(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      request: bau(c),
    );
  }

  static String _fehlertext(Object fehler) =>
      fehler is StateError ? fehler.message : '$fehler';

  @override
  Widget build(BuildContext context) {
    final c = ref
        .watch(heroByIdProvider(widget.heroId))
        ?.companions
        .where((b) => b.id == widget.companionId)
        .firstOrNull;
    if (c == null || c.vertrautenBindung == null) {
      return const SizedBox.shrink();
    }
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    Widget knopf(String schluessel, String text, VoidCallback? onPressed) =>
        OutlinedButton(
          key: ValueKey<String>(schluessel),
          onPressed: onPressed,
          child: Text(text),
        );
    return Column(
      key: const ValueKey<String>('vertrauten-spiel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Vertrautenaktionen'),
        Text(
          'Regeneration läuft mit der Rast der Hexe (Rastdialog). Die '
          'Vereinigung zieht beiden AsP ab; ein versäumtes Treffen kostet den '
          'Vertrauten LeP und LO.',
          style: muted,
        ),
        const SizedBox(height: _innerFieldSpacing),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            knopf('vertrauten-vereinigung', 'Vereinigung', _vereinige),
            knopf(
              'vertrauten-versaeumt',
              'Treffen versäumt',
              widget.sofort ? _treffenVersaeumt : null,
            ),
            knopf(
              'vertrauten-lo-plus',
              'CH-Probe (LO +1)',
              widget.sofort ? _loyalitaetProbe : null,
            ),
            knopf(
              'vertrauten-zauber-wuerfeln',
              'Zauber würfeln',
              _wuerfleZauber,
            ),
            knopf(
              'vertrauten-kl-probe',
              'KL-Probe (Auftrag)',
              () => _tierprobe(vertrautenKlProbe),
            ),
            knopf(
              'vertrauten-lo-probe',
              'LO-Probe (Gefahr)',
              () => _tierprobe(vertrautenLoProbe),
            ),
          ],
        ),
        if (_letzteMeldung != null)
          Padding(
            padding: const EdgeInsets.only(top: _innerFieldSpacing),
            child: Text(
              _letzteMeldung!,
              key: const ValueKey<String>('vertrauten-spiel-meldung'),
            ),
          ),
        if (!widget.sofort)
          Text(
            'Buchungen am Bogen (Loyalität) ruhen bei ungespeicherten '
            'Änderungen.',
            style: muted,
          ),
      ],
    );
  }
}

/// Öffnet die Vertrautenaktionen eines gebundenen Vertrauten in einem Dialog.
///
/// Für die Spielansicht des Kartograph-Rahmens: dieselben Aktionen und
/// Schreibwege wie im Begleiter-Tab, ohne dessen Bearbeitungsentwurf. Fehler
/// erscheinen im Dialog selbst (`ZustandFehlerBereich`).
Future<void> zeigeVertrautenAktionen({
  required BuildContext context,
  required String heroId,
  required String begleiterId,
}) {
  return showAdaptiveInputDialog<void>(
    context: context,
    builder: (dialogContext) => AdaptiveInputDialog(
      title: 'Vertrautenaktionen',
      content: ZustandFehlerBereich(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BegleiterLaufwerteSection(
              heroId: heroId,
              companionId: begleiterId,
            ),
            const SizedBox(height: _sectionSpacing),
            _VertrautenSpielSection(
              heroId: heroId,
              companionId: begleiterId,
              sofort: true,
            ),
            const ZustandFehlerAnzeige(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Schließen'),
        ),
      ],
    ),
  );
}
