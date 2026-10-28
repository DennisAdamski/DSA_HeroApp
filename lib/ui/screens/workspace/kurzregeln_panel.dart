import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/kurzregel_def.dart';
import 'package:dsa_heldenverwaltung/catalog/kurzregel_loader.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kurzregel_suche_rules.dart';
import 'package:dsa_heldenverwaltung/state/kurzregel_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/catalog_unlock_dialog.dart';

/// Durchsuchbares Kurzregel-Kompendium für den Regel-Nachschlag-Dialog.
///
/// Arbeitet vollständig offline aus dem mitgelieferten Katalog und braucht
/// weder die Wissensbasis noch eine Netzverbindung. Ohne Katalogpasswort
/// zeigt die Liste Titel und Quellenbelege; die Texte bleiben gesperrt, bis
/// der Nutzer das Passwort eingibt.
class KurzregelnPanel extends ConsumerStatefulWidget {
  /// Erzeugt das Panel.
  const KurzregelnPanel({super.key});

  @override
  ConsumerState<KurzregelnPanel> createState() => _KurzregelnPanelState();
}

class _KurzregelnPanelState extends ConsumerState<KurzregelnPanel>
    with AutomaticKeepAliveClientMixin {
  String _query = '';
  String? _thema;

  // Hält Suchtext und Filter beim Reiterwechsel.
  @override
  bool get wantKeepAlive => true;

  /// Öffnet die Passworteingabe; der Provider lädt danach selbst neu.
  Future<void> _freischalten() async {
    await showCatalogUnlockDialog(context: context, ref: ref);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final katalog = ref.watch(kurzregelKatalogProvider);
    return katalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _Hinweis(
        text: 'Das Kurzregel-Kompendium konnte nicht geladen werden.',
      ),
      data: _buildKatalog,
    );
  }

  Widget _buildKatalog(KurzregelKatalog katalog) {
    final treffer = sucheKurzregeln(katalog.eintraege, _query, thema: _thema);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: const ValueKey('kurzregeln-suchfeld'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Kurzregel suchen …',
            ),
            onChanged: (wert) => setState(() => _query = wert),
          ),
        ),
        _buildThemen(katalog),
        if (katalog.gesperrt) _buildSperrHinweis(),
        const SizedBox(height: 4),
        Expanded(child: _buildListe(katalog, treffer)),
      ],
    );
  }

  /// Filter-Chips für die im Katalog vorkommenden Themen.
  Widget _buildThemen(KurzregelKatalog katalog) {
    final vorhanden = {for (final e in katalog.eintraege) e.thema}..remove('');
    if (vorhanden.isEmpty) {
      return const SizedBox.shrink();
    }
    final bekannte = [
      for (final thema in kurzregelThemen)
        if (vorhanden.contains(thema.schluessel)) thema.schluessel,
    ];
    final themen = [
      ...bekannte,
      ...vorhanden.where((t) => !bekannte.contains(t)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final thema in themen)
            FilterChip(
              key: ValueKey('kurzregeln-thema-$thema'),
              label: Text(kurzregelThemaLabel(thema)),
              visualDensity: VisualDensity.compact,
              selected: _thema == thema,
              onSelected: (aktiv) =>
                  setState(() => _thema = aktiv ? thema : null),
            ),
        ],
      ),
    );
  }

  /// Hinweis mit Freischalt-Knopf, solange Texte verschlüsselt sind.
  Widget _buildSperrHinweis() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Die Regeltexte sind gesperrt.'),
          TextButton.icon(
            key: const ValueKey('kurzregeln-freischalten'),
            onPressed: _freischalten,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Freischalten'),
          ),
        ],
      ),
    );
  }

  Widget _buildListe(KurzregelKatalog katalog, List<KurzregelDef> treffer) {
    if (katalog.eintraege.isEmpty) {
      return const _Hinweis(
        text: 'Das Kompendium enthält noch keine Einträge.',
      );
    }
    if (treffer.isEmpty) {
      return const _Hinweis(text: 'Keine Kurzregel gefunden.');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: treffer.length,
      itemBuilder: (context, index) => _KurzregelKarte(regel: treffer[index]),
    );
  }
}

/// Zentrierter Leer- oder Fehlerhinweis.
class _Hinweis extends StatelessWidget {
  const _Hinweis({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(text, textAlign: TextAlign.center)),
    );
  }
}

/// Aufklappbare Karte einer Kurzregel mit getrennter Hausregel-Anzeige.
class _KurzregelKarte extends StatelessWidget {
  const _KurzregelKarte({required this.regel});

  final KurzregelDef regel;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final thema = kurzregelThemaLabel(regel.thema);
    final untertitel = [
      if (thema.isNotEmpty) thema,
      if (regel.hatHausregel) 'mit Hausregel',
    ].join(' · ');
    return Card(
      key: ValueKey('kurzregel-${regel.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(regel.titel),
        subtitle: untertitel.isEmpty ? null : Text(untertitel),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Abschnitt(
            titel: 'Offizielle Regel (DSA 4.1)',
            kinder: [
              if (regel.gesperrt)
                const Text('Gesperrt – Katalogpasswort erforderlich.')
              else
                Text(regel.kurztext),
              for (final hinweis in regel.hinweise) _Stichpunkt(text: hinweis),
            ],
          ),
          if (regel.hatHausregel) _buildHausregel(context),
          const SizedBox(height: 8),
          Text('Quelle: ${regel.quellen.join(' · ')}', style: texte.bodySmall),
        ],
      ),
    );
  }

  /// Hausregel-Block, optisch klar von der offiziellen Regel abgesetzt.
  Widget _buildHausregel(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: farben.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: _Abschnitt(
            titel: 'Hausregel',
            kinder: [
              Text(
                regel.gesperrt
                    ? 'Gesperrt – Katalogpasswort erforderlich.'
                    : regel.hausregelText,
              ),
              const SizedBox(height: 4),
              Text(
                'Beleg: ${regel.hausregelQuelle}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abschnitt mit fetter Überschrift.
class _Abschnitt extends StatelessWidget {
  const _Abschnitt({required this.titel, required this.kinder});

  final String titel;
  final List<Widget> kinder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titel,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        ...kinder,
      ],
    );
  }
}

/// Aufzählungspunkt, der bei großer Schrift umbricht statt zu überlaufen.
class _Stichpunkt extends StatelessWidget {
  const _Stichpunkt({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
