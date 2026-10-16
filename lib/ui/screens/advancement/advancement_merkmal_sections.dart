import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_merkmalskenntnis_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_trait_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_acquisition_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Kompakte Kachel für Vor-/Nachteile und Merkmalskenntnisse.
class AdvancementMerkmalKachel extends StatelessWidget {
  /// Zeigt nur bereits aufgelöste Regelwerte.
  const AdvancementMerkmalKachel({
    super.key,
    required this.titel,
    required this.aktion,
    required this.onAktion,
    this.zeilen = const [],
    this.sperrgrund,
    this.planned = false,
    this.erworben = false,
    this.aktionsKey,
  });

  /// Name des Eintrags.
  final String titel;

  /// Weitere Angaben (Bestand, Kosten, Regelhinweis).
  final List<String> zeilen;

  /// Beschriftung des Knopfs.
  final String aktion;

  /// Plant den Schritt; `null` sperrt den Knopf.
  final VoidCallback? onAktion;

  /// Warum der Schritt gerade nicht möglich ist.
  final String? sperrgrund;

  /// Ob der Eintrag in dieser Runde vorgemerkt ist.
  final bool planned;

  /// Ob der Held den Eintrag bereits führt; dann gibt es keinen Knopf.
  final bool erworben;

  /// Testschlüssel des Knopfs.
  final Key? aktionsKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inhalt = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final zeile in zeilen)
          Text(zeile, style: theme.textTheme.bodySmall),
        if (planned)
          Text(
            'Geplant',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        if (sperrgrund != null && !erworben)
          Text(sperrgrund!, style: theme.textTheme.bodySmall),
        if (!erworben) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            key: aktionsKey,
            onPressed: sperrgrund == null ? onAktion : null,
            child: Text(aktion),
          ),
        ],
      ],
    );
    return kartoVariante(context) != null
        ? KartoFlaeche(innen: const EdgeInsets.all(12), child: inhalt)
        : Card(
            margin: EdgeInsets.zero,
            child: Padding(padding: const EdgeInsets.all(12), child: inhalt),
          );
  }
}

/// Verteilt Kacheln auf Spalten gleicher Breite.
class AdvancementKachelRaster extends StatelessWidget {
  /// Legt die Mindestbreite je Spalte fest.
  const AdvancementKachelRaster({
    super.key,
    required this.kinder,
    this.mindestBreite = 260,
  });

  /// Kacheln in Anzeigereihenfolge.
  final List<Widget> kinder;

  /// Mindestbreite einer Spalte vor Textskalierung.
  final double mindestBreite;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final spalten = math.max(
        1,
        (constraints.maxWidth / (mindestBreite * scale)).floor(),
      );
      final breite = (constraints.maxWidth - (spalten - 1) * 10) / spalten;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final kind in kinder) SizedBox(width: breite, child: kind),
        ],
      );
    },
  );
}

String _ap(AdvancementOption option) =>
    option.apCost == null ? 'Kosten nach GP-Wert' : '${option.apCost} AP';

/// Nachträglich erwerbbare Vorteile bzw. abbaubare Nachteile des Helden.
class AdvancementMerkmalSection extends StatelessWidget {
  /// Zeigt [options] einer Merkmalsart; geplant wird über [onPlan].
  const AdvancementMerkmalSection({
    super.key,
    required this.session,
    required this.options,
    required this.vorteile,
    required this.onPlan,
  });

  /// Laufende Runde für Vormerkungen.
  final AdvancementSession session;

  /// Bereits gefilterte Optionen der Merkmalsart.
  final List<AdvancementOption> options;

  /// `true` für Vorteile, `false` für Nachteile.
  final bool vorteile;

  /// Öffnet den Planungsdialog; `null` während eines Dialogs.
  final ValueChanged<AdvancementOption>? onPlan;

  bool _geplant(AdvancementOption option) => session.entries.any(
    (entry) =>
        entry.kind == option.kind &&
        entry.targetId == option.targetId &&
        (option.kind == AdvancementKind.advantage ||
            entry.options[kMerkmalOptionEintrag] ==
                option.options[kMerkmalOptionEintrag]),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final eintraege = [...options]
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          vorteile
              ? 'Nur diese Vorteile lassen sich nach der Erschaffung erwerben: '
                    '50 × GP-Wert in AP, in Absprache mit dem Meister '
                    '(Wege des Schwerts S. 170).'
              : 'Körperliche und geistige Nachteile kosten 100 × GP-Wert, '
                    'Schlechte Eigenschaften je Punkt 50 × GP (Spezielle '
                    'Erfahrung) bzw. 75 × GP (Selbststudium). '
                    'Gesellschaftliche Nachteile werden im Spiel abgebaut '
                    '(Wege des Schwerts S. 170).',
          style: muted,
        ),
        const SizedBox(height: 12),
        if (eintraege.isEmpty)
          Center(
            key: ValueKey(
              'advancement-empty-${vorteile ? 'vorteile' : 'nachteile'}',
            ),
            child: Text(
              vorteile
                  ? 'Keine passenden Vorteile.'
                  : 'Keine katalogisierten Nachteile auf dem Heldenbogen.',
            ),
          )
        else
          AdvancementKachelRaster(
            kinder: [
              for (final option in eintraege)
                vorteile ? _vorteilKachel(option) : _nachteilKachel(option),
            ],
          ),
      ],
    );
  }

  Widget _vorteilKachel(AdvancementOption option) {
    final wirksam = gleicheMerkmaleAb(
      session.preview,
      katalog: MerkmalKatalog.von(session.catalog),
    ).vorteile;
    final bestand = [
      for (final eintrag in wirksam)
        if (eintrag.katalogId == option.targetId) eintrag.text,
    ];
    final wertbar = option.maxValue > 0;
    return AdvancementMerkmalKachel(
      key: ValueKey('advancement-trait-${option.targetId}'),
      titel: option.label,
      zeilen: [
        if (bestand.isNotEmpty) 'Vorhanden: ${bestand.join(', ')}',
        'Nächster Schritt: ${_ap(option)}',
        if (option.complexityHint != null) option.complexityHint!,
      ],
      aktion: option.isOwned
          ? (wertbar ? 'Ausbauen' : 'Weitere erwerben')
          : 'Erwerben',
      planned: _geplant(option),
      sperrgrund: option.unavailableReason,
      onAktion: onPlan == null ? null : () => onPlan!(option),
      aktionsKey: ValueKey('advancement-plan-advantage-${option.targetId}'),
    );
  }

  Widget _nachteilKachel(AdvancementOption option) {
    final text = option.options[kMerkmalOptionEintrag] ?? option.label;
    return AdvancementMerkmalKachel(
      key: ValueKey('advancement-trait-$text'),
      titel: option.label,
      zeilen: [
        if (option.unavailableReason == null)
          'Nächster Schritt: ${_ap(option)}',
        if (option.complexityHint != null) option.complexityHint!,
      ],
      aktion: option.maxValue > 0 ? 'Senken oder abbauen' : 'Abbauen',
      planned: _geplant(option),
      sperrgrund: option.unavailableReason,
      onAktion: onPlan == null ? null : () => onPlan!(option),
      aktionsKey: ValueKey('advancement-plan-disadvantage-$text'),
    );
  }
}

/// Merkmalskenntnisse nach Klassifikation (Wege der Helden S. 289).
class AdvancementMerkmalskenntnisSection extends StatelessWidget {
  /// Zeigt je Merkmal den Bestand und den möglichen Erwerb.
  const AdvancementMerkmalskenntnisSection({
    super.key,
    required this.session,
    required this.options,
    required this.onPlan,
  });

  /// Laufende Runde für Vormerkungen.
  final AdvancementSession session;

  /// Merkmalskenntnis-Optionen, bereits nach Suche gefiltert.
  final List<AdvancementOption> options;

  /// Öffnet den Erwerbsdialog; `null` während eines Dialogs.
  final ValueChanged<AdvancementOption>? onPlan;

  String _merkmal(AdvancementOption option) =>
      option.options[kMerkmalskenntnisOptionMerkmal] ?? '';

  bool _geplant(String merkmal) => session.entries.any(
    (entry) =>
        entry.options['action'] == kMerkmalskenntnisAktion &&
        entry.options[kMerkmalskenntnisOptionMerkmal] == merkmal,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bekannt = session.base.merkmalskenntnisse;
    final offen = options
        .where((option) => option.unavailableReason == null)
        .firstOrNull;
    final gruppen = <int, List<AdvancementOption>>{};
    for (final option in options) {
      (gruppen[merkmalsklassifikation(_merkmal(option))] ??= []).add(option);
    }
    final hinweise = offen == null
        ? const <RequirementCheckResult>[]
        : offen.requirements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          bekannt.isEmpty
              ? 'Noch keine Merkmalskenntnis. Die erste ist bei vielen '
                    'Professionen enthalten (dann 0 AP eintragen).'
              : 'Bekannt: ${bekannt.join(', ')}',
          style: theme.textTheme.bodyMedium,
        ),
        for (final befund in hinweise)
          Text(
            '${befund.istOffen ? 'Offen' : 'Erfüllt'}: ${befund.sollText}'
            '${befund.istText.isEmpty ? '' : ' (${befund.istText})'}',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        for (final stufe in const [1, 2, 3])
          if (gruppen[stufe] case final liste?) ...[
            Text(
              'Klassifikation ${'I' * stufe} · '
              '${merkmalskenntnisApCost(liste.isEmpty ? '' : _merkmal(liste.first))} AP',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            AdvancementKachelRaster(
              mindestBreite: 200,
              kinder: [
                for (final option in liste)
                  AdvancementMerkmalKachel(
                    key: ValueKey('advancement-merkmal-${_merkmal(option)}'),
                    titel: _merkmal(option),
                    zeilen: [
                      if (option.isOwned && !_geplant(_merkmal(option)))
                        'Bekannt',
                    ],
                    aktion: 'Erwerben',
                    erworben: option.isOwned && !_geplant(_merkmal(option)),
                    planned: _geplant(_merkmal(option)),
                    sperrgrund: _geplant(_merkmal(option))
                        ? null
                        : option.unavailableReason,
                    onAktion: onPlan == null || _geplant(_merkmal(option))
                        ? null
                        : () => onPlan!(option),
                    aktionsKey: ValueKey(
                      'advancement-plan-merkmal-${_merkmal(option)}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}
