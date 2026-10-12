import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_migration_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/hero_herkunft_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';

/// Die Herkunftsmodifikatoren einer Gruppe (Rasse, Kultur oder Profession).
///
/// Zeigt die strukturierten Einträge der Gruppe als Chips und, im
/// Bearbeitungsmodus, das Hinzufügen, Ändern und Entfernen. Das Widget rechnet
/// nichts: Liste, Abweichung und Sperren kommen aus den Regeln in
/// `hero_herkunft_migration_rules.dart`; Änderungen meldet es nur über
/// [onEintraegeChanged] und [onAbgleich], geschrieben wird beim Aufrufer. Ein
/// Abbruch eines Dialogs ruft keinen Callback.
class HeroHerkunftSection extends StatelessWidget {
  /// Erstellt die Section.
  const HeroHerkunftSection({
    super.key,
    required this.herkunft,
    required this.background,
    required this.bearbeitbar,
    required this.onEintraegeChanged,
    required this.onAbgleich,
    this.vorBearbeiten,
  });

  /// Gezeigte Gruppe.
  final HeroHerkunft herkunft;

  /// Stand (gespeichert oder Entwurf), aus dem die Section liest.
  final HeroBackground background;

  /// Ob gerade bearbeitet werden darf.
  final bool bearbeitbar;

  /// Meldet die neue, vollständige Liste der Gruppe.
  final ValueChanged<List<HeroHerkunftsModifikator>> onEintraegeChanged;

  /// Meldet die Entscheidung bei einer Textabweichung.
  final ValueChanged<HerkunftsAbgleichWahl> onAbgleich;

  /// Prueft vor jeder Bearbeitung (Dialog oeffnen, Entfernen), ob sie
  /// erlaubt ist, etwa wegen einer offenen Planung. Bei `false` kehrt die
  /// Section sofort zurueck und ruft keinen Callback.
  final Future<bool> Function()? vorBearbeiten;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = herkunftBezeichnung(herkunft);
    final abgleich = gleicheHerkunftAb(background);
    final container = abgleich.eintraege;
    final abweichung = abgleich.abweichungen[herkunft];
    final gruppeOffen = container.istGruppeBearbeitbar(herkunft);
    final aenderbar = bearbeitbar && gruppeOffen && abweichung == null;
    final eintraege = container.eintraegeFuer(herkunft);

    return Column(
      key: ValueKey<String>('herkunft-${herkunft.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$name Modifikatoren', style: theme.textTheme.titleSmall),
            if (bearbeitbar)
              TextButton(
                key: ValueKey<String>('herkunft-add-${herkunft.name}'),
                onPressed: aenderbar
                    ? () => _hinzufuegen(context, eintraege)
                    : null,
                child: const Text('+ Herkunftsmodifikator'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!gruppeOffen) ...[
          Text(
            _sperrgrund(container),
            key: ValueKey<String>('herkunft-gesperrt-${herkunft.name}'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
        if (abweichung != null) ...[
          _Abweichung(
            herkunft: herkunft,
            abweichung: abweichung,
            bearbeitbar: bearbeitbar,
            onAbgleich: onAbgleich,
          ),
          const SizedBox(height: 8),
        ],
        if (container.istUnverstanden)
          _kompatibilitaetsText(theme)
        else if (eintraege.isEmpty)
          Text('Keine Einträge', style: theme.textTheme.bodyMedium)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < eintraege.length; index++)
                _chip(context, eintraege, index, aenderbar: aenderbar),
            ],
          ),
      ],
    );
  }

  // Bei unlesbarem Container nur der Text, der weiter gilt.
  Widget _kompatibilitaetsText(ThemeData theme) {
    final text = herkunftsTextVon(background, herkunft).trim();
    return Text(
      text.isEmpty ? 'Keine Einträge' : text,
      key: ValueKey<String>('herkunft-text-${herkunft.name}'),
      style: theme.textTheme.bodyMedium,
    );
  }

  String _sperrgrund(HeroHerkunftsModifikatoren container) {
    if (container.istUnverstanden) {
      return 'Diese Herkunftsdaten stammen aus einer neueren App-Version. '
          'Sie bleiben unverändert erhalten, lassen sich hier aber nicht '
          'bearbeiten; es gilt der Text.';
    }
    return 'Einzelne Einträge dieser Gruppe sind nicht lesbar oder doppelt. '
        'Sie bleiben unverändert erhalten; Bearbeiten ist gesperrt.';
  }

  Widget _chip(
    BuildContext context,
    List<HeroHerkunftsModifikator> eintraege,
    int index, {
    required bool aenderbar,
  }) {
    final eintrag = eintraege[index];
    if (eintrag.istUnverstanden) {
      return const Chip(
        label: Text('Nicht lesbarer Eintrag'),
        avatar: Icon(Icons.help_outline, size: 16),
        visualDensity: VisualDensity.compact,
      );
    }
    final label = Text(eintrag.text.isEmpty ? eintrag.id : eintrag.text);
    if (!aenderbar) {
      return Chip(label: label, visualDensity: VisualDensity.compact);
    }
    return InputChip(
      key: ValueKey<String>('herkunft-chip-${herkunft.name}-$index'),
      label: label,
      visualDensity: VisualDensity.compact,
      onPressed: () => _aendern(context, eintraege, index),
      onDeleted: () async {
        if (!await _darfBearbeiten()) {
          return;
        }
        onEintraegeChanged(
          List<HeroHerkunftsModifikator>.of(eintraege)..removeAt(index),
        );
      },
    );
  }

  Future<bool> _darfBearbeiten() async {
    final pruefung = vorBearbeiten;
    return pruefung == null || await pruefung();
  }

  Future<void> _hinzufuegen(
    BuildContext context,
    List<HeroHerkunftsModifikator> eintraege,
  ) async {
    if (!await _darfBearbeiten() || !context.mounted) {
      return;
    }
    final neu = await zeigeHerkunftsEintragDialog(
      context: context,
      herkunftName: herkunftBezeichnung(herkunft),
    );
    if (neu == null) {
      return;
    }
    onEintraegeChanged(<HeroHerkunftsModifikator>[...eintraege, neu]);
  }

  Future<void> _aendern(
    BuildContext context,
    List<HeroHerkunftsModifikator> eintraege,
    int index,
  ) async {
    if (!await _darfBearbeiten() || !context.mounted) {
      return;
    }
    final ersatz = await zeigeHerkunftsEintragDialog(
      context: context,
      herkunftName: herkunftBezeichnung(herkunft),
      bisher: eintraege[index],
    );
    if (ersatz == null) {
      return;
    }
    onEintraegeChanged(
      List<HeroHerkunftsModifikator>.of(eintraege)..[index] = ersatz,
    );
  }
}

/// Hinweis auf eine Textänderung durch eine ältere App-Version.
class _Abweichung extends StatelessWidget {
  const _Abweichung({
    required this.herkunft,
    required this.abweichung,
    required this.bearbeitbar,
    required this.onAbgleich,
  });

  final HeroHerkunft herkunft;
  final HerkunftsTextAbweichung abweichung;
  final bool bearbeitbar;
  final ValueChanged<HerkunftsAbgleichWahl> onAbgleich;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey<String>('herkunft-abweichung-${herkunft.name}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(kartoRadiusOder(context, 8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eine ältere App-Version hat den Text dieser Modifikatoren '
            'geändert. Wirksam bleibt die Liste, bis du entscheidest.',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            'Text: ${abweichung.text.isEmpty ? '–' : abweichung.text}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'Liste: ${abweichung.listenText.isEmpty ? '–' : abweichung.listenText}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (!bearbeitbar)
            Text(
              'Zum Entscheiden in den Bearbeitungsmodus wechseln.',
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: ValueKey<String>(
                    'herkunft-text-uebernehmen-${herkunft.name}',
                  ),
                  onPressed: () =>
                      onAbgleich(HerkunftsAbgleichWahl.textUebernehmen),
                  child: const Text('Geänderten Text übernehmen'),
                ),
                OutlinedButton(
                  key: ValueKey<String>(
                    'herkunft-liste-behalten-${herkunft.name}',
                  ),
                  onPressed: () =>
                      onAbgleich(HerkunftsAbgleichWahl.listeBehalten),
                  child: const Text('Liste behalten'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
