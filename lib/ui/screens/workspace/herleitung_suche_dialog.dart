import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/rules/derived/herleitung_uebersicht_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/herleitung_abschnitt.dart';

/// Öffnet die durchsuchbaren Berechnungsschritte eines Helden (ARCH-04).
Future<void> showHerleitungsSuche({
  required BuildContext context,
  required String heroId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => HerleitungsSucheDialog(heroId: heroId),
  );
}

/// Schaltfläche (i) für die Werkzeugleiste, die [showHerleitungsSuche]
/// öffnet.
class HerleitungsSucheKnopf extends StatelessWidget {
  /// Erzeugt die Schaltfläche für [heroId]; [schluessel] dient den Tests.
  const HerleitungsSucheKnopf({
    super.key,
    required this.heroId,
    required this.schluessel,
  });

  /// Held, dessen Werte erklärt werden.
  final String heroId;

  /// Schlüssel der eigentlichen Schaltfläche.
  final Key schluessel;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: schluessel,
      tooltip: 'Berechnungsschritte anzeigen',
      onPressed: () => showHerleitungsSuche(context: context, heroId: heroId),
      icon: const Icon(Icons.info_outline),
    );
  }
}

/// Dialog mit allen erklärbaren Werten des Helden und einer Suche über
/// Wertnamen, Schritte, Quellen und Formeln.
///
/// Zeigt den gespeicherten Stand aus `heroComputedProvider`; die Einträge
/// stammen aus `sammleHerleitungen`, die Suche aus `filtereHerleitungen`.
class HerleitungsSucheDialog extends ConsumerStatefulWidget {
  /// Erzeugt den Dialog für [heroId].
  const HerleitungsSucheDialog({super.key, required this.heroId});

  /// Held, dessen Werte erklärt werden.
  final String heroId;

  @override
  ConsumerState<HerleitungsSucheDialog> createState() =>
      _HerleitungsSucheDialogState();
}

class _HerleitungsSucheDialogState
    extends ConsumerState<HerleitungsSucheDialog> {
  String _suche = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = ref.watch(heroComputedProvider(widget.heroId)).valueOrNull;
    final Widget inhalt;
    if (snapshot == null) {
      inhalt = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      inhalt = _Trefferliste(
        eintraege: filtereHerleitungen(_alleEintraege(snapshot), _suche),
        aufgeklappt: _suche.trim().isNotEmpty,
      );
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Berechnungsschritte',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Woher sich jeder Wert bestimmt (gespeicherter Stand).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                key: const ValueKey<String>('herleitung-suche-feld'),
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Wert, Quelle oder Schritt suchen …',
                ),
                onChanged: (wert) => setState(() => _suche = wert),
              ),
            ),
            Flexible(child: inhalt),
          ],
        ),
      ),
    );
  }

  List<HerleitungsEintrag> _alleEintraege(HeroComputedSnapshot snapshot) {
    return sammleHerleitungen(
      eigenschaften: snapshot.eigenschaftHerleitungen,
      basiswerte: snapshot.derivedStats.herleitungen,
      kampf: snapshot.combatPreviewStats,
      astral: snapshot.resourceActivation.magic.isEnabled,
      karmal: snapshot.resourceActivation.divine.isEnabled,
    );
  }
}

class _Trefferliste extends StatelessWidget {
  const _Trefferliste({required this.eintraege, required this.aufgeklappt});

  final List<HerleitungsEintrag> eintraege;

  /// Bei einer Suche stehen die Treffer offen, sonst nur die Köpfe.
  final bool aufgeklappt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (eintraege.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Kein Wert gefunden.', textAlign: TextAlign.center),
      );
    }
    final kinder = <Widget>[];
    HerleitungsBereich? letzterBereich;
    for (final eintrag in eintraege) {
      if (eintrag.bereich != letzterBereich) {
        letzterBereich = eintrag.bereich;
        kinder.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              eintrag.bereich.anzeige,
              style: theme.textTheme.labelLarge,
            ),
          ),
        );
      }
      kinder.add(
        ExpansionTile(
          // Der Schlüssel enthält den Aufklappzustand, damit eine neue Suche
          // die Treffer öffnet und das Leeren sie wieder schließt.
          key: ValueKey<String>(
            'herleitung-eintrag-${eintrag.id}-$aufgeklappt',
          ),
          initiallyExpanded: aufgeklappt,
          dense: true,
          title: Text(eintrag.titel),
          trailing: Text(
            '= ${eintrag.ergebnisText}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(32, 0, 16, 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [HerleitungsSchritte(herleitung: eintrag.herleitung)],
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: kinder,
    );
  }
}
