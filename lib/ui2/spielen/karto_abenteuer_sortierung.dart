import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Anzeigereihenfolge der Notizen als Indizes in [notizen].
///
/// Indizes statt sortierter Kopien: das Abenteuerblatt prüft beim Bearbeiten
/// den Originalindex gegen den frisch geladenen Stand.
List<int> sortiereNotizen(
  List<HeroNoteEntry> notizen,
  AbenteuerSortierung sortierung,
) => _sortiere([
  for (final n in notizen) (zeit: n.lastModified, text: n.title),
], sortierung);

/// Anzeigereihenfolge der Personen als Indizes in [personen].
List<int> sortierePersonen(
  List<HeroAdventurePersonEntry> personen,
  AbenteuerSortierung sortierung,
) => _sortiere([
  for (final p in personen) (zeit: p.lastModified, text: p.name),
], sortierung);

/// Kurze Beschriftung eines Sortiermodus.
String sortierungsName(AbenteuerSortierung sortierung) => switch (sortierung) {
  AbenteuerSortierung.zuletztBearbeitet => 'Zuletzt bearbeitet',
  AbenteuerSortierung.neuesteZuerst => 'Neueste zuerst',
  AbenteuerSortierung.aeltesteZuerst => 'Älteste zuerst',
  AbenteuerSortierung.alphabetisch => 'Alphabetisch',
};

typedef _Eintrag = ({DateTime? zeit, String text});

List<int> _sortiere(List<_Eintrag> eintraege, AbenteuerSortierung sortierung) {
  final indizes = List<int>.generate(eintraege.length, (i) => i);
  switch (sortierung) {
    case AbenteuerSortierung.aeltesteZuerst:
      return indizes;
    case AbenteuerSortierung.neuesteZuerst:
      return indizes.reversed.toList();
    case AbenteuerSortierung.zuletztBearbeitet:
      // Bestandseinträge ohne Zeitstempel folgen den gestempelten, unter sich
      // die zuletzt erfassten zuerst.
      indizes.sort((a, b) {
        final za = eintraege[a].zeit;
        final zb = eintraege[b].zeit;
        if (za != null && zb != null) {
          final vergleich = zb.compareTo(za);
          return vergleich != 0 ? vergleich : b.compareTo(a);
        }
        if (za != null) return -1;
        if (zb != null) return 1;
        return b.compareTo(a);
      });
      return indizes;
    case AbenteuerSortierung.alphabetisch:
      final schluessel = [
        for (final e in eintraege) vergleichsschluessel(e.text),
      ];
      indizes.sort((a, b) {
        // Leere Titel ans Ende, sonst stünden „Ohne Titel“-Karten vorn.
        final leerA = schluessel[a].isEmpty;
        final leerB = schluessel[b].isEmpty;
        if (leerA != leerB) return leerA ? 1 : -1;
        final vergleich = schluessel[a].compareTo(schluessel[b]);
        return vergleich != 0 ? vergleich : a.compareTo(b);
      });
      return indizes;
  }
}

/// Vergleichsform eines Textes: Umlaute wie ihre Grundbuchstaben, damit „Ärger“
/// neben „Ast“ steht und die Suche „Ärger“ auch „aerger“ nicht verfehlt.
String vergleichsschluessel(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ß', 'ss');

/// Leise Auswahl der Reihenfolge von Notizen und Personen.
///
/// Die Wahl ist eine Geräteeinstellung und schreibt nie den Helden; sie gilt
/// im Abenteuerblatt und im Abenteuerabschnitt der Spielansicht zugleich.
class KartoAbenteuerSortierwahl extends ConsumerWidget {
  /// Erstellt die Auswahl.
  const KartoAbenteuerSortierwahl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aktuell = ref.watch(abenteuerSortierungProvider);
    final karto = context.karto;
    return PopupMenuButton<AbenteuerSortierung>(
      key: const ValueKey<String>('karto-abenteuer-sortierung'),
      tooltip: 'Sortierung',
      initialValue: aktuell,
      onSelected: (wert) => _waehle(context, ref, wert),
      itemBuilder: (_) => [
        for (final wert in AbenteuerSortierung.values)
          PopupMenuItem(value: wert, child: Text(sortierungsName(wert))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Abstand.normal,
          vertical: Abstand.knapp,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 18, color: karto.meer),
            const SizedBox(width: Abstand.knapp),
            Flexible(
              child: Text(
                sortierungsName(aktuell),
                style: Theme.of(context).textTheme.etikett
                    .copyWith(color: karto.meer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _waehle(
    BuildContext context,
    WidgetRef ref,
    AbenteuerSortierung wert,
  ) async {
    final meldung = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(settingsActionsProvider).setAbenteuerSortierung(wert);
    } catch (error) {
      meldung?.showSnackBar(
        SnackBar(content: Text('Sortierung nicht gespeichert: $error')),
      );
    }
  }
}
