// ignore_for_file: invalid_use_of_protected_member

part of '../hero_inventory_tab.dart';

extension _HeroInventoryMutations on _HeroInventoryTabState {
  /// Hängt einen im Editor angelegten Gegenstand frisch an (ARCH-05).
  ///
  /// Fehler gehen an den Editor, der sie anzeigt und offen bleibt.
  Future<void> _saveNewEntry(HeroInventoryEntry entry) async {
    final gespeichert = await aendereHeldImEditor(
      ref: ref,
      heroId: widget.heroId,
      aenderung: (held) => mitNeuemInventarEintrag(held, entry),
    );
    _nachEditorSpeichern(
      gespeichert.inventoryEntries,
      findeLetztenGleichenInventarEintrag(gespeichert.inventoryEntries, entry),
      changedEntry: entry,
    );
  }

  /// Schreibt das Editorergebnis [entry] frisch über den Gegenstand, mit dem
  /// der Editor geöffnet wurde ([angezeigt]).
  ///
  /// Getroffen wird der Eintrag über seinen Inhalt, nicht über seine
  /// Position. Hat ein anderer Weg ihn inzwischen geändert, wird das Ergebnis
  /// abgewiesen; der Editor zeigt den Grund und bleibt offen.
  Future<void> _saveUpdatedEntry(
    HeroInventoryEntry angezeigt,
    HeroInventoryEntry entry,
  ) async {
    final gespeichert = await aendereHeldImEditor(
      ref: ref,
      heroId: widget.heroId,
      aenderung: (held) =>
          mitGeaendertemInventarEintrag(held, angezeigt, entry),
    );
    _nachEditorSpeichern(
      gespeichert.inventoryEntries,
      _findeGespeichertenEintrag(gespeichert.inventoryEntries, entry),
      changedEntry: entry,
    );
  }

  void _nachEditorSpeichern(
    List<HeroInventoryEntry> gespeicherteEintraege,
    int auswahl, {
    required HeroInventoryEntry changedEntry,
  }) {
    if (!mounted) {
      return;
    }
    final shouldResetFilter =
        _filter != InventoryFilter.alle &&
        !matchesInventoryFilter(
          changedEntry.itemType,
          changedEntry.source,
          _filter,
        );

    setState(() {
      if (shouldResetFilter) {
        _filter = InventoryFilter.alle;
      }
      _waehleAus(gespeicherteEintraege, auswahl);
      _pendingNewEntry = null;
      _editorRevision++;
    });
  }

  // Position des gespeicherten Gegenstands nach dem Speichern. Verknüpfte
  // Einträge gleicht das Speichern an ihren Slot an; sie werden notfalls
  // über ihren ID-Verweis gefunden.
  int _findeGespeichertenEintrag(
    List<HeroInventoryEntry> eintraege,
    HeroInventoryEntry eintrag,
  ) {
    final perInhalt = findeGleichenInventarEintrag(eintraege, eintrag);
    final slotRef = eintrag.slotRef;
    if (perInhalt >= 0 || slotRef == null) {
      return perInhalt;
    }
    return eintraege.indexWhere((kandidat) => kandidat.slotRef == slotRef);
  }

  Future<void> _deleteEntry(int index) async {
    final hero = _latestHero;
    if (hero == null || index < 0 || index >= _entries.length) {
      return;
    }

    final entry = _entries[index];
    if (_isCombatLinkedEntry(entry)) {
      return;
    }

    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Gegenstand löschen',
      content: 'Soll „${_entryName(entry)}“ wirklich gelöscht werden?',
      confirmLabel: 'Löschen',
      isDestructive: true,
    );
    if (!mounted || confirmed != AdaptiveConfirmResult.confirm) {
      return;
    }

    // Die Auswahl über den Inhalt merken: Positionen können sich durch einen
    // anderen Schreibweg verschoben haben.
    final ausgewaehlt = _selectedIndex == index ? null : _bearbeiteterEintrag;
    // Frisch: nur dieser Eintrag verschwindet; Kampf und Geschossmengen
    // bleiben, wie sie gespeichert sind (ARCH-05).
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Löschen von „${_entryName(entry)}“',
      aenderung: (held) => ohneInventarEintrag(held, entry),
    );
    if (gespeichert == null || !mounted) {
      return;
    }
    final neueAuswahl = ausgewaehlt == null
        ? -1
        : findeGleichenInventarEintrag(
            gespeichert.inventoryEntries,
            ausgewaehlt,
          );
    setState(() {
      _waehleAus(gespeichert.inventoryEntries, neueAuswahl);
      _pendingNewEntry = null;
      _editorRevision++;
    });
  }

  /// Wählt den Eintrag an [index] für den Editor aus; `-1` schließt ihn.
  ///
  /// Der Editor arbeitet auf dem hier gemerkten Eintrag, nicht auf der
  /// Position: Verschiebt ein anderer Weg die Liste, bleibt er beim
  /// geöffneten Gegenstand.
  void _waehleAus(List<HeroInventoryEntry> eintraege, int index) {
    final gueltig = index >= 0 && index < eintraege.length;
    _selectedIndex = gueltig ? index : null;
    _bearbeiteterEintrag = gueltig ? eintraege[index] : null;
  }

  /// Setzt einen eingetippten Geldbetrag frisch am gespeicherten Helden.
  Future<void> _saveDukaten(String value) async {
    await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Dukaten',
      aenderung: (held) => mitDukaten(held, value),
    );
  }

  /// Verschiebt den gespeicherten Geldbetrag um einen Münzschritt.
  Future<void> _verschiebeDukaten(int deltaKreuzer) async {
    await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Dukaten',
      aenderung: (held) => mitDukatenSchritt(held, deltaKreuzer),
    );
  }

  bool _isCombatLinkedEntry(HeroInventoryEntry entry) {
    return entry.sourceRef != null &&
        isCombatLinkedInventorySource(entry.source);
  }
}
