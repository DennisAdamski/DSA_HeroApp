part of '../hero_magic_tab.dart';

/// Zauber aus Artefakten (Matrixgebern, Spruchspeichern) in der Zauberliste
/// des Helden.
///
/// Die Zauber gehören dem Gegenstand: Repräsentation, ZfW und ZfP* stammen
/// von dessen Sprecher. Der Abschnitt ist nur zum Ansehen und Auslösen da;
/// bearbeitet wird der Gegenstand im Inventar.
class _MagicArtefaktZauberSection extends StatelessWidget {
  const _MagicArtefaktZauberSection({
    required this.eintraege,
    required this.onAusloesen,
  });

  final List<ArtefaktZauberEintrag> eintraege;
  final ValueChanged<HeroInventoryEntry> onAusloesen;

  @override
  Widget build(BuildContext context) {
    if (eintraege.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: CodexSectionCard(
        key: const ValueKey<String>('magic-artefakt-zauber'),
        title: 'Zauber aus Artefakten',
        subtitle:
            'Matrixgeber, Spruchspeicher und Zaubertalismane im Inventar. Ein '
            'Matrixgeber braucht einen zauberkundigen Träger; ein '
            'Spruchspeicher wirkt sofort, ohne AsP; ein permanenter '
            'Spruchspeicher wirkt ständig; ein Zaubertalisman '
            'unterstützt den Zauber, den du selbst sprichst.',
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < eintraege.length; i++)
                _zeile(context, eintraege[i], i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zeile(BuildContext context, ArtefaktZauberEintrag e, int index) {
    final zauber = e.zauber;
    final status = e.defekt
        ? 'beschädigt'
        : e.dauerhaft
        ? 'dauerhaft wirksam'
        : e.verbraucht
        ? 'Ladung verbraucht'
        : e.ausgeruestet
        ? 'ausgerüstet'
        : 'nicht ausgerüstet';
    final ausloesbar = artefaktAusloesbar(e.daten) && !e.verbraucht;
    return ListTile(
      key: ValueKey<String>('magic-artefakt-zauber-$index'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(zauber.name.isEmpty ? 'Unbenannt' : zauber.name),
      subtitle: Text(
        [
          e.artefakt.gegenstand.isEmpty ? 'Artefakt' : e.artefakt.gegenstand,
          status,
          if (e.detail.isNotEmpty) e.detail,
        ].join(' · '),
      ),
      trailing: !ausloesbar
          ? null
          : TextButton(
              key: ValueKey<String>('magic-artefakt-ausloesen-$index'),
              onPressed: () => onAusloesen(e.artefakt),
              child: Text(
                e.daten.art == ArtefaktArt.zaubertalisman
                    ? 'Auxiliator'
                    : 'Auslösen',
              ),
            ),
    );
  }
}
