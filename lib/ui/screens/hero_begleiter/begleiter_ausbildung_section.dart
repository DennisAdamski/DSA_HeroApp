part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Reittier-Ausbildung (ZBA S. 32–37)
// ---------------------------------------------------------------------------

/// Hinweis, wenn Sofortbuchungen wegen offener Änderungen ruhen.
const String _kSofortbuchungGesperrt =
    'Erst die offenen Änderungen speichern oder verwerfen.';

/// Ausbildungsstand eines Reittiers: Übersicht, Herleitung, Schritte und
/// Unarten.
///
/// Ausgangsstand, Variante und Unarten sind Editorfelder ([onChanged]);
/// Ausbildungsschritte werden sofort gebucht ([onSchritt],
/// [onSchrittZurueck]), damit sie wie eine Steigerung frisch auf dem
/// gespeicherten Helden landen.
class _AusbildungSection extends StatelessWidget {
  const _AusbildungSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
    this.onSchritt,
    this.onSchrittZurueck,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  /// Öffnet den Schrittdialog; `null`, solange Sofortbuchungen ruhen.
  final VoidCallback? onSchritt;

  /// Nimmt den letzten Schritt zurück; `null`, solange Buchungen ruhen.
  final VoidCallback? onSchrittZurueck;

  @override
  Widget build(BuildContext context) {
    final ausbildung = companion.reittierAusbildung;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final hatWeiterenSchritt =
        ausbildung != null &&
        naechsteAusbildungsschritte(ausbildung).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeader('Reittier-Ausbildung')),
            if (hatWeiterenSchritt)
              Tooltip(
                message: onSchritt == null ? _kSofortbuchungGesperrt : '',
                child: TextButton(
                  key: const ValueKey<String>('begleiter-ausbildungsschritt'),
                  onPressed: onSchritt,
                  child: const Text('+ Ausbildungsschritt'),
                ),
              ),
          ],
        ),
        if (ausbildung == null)
          ..._leer(context, muted)
        else
          ..._stand(context, ausbildung, muted),
      ],
    );
  }

  // Leerzustand: im Bearbeitungsmodus lässt sich die Ausbildung erfassen.
  List<Widget> _leer(BuildContext context, TextStyle? muted) {
    return <Widget>[
      Text(
        isEditing
            ? 'Erfasse den heutigen Stand; die eingetragenen Werte gelten dann '
                  'als Ausgangswerte dieser Stufe.'
            : 'Keine Ausbildung erfasst. Im Bearbeitungsmodus erfassen.',
        style: muted,
      ),
      if (isEditing) ...[
        const SizedBox(height: _innerFieldSpacing),
        OutlinedButton.icon(
          key: const ValueKey<String>('begleiter-ausbildung-erfassen'),
          onPressed: () => _bearbeiteAusgangsstand(context, null),
          icon: const Icon(Icons.school_outlined, size: 18),
          label: const Text('Ausbildung erfassen'),
        ),
      ],
    ];
  }

  // Übersicht eines erfassten Ausbildungsstands.
  List<Widget> _stand(
    BuildContext context,
    ReittierAusbildung ausbildung,
    TextStyle? muted,
  ) {
    final reiten = reitenProbenModifikator(companion, imKampf: false);
    final reitenKampf = reitenProbenModifikator(companion, imKampf: true);
    final variante = gewaehlteVariante(ausbildung);
    final herkunft = reittierModifikationsHerkunft(ausbildung);
    final summe = reittierAusbildungsModifikationen(ausbildung);
    return <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          Chip(
            label: Text(
              '${aktuelleStufe(ausbildung).label} '
              '(${aktuelleArt(ausbildung).label})',
            ),
          ),
          if (variante != null)
            Chip(
              label: Text(
                variante.kampfpferd
                    ? '${variante.name} · Kampfpferd'
                    : variante.name,
              ),
            ),
          Chip(
            label: Text(
              'Reiten ${mitVorzeichen(reiten.erschwernis)} · im Kampf '
              '${mitVorzeichen(reitenKampf.erschwernis)}',
            ),
          ),
        ],
      ),
      for (final hinweis in reitenKampf.hinweise) Text(hinweis, style: muted),
      if (herkunft.isNotEmpty) ...[
        const SizedBox(height: _innerFieldSpacing),
        for (final quelle in herkunft)
          Text(
            '${quelle.bezeichnung}: '
            '${reittierModifikationenText(quelle.modifikationen)}',
            style: muted,
          ),
        Text(
          'Wirksam: ${reittierModifikationenText(summe)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text('Die Ansicht zeigt Werte inklusive Ausbildung.', style: muted),
      ],
      const SizedBox(height: _innerFieldSpacing),
      ..._schritte(context, ausbildung, muted),
      const SizedBox(height: _innerFieldSpacing),
      ..._unarten(context, ausbildung, muted),
      if (isEditing) ...[
        const SizedBox(height: _innerFieldSpacing),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              key: const ValueKey<String>('begleiter-ausgangsstand'),
              onPressed: () => _bearbeiteAusgangsstand(context, ausbildung),
              child: const Text('Ausgangsstand ändern'),
            ),
            TextButton(
              onPressed: () =>
                  onChanged(companion.copyWith(reittierAusbildung: null)),
              child: const Text('Ausbildung entfernen'),
            ),
          ],
        ),
      ],
    ];
  }

  // Liste der gebuchten Schritte; der letzte lässt sich zurücknehmen.
  List<Widget> _schritte(
    BuildContext context,
    ReittierAusbildung ausbildung,
    TextStyle? muted,
  ) {
    final schritte = ausbildung.schritte;
    if (schritte.isEmpty) {
      return <Widget>[
        Text(
          'Ausgangsstand: ${ausbildung.ausgangsstufe.label} '
          '(${ausbildung.ausgangsart.label}). Noch kein Schritt gebucht.',
          style: muted,
        ),
      ];
    }
    return <Widget>[
      Text('Gebuchte Schritte', style: Theme.of(context).textTheme.labelMedium),
      for (var i = 0; i < schritte.length; i++)
        Row(
          children: [
            Expanded(
              child: Text(
                [
                  reittierSchrittText(schritte[i].nach, schritte[i].art),
                  if (schritte[i].ausbilder.isNotEmpty) schritte[i].ausbilder,
                  if (schritte[i].fehlschlaege > 0)
                    '${schritte[i].fehlschlaege} misslungene Proben',
                  if (schritte[i].notiz.isNotEmpty) schritte[i].notiz,
                ].join(' · '),
              ),
            ),
            if (i == schritte.length - 1)
              IconButton(
                key: const ValueKey<String>(
                  'begleiter-ausbildungsschritt-zurueck',
                ),
                icon: const Icon(Icons.undo, size: 18),
                tooltip: onSchrittZurueck == null
                    ? _kSofortbuchungGesperrt
                    : 'Letzten Schritt zurücknehmen',
                visualDensity: VisualDensity.compact,
                onPressed: onSchrittZurueck,
              ),
          ],
        ),
    ];
  }

  // Unarten als Chips; im Bearbeitungsmodus entfern- und ergänzbar.
  List<Widget> _unarten(
    BuildContext context,
    ReittierAusbildung ausbildung,
    TextStyle? muted,
  ) {
    final ids = ausbildung.unartIds;
    return <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              'Unarten',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          if (isEditing)
            TextButton(
              key: const ValueKey<String>('begleiter-unart-hinzufuegen'),
              onPressed: () => _ergaenzeUnart(context, ausbildung),
              child: const Text('+ Unart'),
            ),
        ],
      ),
      if (ids.isEmpty)
        Text('Keine.', style: muted)
      else
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final id in ids)
              Chip(
                label: Text(_unartText(id)),
                onDeleted: isEditing
                    ? () => onChanged(
                        companion.copyWith(
                          reittierAusbildung: ausbildung.copyWith(
                            unartIds: ids.where((u) => u != id).toList(),
                          ),
                        ),
                      )
                    : null,
              ),
          ],
        ),
    ];
  }

  // Anzeigename einer Unart samt LO-Wirkung; unbekannte IDs bleiben lesbar.
  String _unartText(String id) {
    final unart = pferdeUnart(id);
    if (unart == null) {
      return id;
    }
    return unart.lo == 0
        ? unart.name
        : '${unart.name} (LO ${mitVorzeichen(unart.lo)})';
  }

  Future<void> _bearbeiteAusgangsstand(
    BuildContext context,
    ReittierAusbildung? bisher,
  ) async {
    final ergebnis = await showAdaptiveInputDialog<ReittierAusbildung>(
      context: context,
      builder: (_) => _AusgangsstandDialog(initial: bisher),
    );
    if (ergebnis != null) {
      onChanged(companion.copyWith(reittierAusbildung: ergebnis));
    }
  }

  Future<void> _ergaenzeUnart(
    BuildContext context,
    ReittierAusbildung ausbildung,
  ) async {
    final id = await showAdaptiveInputDialog<String>(
      context: context,
      builder: (_) => _UnartDialog(vorhanden: ausbildung.unartIds),
    );
    if (id != null) {
      onChanged(
        companion.copyWith(
          reittierAusbildung: ausbildung.copyWith(
            unartIds: <String>[...ausbildung.unartIds, id],
          ),
        ),
      );
    }
  }
}
