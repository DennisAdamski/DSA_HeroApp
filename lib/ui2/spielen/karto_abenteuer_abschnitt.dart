import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_karten.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_sortierung.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_kartenraster.dart';

/// Laufendes Abenteuer in der Spielansicht: die obersten Personen und Notizen.
///
/// Rein darstellend. Gepflegt wird im Abenteuerblatt; jede Karte und der
/// Kopfknopf öffnen es über [onOeffnen]. Die Zusammenfassung steht bereits im
/// Seitenkopf und wird hier nicht wiederholt.
class KartoAbenteuerAbschnitt extends StatelessWidget {
  /// Erstellt den Abschnitt für [abenteuer].
  const KartoAbenteuerAbschnitt({
    super.key,
    required this.abenteuer,
    required this.sortierung,
    required this.onOeffnen,
  });

  /// Das laufende Abenteuer.
  final HeroAdventureEntry abenteuer;

  /// Reihenfolge von Personen und Notizen.
  final AbenteuerSortierung sortierung;

  /// Öffnet das Abenteuerblatt.
  final VoidCallback onOeffnen;

  /// Höchstzahl gezeigter Personen.
  static const int maxPersonen = 3;

  /// Höchstzahl gezeigter Notizen.
  static const int maxNotizen = 4;

  @override
  Widget build(BuildContext context) {
    final personen = abenteuer.people;
    final notizen = abenteuer.notes;
    final personenfolge = sortierePersonen(
      personen,
      sortierung,
    ).take(maxPersonen);
    final notizfolge = sortiereNotizen(notizen, sortierung).take(maxNotizen);

    return KartoAbschnitt(
      titel: 'Abenteuer',
      symbol: Icons.explore_outlined,
      akzent: KartoAkzent.messing,
      aktion: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Abstand.knapp,
        children: [
          const KartoAbenteuerSortierwahl(),
          TextButton(
            key: const ValueKey<String>('karto-spiel-abenteuer-oeffnen'),
            onPressed: onOeffnen,
            child: const Text('Öffnen'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (personen.isEmpty && notizen.isEmpty)
            Text(
              'Noch keine Notizen oder Personen.',
              style: Theme.of(context).textTheme.fliess
                  .copyWith(color: context.karto.schriftLeise),
            ),
          if (personen.isNotEmpty) ...[
            _Zwischenzeile(titel: 'Personen', anzahl: personen.length),
            const SizedBox(height: Abstand.normal),
            KartoKartenraster(
              mindestbreite: 200,
              kinder: [
                for (final i in personenfolge)
                  KartoFigurenkarte(
                    name: personen[i].name,
                    beschreibung: personen[i].description,
                    onTap: onOeffnen,
                  ),
              ],
            ),
          ],
          if (personen.isNotEmpty && notizen.isNotEmpty)
            const SizedBox(height: Abstand.block),
          if (notizen.isNotEmpty) ...[
            _Zwischenzeile(titel: 'Notizen', anzahl: notizen.length),
            const SizedBox(height: Abstand.normal),
            KartoKartenraster(
              mindestbreite: 260,
              kinder: [
                for (final i in notizfolge)
                  KartoNotizkarte(
                    titel: notizen[i].title,
                    text: notizen[i].description,
                    onTap: onOeffnen,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Leise Zwischenzeile mit Gesamtanzahl.
class _Zwischenzeile extends StatelessWidget {
  const _Zwischenzeile({required this.titel, required this.anzahl});

  final String titel;
  final int anzahl;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$titel · $anzahl',
      style: Theme.of(context).textTheme.etikett
          .copyWith(color: context.karto.schriftLeise),
    );
  }
}
