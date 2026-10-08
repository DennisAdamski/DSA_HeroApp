part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Steigerung (inline, nur Vertraute)
// ---------------------------------------------------------------------------

/// Vertrauten-Steigerungen nach WdZ S. 125 (Komplexität F).
///
/// Grenzen und Steigerbarkeit kommen aus `companion_steigerung_rules.dart`;
/// gebucht wird frisch auf den gespeicherten Begleiter (ARCH-05).
extension _VertrautenSteigerungAktionen on _HeroBegleiterTabState {
  bool get _canRaise => _editController.isEditing && !_editController.isDirty;

  HeroCompanion? get _activeCompanion => _activeCompanionId != null
      ? _draftCompanions.cast<HeroCompanion?>().firstWhere(
          (c) => c!.id == _activeCompanionId,
          orElse: () => null,
        )
      : null;

  bool _canRaiseFor(HeroCompanion c) =>
      _canRaise && c.typ == BegleiterTyp.vertrauter;

  /// Steigert eine Eigenschaft (direkt).
  Future<void> _raiseRegular(String key, String label) async {
    final c = _activeCompanion;
    if (c == null || !_canRaiseFor(c)) return;
    final basis = companionBasiswert(c, key);
    if (basis == null) return;
    await _steigereVertrauten(
      c,
      bezeichnung: label,
      ziel: BegleiterSteigerungsziel.wert(key),
      basis: basis,
    );
  }

  /// Kauft LeP, AsP oder MR hinzu (Kosten nach gekauften Punkten).
  Future<void> _raisePool(String key, String label) async {
    final c = _activeCompanion;
    if (c == null || !_canRaiseFor(c)) return;
    await _steigereVertrauten(
      c,
      bezeichnung: label,
      ziel: BegleiterSteigerungsziel.wert(key),
      basis: 0,
    );
  }

  /// Steigert die AT eines Angriffs.
  Future<void> _raiseAngriffAt(String attackId) async {
    final c = _activeCompanion;
    if (c == null || !_canRaiseFor(c)) return;
    final angriff = c.angriffe.where((a) => a.id == attackId).firstOrNull;
    if (angriff == null || angriff.at == null) return;
    await _steigereVertrauten(
      c,
      bezeichnung: '${angriff.name} AT',
      ziel: BegleiterSteigerungsziel.angriff(attackId, parade: false),
      basis: angriff.at!,
    );
  }

  /// Steigert die PA eines Angriffs.
  Future<void> _raiseAngriffPa(String attackId) async {
    final c = _activeCompanion;
    if (c == null || !_canRaiseFor(c)) return;
    final angriff = c.angriffe.where((a) => a.id == attackId).firstOrNull;
    if (angriff == null || angriff.pa == null) return;
    await _steigereVertrauten(
      c,
      bezeichnung: '${angriff.name} PA',
      ziel: BegleiterSteigerungsziel.angriff(attackId, parade: true),
      basis: angriff.pa!,
    );
  }

  /// Steigert eine Geschwindigkeit (direkt).
  Future<void> _raiseGs(String art) async {
    final c = _activeCompanion;
    if (c == null || !_canRaiseFor(c)) return;
    final tempo = c.geschwindigkeiten.where((s) => s.art == art).firstOrNull;
    if (tempo == null) return;
    await _steigereVertrauten(
      c,
      bezeichnung: 'GS $art',
      ziel: BegleiterSteigerungsziel.geschwindigkeit(art),
      basis: tempo.wert,
    );
  }

  /// Steigert die Ritualkenntnis (direkt, unbegrenzt).
  Future<void> _raiseRk() async {
    final c = _activeCompanion;
    if (c == null || !_canRaiseFor(c)) return;
    final basisRk =
        c.ritualCategories
            .where((k) => k.id == kVertrautenmagieKategorieId)
            .firstOrNull
            ?.ownKnowledge
            ?.value ??
        0;
    await _steigereVertrauten(
      c,
      bezeichnung: 'Ritualkenntnis',
      ziel: const BegleiterSteigerungsziel.wert('rk'),
      basis: basisRk,
    );
  }

  // Öffnet den Steigerungsdialog für [ziel] und bucht das Ergebnis.
  //
  // [basis] ist der Grundwert direkt gesteigerter Werte; hinzugekaufte Werte
  // übergeben 0, ihr Dialog zählt dann die gekauften Punkte.
  Future<void> _steigereVertrauten(
    HeroCompanion c, {
    required String bezeichnung,
    required BegleiterSteigerungsziel ziel,
    required int basis,
  }) async {
    final darfBearbeiten = await bestaetigeBearbeitungBeiPlanung(
      context: context,
      heroId: widget.heroId,
    );
    if (!darfBearbeiten || !mounted) {
      return;
    }
    final stand = ziel.standIn(c);
    final maxStand = ziel.maxStandIn(c);
    if (maxStand != null && stand >= maxStand) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            maxStand == 0
                ? '$bezeichnung ist nach WdZ S. 125 nicht steigerbar.'
                : '$bezeichnung hat die Grenze von 1,5 × Startwert erreicht.',
          ),
        ),
      );
      return;
    }
    final apVerf = companionApVerfuegbar(c);
    final aktuell = basis + stand;
    var maxWert = regMaxSteigerung(
      aktuellerSteigerungswert: aktuell,
      verfuegbareAp: apVerf,
    );
    if (maxStand != null) maxWert = math.min(maxWert, basis + maxStand);
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: '$bezeichnung (Vertrauter)',
      aktuellerWert: aktuell,
      maxWert: maxWert,
      effektiveKomplexitaet: kVertrauterKomplexitaet,
      verfuegbareAp: apVerf,
    );
    if (result == null) return;
    await _bucheSteigerung(
      c,
      ziel: ziel,
      erwarteterStand: stand,
      neuerStand: result.neuerWert - basis,
      apKosten: result.apKosten,
    );
  }

  /// Bucht eine Vertrauten-Steigerung sofort, ohne den Editor zu speichern.
  ///
  /// Gebucht wird auf den gespeicherten Begleiter (ARCH-05): Hat ihn ein
  /// anderer Weg inzwischen gesteigert, passen die Kosten nicht mehr, und die
  /// Buchung wird mit Meldung abgewiesen. Danach übernimmt der Entwurf den
  /// gespeicherten Stand; gesteigert wird nur ohne offene Änderungen, und
  /// der gespeicherte Held wird die neue Basis des Abgleichs.
  Future<void> _bucheSteigerung(
    HeroCompanion angezeigt, {
    required BegleiterSteigerungsziel ziel,
    required int erwarteterStand,
    required int neuerStand,
    required int apKosten,
  }) async {
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Steigerung',
      aenderung: (held) => bucheBegleiterSteigerung(
        held,
        begleiterId: angezeigt.id,
        ziel: ziel,
        erwarteterStand: erwarteterStand,
        neuerStand: neuerStand,
        apKosten: apKosten,
      ),
    );
    if (gespeichert == null || !mounted) return;
    _uebernimmGespeichertenHelden(gespeichert);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Steigerung gespeichert')));
  }
}
