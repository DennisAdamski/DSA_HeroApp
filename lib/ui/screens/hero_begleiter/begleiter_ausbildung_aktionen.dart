part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Sofortbuchungen der Reittier-Ausbildung
// ---------------------------------------------------------------------------

/// Ausbildungsschritte und Pferde-SF des Begleiter-Tabs.
///
/// Gebucht wird wie bei der Vertrauten-Steigerung frisch auf den
/// gespeicherten Helden (`aendereHeldMitMeldung`, bei offener Planung
/// gesperrt), nie über den Editorentwurf. Deshalb nur ohne offene
/// Änderungen; danach übernimmt der Entwurf den gespeicherten Stand.
extension _ReittierAusbildungAktionen on _HeroBegleiterTabState {
  /// `true`, solange keine ungespeicherten Änderungen offen sind.
  bool get _kannSofortBuchen => !_editController.isDirty;

  /// Wählt den nächsten Ausbildungsschritt und bucht ihn.
  Future<void> _oeffneAusbildungsschritt(HeroCompanion angezeigt) async {
    final ausbildung = angezeigt.reittierAusbildung;
    if (ausbildung == null || !_kannSofortBuchen) return;
    final wahl = await showAdaptiveInputDialog<_AusbildungsschrittWahl>(
      context: context,
      builder: (_) => _AusbildungsschrittDialog(ausbildung: ausbildung),
    );
    if (wahl == null || !mounted) return;
    await _bucheReittier(
      was: 'Ausbildungsschritt',
      meldung: 'Ausbildungsschritt gebucht',
      aenderung: (held) => bucheAusbildungsschritt(
        held,
        begleiterId: angezeigt.id,
        erwarteteSchrittanzahl: ausbildung.schritte.length,
        schritt: wahl.schritt,
        varianteId: wahl.varianteId,
        varianteSfUebernehmen: wahl.varianteSfUebernehmen,
      ),
    );
  }

  /// Nimmt nach Rückfrage den letzten Ausbildungsschritt zurück.
  Future<void> _nimmAusbildungsschrittZurueck(HeroCompanion angezeigt) async {
    final ausbildung = angezeigt.reittierAusbildung;
    if (ausbildung == null || ausbildung.schritte.isEmpty) return;
    if (!_kannSofortBuchen) return;
    final antwort = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Schritt zurücknehmen',
      content:
          'Den Schritt ${reittierSchrittText(ausbildung.schritte.last.nach, ausbildung.schritte.last.art)} '
          'zurücknehmen? Übernommene Sonderfertigkeiten bleiben stehen.',
      confirmLabel: 'Zurücknehmen',
    );
    if (antwort != AdaptiveConfirmResult.confirm || !mounted) return;
    await _bucheReittier(
      was: 'Rücknahme',
      meldung: 'Ausbildungsschritt zurückgenommen',
      aenderung: (held) => bucheAusbildungsschrittZurueck(
        held,
        begleiterId: angezeigt.id,
        erwarteteSchrittanzahl: ausbildung.schritte.length,
      ),
    );
  }

  /// Wählt eine Pferde-SF und trägt sie ein.
  Future<void> _oeffnePferdeSf(HeroCompanion angezeigt) async {
    if (!_kannSofortBuchen) return;
    final sfId = await showAdaptiveInputDialog<String>(
      context: context,
      builder: (_) => _PferdeSfDialog(companion: angezeigt),
    );
    if (sfId == null || !mounted) return;
    await _bucheReittier(
      was: 'Sonderfertigkeit',
      meldung: '${pferdeSf(sfId)?.name ?? 'Sonderfertigkeit'} erlernt',
      aenderung: (held) =>
          buchePferdeSf(held, begleiterId: angezeigt.id, sfId: sfId),
    );
  }

  // Schreibt frisch, übernimmt den gespeicherten Stand und meldet Erfolg.
  Future<void> _bucheReittier({
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
