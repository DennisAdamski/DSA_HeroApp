part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Vertrautenbindung (WdZ S. 123–125)
// ---------------------------------------------------------------------------

/// Sofortbuchungen eines Vertrauten, gebündelt für die Detailansicht.
class _VertrautenAktionen {
  const _VertrautenAktionen({
    required this.binden,
    required this.erfassen,
    required this.uebertragen,
    required this.anteilEinrichten,
    required this.ausbildung,
    required this.zauberLernen,
  });

  final VoidCallback binden;
  final VoidCallback erfassen;
  final VoidCallback uebertragen;
  final VoidCallback anteilEinrichten;
  final VoidCallback ausbildung;
  final VoidCallback zauberLernen;
}

/// Bindung, AP-Fluss und Ausbildung eines Vertrauten.
///
/// Alle Aktionen sind Sofortbuchungen auf den gespeicherten Helden
/// (`vertrauten_bindung_aktionen.dart`); sie ruhen, solange ungespeicherte
/// Änderungen offen sind (Callbacks dann `null`).
class _VertrautenBindungSection extends StatelessWidget {
  const _VertrautenBindungSection({
    required this.companion,
    this.onBinden,
    this.onErfassen,
    this.onUebertragen,
    this.onAnteilEinrichten,
    this.onAusbildung,
  });

  final HeroCompanion companion;
  final VoidCallback? onBinden;
  final VoidCallback? onErfassen;
  final VoidCallback? onUebertragen;
  final VoidCallback? onAnteilEinrichten;
  final VoidCallback? onAusbildung;

  @override
  Widget build(BuildContext context) {
    final bindung = companion.vertrautenBindung;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final sperrHinweis = onBinden == null && onUebertragen == null
        ? _kSofortbuchungGesperrt
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeader('Vertrautenbindung')),
            if (bindung != null)
              Tooltip(
                message: onAusbildung == null ? _kSofortbuchungGesperrt : '',
                child: TextButton(
                  key: const ValueKey<String>('vertrauten-ausbildung'),
                  onPressed: onAusbildung,
                  child: const Text('+ Ausbildung'),
                ),
              ),
          ],
        ),
        if (bindung == null)
          ..._ungebunden(muted, sperrHinweis)
        else
          ..._gebunden(context, bindung, muted, sperrHinweis),
      ],
    );
  }

  List<Widget> _ungebunden(TextStyle? muted, String sperrHinweis) {
    return <Widget>[
      Text(
        'Noch keine Bindung erfasst. Ein neues Tier wird gebunden (die Hexe '
        'zahlt die Bindung in AP); ein schon gebundenes wird ohne Buchung '
        'erfasst.',
        style: muted,
      ),
      const SizedBox(height: _innerFieldSpacing),
      Tooltip(
        message: sperrHinweis,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              key: const ValueKey<String>('vertrauten-binden'),
              onPressed: onBinden,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Vertrauten binden'),
            ),
            OutlinedButton(
              key: const ValueKey<String>('vertrauten-erfassen'),
              onPressed: onErfassen,
              child: const Text('Ohne Buchung erfassen'),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _gebunden(
    BuildContext context,
    VertrautenBindung bindung,
    TextStyle? muted,
    String sperrHinweis,
  ) {
    final art = vertrautenArt(bindung.artId);
    final kosten = bindung.bindungskosten;
    final anteil = bindung.abenteuerApErfasst;
    return <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          Chip(label: Text(art?.name ?? 'Art außerhalb des Katalogs')),
          if (bindung.machtvoll) const Chip(label: Text('Machtvoll')),
          Chip(
            label: Text(
              kosten == null
                  ? 'Bindung ohne Buchung'
                  : 'Bindung: $kosten AP der Hexe',
            ),
          ),
        ],
      ),
      const SizedBox(height: _innerFieldSpacing),
      Text(
        anteil == null
            ? 'AP-Anteil: nicht eingerichtet. Danach erhält der Vertraute '
                  'automatisch ¼ der Abenteuer-AP der Hexe.'
            : 'AP-Anteil: ¼ der Abenteuer-AP der Hexe (seit dem Einrichten '
                  '$anteil AP erfasst).',
        style: muted,
      ),
      Text(
        'Übertragen: ${bindung.apUebertragen} AP '
        '(Loyalität +1 je volle $kVertrautenApJeLoyalitaet AP, höchstens '
        '$kVertrautenMaxLoyalitaet).',
        style: muted,
      ),
      const SizedBox(height: _innerFieldSpacing),
      Tooltip(
        message: sperrHinweis,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (anteil == null)
              OutlinedButton(
                key: const ValueKey<String>('vertrauten-anteil-einrichten'),
                onPressed: onAnteilEinrichten,
                child: const Text('AP-Anteil einrichten'),
              ),
            OutlinedButton(
              key: const ValueKey<String>('vertrauten-ap-uebertragen'),
              onPressed: onUebertragen,
              child: const Text('AP übertragen'),
            ),
          ],
        ),
      ),
      if (bindung.ausbildungen.isNotEmpty) ...[
        const SizedBox(height: _innerFieldSpacing),
        Text('Ausbildung', style: Theme.of(context).textTheme.labelMedium),
        for (final buchung in bindung.ausbildungen)
          Text('• ${_ausbildungText(buchung)}'),
      ],
      if (art != null) ...[
        const SizedBox(height: _innerFieldSpacing),
        Text('Kampfregeln: ${art.kampfregeln.join(' · ')}', style: muted),
        Text('Tiersinne: ${art.tiersinne}', style: muted),
        if (art.hinweis.isNotEmpty) Text(art.hinweis, style: muted),
      ],
    ];
  }

  static String _ausbildungText(VertrautenAusbildungsbuchung buchung) {
    final name =
        vertrautenAusbildung(buchung.katalogId)?.name ??
        vertrautenFertigkeit(buchung.katalogId)?.name ??
        buchung.katalogId;
    final zusatz = buchung.bezeichnung.isEmpty
        ? ''
        : ' (${buchung.bezeichnung})';
    return '$name$zusatz – ${buchung.apKosten} AP';
  }
}
