part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Sofortbuchungen der Vertrautenbindung
// ---------------------------------------------------------------------------

/// Bindung, AP-Fluss, Zauber und Ausbildung eines Vertrauten.
///
/// Gebucht wird wie bei der Steigerung frisch auf den gespeicherten Helden
/// (`aendereHeldMitMeldung`, bei offener Planung gesperrt), nie über den
/// Editorentwurf; deshalb nur ohne offene Änderungen. Die Regeln liegen in
/// `vertrauten_bindung_rules.dart`, `vertrauten_ap_rules.dart` und
/// `vertrauten_ausbildung_rules.dart`.
extension _VertrautenBindungAktionen on _HeroBegleiterTabState {
  // Die Hexe hat den Vorteil Machtvoller Vertrauter.
  bool get _hexeHatMachtvollenVertrauten =>
      _latestHero?.vorteilEintraege.any(
        (m) => m.katalogId == 'adv_machtvoller_vertrauter',
      ) ??
      false;

  /// Bindet einen neuen Vertrauten und bucht die Kosten bei der Hexe.
  Future<void> _bindeVertrauten(HeroCompanion angezeigt) async {
    final held = _latestHero;
    if (held == null || !_kannSofortBuchen) return;
    final generierung = await showAdaptiveInputDialog<VertrautenGenerierung>(
      context: context,
      builder: (_) => _VertrautenBindungsDialog(
        freieAp: heldFreieAp(held),
        machtvollVorbelegt: _hexeHatMachtvollenVertrauten,
      ),
    );
    if (generierung == null || !mounted) return;
    await _bucheVertrauten(
      was: 'Bindung',
      meldung: 'Vertrauter gebunden',
      aenderung: (held) => bucheVertrautenBindung(
        held,
        begleiterId: angezeigt.id,
        generierung: generierung,
      ),
    );
  }

  /// Erfasst die Bindung eines Bestandsvertrauten ohne Buchung.
  Future<void> _erfasseVertrautenBindung(HeroCompanion angezeigt) async {
    if (!_kannSofortBuchen) return;
    final wahl = await showAdaptiveInputDialog<(String, bool)>(
      context: context,
      builder: (_) => _BindungErfassenDialog(
        machtvollVorbelegt: _hexeHatMachtvollenVertrauten,
      ),
    );
    if (wahl == null || !mounted) return;
    await _bucheVertrauten(
      was: 'Bindung',
      meldung: 'Bindung erfasst',
      aenderung: (held) => erfasseVertrautenBindung(
        held,
        begleiterId: angezeigt.id,
        artId: wahl.$1,
        machtvoll: wahl.$2,
      ),
    );
  }

  /// Überträgt AP der Hexe auf den Vertrauten (WdZ S. 125).
  Future<void> _uebertrageVertrautenAp(HeroCompanion angezeigt) async {
    final held = _latestHero;
    final bindung = angezeigt.vertrautenBindung;
    if (held == null || bindung == null || !_kannSofortBuchen) return;
    final frei = heldFreieAp(held);
    final ap = await showAdaptiveInputDialog<int>(
      context: context,
      builder: (_) => _VertrautenApDialog(
        titel: 'AP übertragen',
        text:
            'Die Hexe gibt AP dauerhaft an ihren Vertrauten ab (bei der '
            'Vereinigung). Je volle $kVertrautenApJeLoyalitaet übertragene AP '
            'steigt die Loyalität um 1. Bisher übertragen: '
            '${bindung.apUebertragen} AP.',
        vorschlag: kVertrautenApJeLoyalitaet,
        max: frei,
      ),
    );
    if (ap == null || !mounted) return;
    await _bucheVertrauten(
      was: 'Übertragung',
      meldung: '$ap AP übertragen',
      aenderung: (held) => uebertrageApAufVertrauten(
        held,
        begleiterId: angezeigt.id,
        ap: ap,
        erwartetUebertragen: bindung.apUebertragen,
      ),
    );
  }

  /// Richtet den AP-Anteil ein und schreibt einmalig den Nachtrag gut.
  Future<void> _richteVertrautenAnteilEin(HeroCompanion angezeigt) async {
    final held = _latestHero;
    if (held == null || !_kannSofortBuchen) return;
    final katalog = ref.read(rulesCatalogProvider).valueOrNull;
    final reiseberichtAp = katalog == null
        ? 0
        : gebuchteReiseberichtAp(
            catalog: katalog.reisebericht,
            gebucht: held.reisebericht,
          );
    final vorschlag = vertrautenNachtragsvorschlag(
      held,
      reiseberichtAp: reiseberichtAp,
    );
    final ap = await showAdaptiveInputDialog<int>(
      context: context,
      builder: (_) => _VertrautenApDialog(
        titel: 'AP-Anteil einrichten',
        text:
            'Ab jetzt erhält der Vertraute automatisch ¼ der AP, die die Hexe '
            'durch Abenteuer und Reisebericht bekommt. Einmalig nachtragen '
            '(Vorschlag: ¼ der bisher gebuchten Abenteuer-AP):',
        vorschlag: vorschlag,
        erlaubeNull: true,
      ),
    );
    if (ap == null || !mounted) return;
    await _bucheVertrauten(
      was: 'AP-Anteil',
      meldung: 'AP-Anteil eingerichtet',
      aenderung: (held) => richteVertrautenApAnteilEin(
        held,
        begleiterId: angezeigt.id,
        nachtragAp: ap,
      ),
    );
  }

  /// Bucht eine Ausbildungsstufe oder Fertigkeit aus den AP des Vertrauten.
  Future<void> _bucheVertrautenAusbildung(HeroCompanion angezeigt) async {
    final bindung = angezeigt.vertrautenBindung;
    if (bindung == null || !_kannSofortBuchen) return;
    final wahl = await showAdaptiveInputDialog<_VertrautenAusbildungWahl>(
      context: context,
      builder: (_) => _VertrautenAusbildungDialog(companion: angezeigt),
    );
    if (wahl == null || !mounted) return;
    await _bucheVertrauten(
      was: 'Ausbildung',
      meldung: 'Ausbildung gebucht',
      aenderung: (held) => bucheVertrautenAusbildung(
        held,
        begleiterId: angezeigt.id,
        katalogId: wahl.katalogId,
        apKosten: wahl.apKosten,
        erwarteteAnzahl: bindung.ausbildungen.length,
        bezeichnung: wahl.bezeichnung,
        meisterentscheid: wahl.meisterentscheid,
      ),
    );
  }

  /// Lernt einen Vertrautenzauber aus den AP des Vertrauten.
  Future<void> _lerneVertrautenZauber(HeroCompanion angezeigt) async {
    if (!_kannSofortBuchen) return;
    final wahl = await showAdaptiveInputDialog<(String, int)>(
      context: context,
      builder: (_) => _VertrautenZauberDialog(companion: angezeigt),
    );
    if (wahl == null || !mounted) return;
    await _bucheVertrauten(
      was: 'Vertrautenzauber',
      meldung: '${wahl.$1} gelernt',
      aenderung: (held) => lerneVertrautenZauber(
        held,
        begleiterId: angezeigt.id,
        ritualName: wahl.$1,
        apKosten: wahl.$2,
      ),
    );
  }

  // Schreibt frisch, übernimmt den gespeicherten Stand und meldet Erfolg.
  Future<void> _bucheVertrauten({
    required String was,
    required String meldung,
    required HeroSheet Function(HeroSheet held) aenderung,
  }) async {
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: was,
      aenderung: aenderung,
    );
    if (gespeichert == null || !mounted) return;
    _uebernimmGespeichertenHelden(gespeichert);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(meldung)));
  }
}
