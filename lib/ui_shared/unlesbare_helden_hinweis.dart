import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/unlesbare_helden_quelle.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Hinweis auf gespeicherte Helden, die diese App-Version nicht lesen kann.
///
/// Ohne betroffene Einträge nimmt der Baustein keinen Platz ein. Er verändert
/// nichts am Speicher: die Rohdaten bleiben liegen, damit eine spätere
/// Version oder eine Reparatur sie lesen kann.
class UnlesbareHeldenHinweis extends ConsumerWidget {
  /// Erstellt den Hinweis; [rahmen] ersetzt die Standardkarte.
  const UnlesbareHeldenHinweis({super.key, this.rahmen});

  /// Fasst den Inhalt in die Fläche der jeweiligen Oberfläche.
  final Widget Function(Widget inhalt)? rahmen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eintraege = ref.watch(unlesbareHeldenProvider);
    if (eintraege.isEmpty) {
      return const SizedBox.shrink();
    }
    final inhalt = UnlesbareHeldenInhalt(eintraege: eintraege);
    final rahmen = this.rahmen;
    if (rahmen != null) {
      return KeyedSubtree(
        key: const ValueKey('unlesbare-helden-hinweis'),
        child: rahmen(inhalt),
      );
    }
    return Card(
      key: const ValueKey('unlesbare-helden-hinweis'),
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: inhalt),
    );
  }
}

/// Text und Liste des Hinweises ohne eigene Fläche.
class UnlesbareHeldenInhalt extends StatelessWidget {
  /// Beschreibt die übersprungenen [eintraege].
  const UnlesbareHeldenInhalt({super.key, required this.eintraege});

  /// Übersprungene Einträge, mindestens einer.
  final List<UnlesbarerHeld> eintraege;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final texte = theme.textTheme;
    final anzahl = eintraege.length;
    final titel = anzahl == 1
        ? 'Ein gespeicherter Held kann nicht gelesen werden'
        : '$anzahl gespeicherte Helden können nicht gelesen werden';
    final namen = eintraege.map((eintrag) => eintrag.anzeigename).join(', ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.report_problem_outlined, color: theme.colorScheme.error),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titel, style: texte.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Betroffen: $namen. Die Daten bleiben unverändert gespeichert '
                'und sind nur ausgeblendet. Eine neuere App-Version kann sie '
                'möglicherweise wieder lesen.',
                style: texte.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
