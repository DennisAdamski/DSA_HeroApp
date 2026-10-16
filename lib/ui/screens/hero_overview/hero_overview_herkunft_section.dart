part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

/// Herkunftsmodifikatoren der Uebersicht (ARCH-02, Herkunftsmerkmale).
///
/// Bearbeitet wird die strukturierte Liste je Gruppe; die Modifikator-Texte
/// (`rasseModText` …) entstehen als Projektion. Solange nichts geaendert
/// wurde, bleibt der Entwurf `null` und der Held unberuehrt — die Migration
/// uebernimmt dann `saveHero`. Aenderungen laufen ausschliesslich ueber die
/// Regeln in `hero_herkunft_bearbeitung_rules.dart`.
extension _HeroOverviewHerkunftSection on _HeroOverviewTabState {
  /// Eine Herkunftsgruppe mit ihren Modifikatoren.
  Widget _buildHerkunftSection(HeroSheet hero, HeroHerkunft herkunft) {
    return HeroHerkunftSection(
      herkunft: herkunft,
      background: _draftHerkunft ?? hero.background,
      bearbeitbar: _editController.isEditing,
      vorBearbeiten: () =>
          bestaetigeBearbeitungBeiPlanung(context: context, heroId: hero.id),
      onEintraegeChanged: (eintraege) =>
          _setzeHerkunftEintraege(hero, herkunft, eintraege),
      onAbgleich: (wahl) => _loeseHerkunftsAbgleich(hero, herkunft, wahl),
    );
  }

  void _setzeHerkunftEintraege(
    HeroSheet hero,
    HeroHerkunft herkunft,
    List<HeroHerkunftsModifikator> eintraege,
  ) {
    final basis = _draftHerkunft ?? hero.background;
    try {
      // Im Entwurf ist der Stand zugleich Basis und Ausgang; ob inzwischen
      // jemand anders speichert, entscheidet beim Speichern der Abgleich des
      // Editorentwurfs.
      _draftHerkunft = ersetzeHerkunftsEintraege(
        basis: basis,
        aktuell: basis,
        herkunft: herkunft,
        eintraege: eintraege,
      );
    } on StateError catch (fehler) {
      _zeigeHerkunftFehler(fehler.message);
      return;
    }
    _onFieldChanged('');
  }

  void _loeseHerkunftsAbgleich(
    HeroSheet hero,
    HeroHerkunft herkunft,
    HerkunftsAbgleichWahl wahl,
  ) {
    try {
      _draftHerkunft = loeseHerkunftsAbweichung(
        _draftHerkunft ?? hero.background,
        herkunft,
        wahl,
      );
    } on StateError catch (fehler) {
      _zeigeHerkunftFehler(fehler.message);
      return;
    }
    _onFieldChanged('');
  }

  void _zeigeHerkunftFehler(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Uebernimmt den Herkunftsentwurf in [hero]: Container plus Projektion.
  HeroSheet _mitHerkunftEntwurf(HeroSheet hero) {
    final entwurf = _draftHerkunft;
    if (entwurf == null) {
      return hero;
    }
    return hero.copyWith(
      background: hero.background.copyWith(
        herkunftsModifikatoren: entwurf.herkunftsModifikatoren,
        rasseModText: entwurf.rasseModText,
        kulturModText: entwurf.kulturModText,
        professionModText: entwurf.professionModText,
      ),
    );
  }

  /// Fragt die Herkunft eines Merkmals ab und uebernimmt sie in den Entwurf.
  Future<void> _aendereMerkmalHerkunft({
    required String keyName,
    required List<HeroMerkmal> eintraege,
    required int index,
  }) async {
    if (!await bestaetigeBearbeitungBeiPlanung(
      context: context,
      heroId: widget.heroId,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    final eintrag = eintraege[index];
    final wahl = await zeigeMerkmalHerkunftDialog(
      context: context,
      merkmalName: eintrag.text,
      aktuell: eintrag.herkunft,
    );
    if (wahl == null || !mounted || wahl.herkunft == eintrag.herkunft) {
      return;
    }
    _setzeMerkmale(
      keyName,
      List<HeroMerkmal>.of(eintraege)
        ..[index] = eintrag.copyWith(herkunft: wahl.herkunft),
    );
  }
}
