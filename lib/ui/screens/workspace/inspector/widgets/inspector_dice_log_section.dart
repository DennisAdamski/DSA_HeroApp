import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/zuletzt_gewuerfelt_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/dice_log_abende.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Filtergruppen fuer das Wuerfelprotokoll.
///
/// Fasst die feingranularen [ProbeType]-Werte zu spielrelevanten Gruppen
/// zusammen, damit die Chip-Leiste kompakt bleibt.
enum DiceLogFilter {
  /// Alle Eintraege ohne Einschraenkung.
  all('Alle'),

  /// Eigenschaftsproben (1W20).
  attribute('Eigenschaft'),

  /// Talentproben (3W20).
  talent('Talent'),

  /// Zauberproben (3W20).
  spell('Zauber'),

  /// Kampfbezogene Wuerfe (AT, PA, Ausweichen, INI, Schaden).
  combat('Kampf');

  const DiceLogFilter(this.label);

  /// Anzeigename des Filters auf dem Chip.
  final String label;

  /// Prueft, ob ein Protokolleintrag zur Filtergruppe gehoert.
  bool matches(DiceLogEntry entry) {
    switch (this) {
      case DiceLogFilter.all:
        return true;
      case DiceLogFilter.attribute:
        return entry.type == ProbeType.attribute;
      case DiceLogFilter.talent:
        return entry.type == ProbeType.talent;
      case DiceLogFilter.spell:
        return entry.type == ProbeType.spell;
      case DiceLogFilter.combat:
        return entry.type == ProbeType.combatAttack ||
            entry.type == ProbeType.combatParry ||
            entry.type == ProbeType.dodge ||
            entry.type == ProbeType.initiative ||
            entry.type == ProbeType.damage;
    }
  }
}

/// Ob sich ein Protokolleintrag über die Probensuche wiederholen lässt.
///
/// Nur die Proben, die die Probensuche selbst erzeugt: Eigenschafts-, Talent-
/// und Zauberproben sowie die Kampf-Schnellproben. Schaden, Rast, Gefechts-
/// aufträge, Summenwürfe und Buchungen haben keinen eigenen Probendialog.
bool diceLogEntryKannWiederholtWerden(DiceLogEntry entry) =>
    probeEintragIstWiederholbar(entry);

/// Liste der zuletzt protokollierten Wuerfelproben mit Filter-Chips.
///
/// Erwartet die Eintraege in chronologischer Reihenfolge (aelteste zuerst,
/// neueste am Ende der Liste – wie sie der `HeroState.diceLog` haelt).
/// Die Anzeige dreht das intern um, damit der neueste Eintrag oben steht.
/// Liegen Würfe aus mehreren Spielabenden vor (Pause von mehr als sechs
/// Stunden), stehen Überschriften zwischen den Abenden; bei einem einzigen
/// Abend bleibt die Liste ohne Überschrift wie bisher.
class InspectorDiceLogSection extends StatefulWidget {
  /// Erzeugt die Protokoll-Sektion fuer die uebergebenen Eintraege.
  const InspectorDiceLogSection({
    super.key,
    required this.entries,
    this.aktion,
    this.onWiederholen,
    this.jetzt,
    this.hoechstens,
    this.tabellarisch = false,
  });

  /// Zeigt jeden Wurf als Tabellenzeile (Zeit, Probe, Würfe, Ziel, Ergebnis)
  /// statt als Karte, mit Kopfzeile. Nur bei genug Platz: unter
  /// [tabellenBreiteMin] dp Breite oder bei stark vergrößerter Schrift bleibt
  /// es bei den Karten. Für die weite Kachel der Spielansicht; Standard ist
  /// die Karte.
  final bool tabellarisch;

  /// Mindestbreite, ab der [tabellarisch] wirkt.
  static const double tabellenBreiteMin = 520;

  /// Größte Schriftskalierung, bei der [tabellarisch] noch wirkt.
  static const double tabellenSchriftMax = 1.3;

  /// Zeigt nur die neuesten so vielen Würfe und keine Filter; `null` zeigt
  /// alles. Für die knappe Fassung auf der Spielansicht, die das vollständige
  /// Protokoll eigens öffnet.
  final int? hoechstens;

  /// Protokolleintraege in chronologischer Reihenfolge.
  final List<DiceLogEntry> entries;

  /// Optionale Aktion je Eintrag (etwa „Zurücknehmen“ einer
  /// Schadensbuchung); `null` heißt: keine. Die Sektion selbst schreibt nie.
  final Widget? Function(DiceLogEntry entry)? aktion;

  /// Würfelt die Probe eines Eintrags nochmal; `null` blendet den Knopf aus.
  /// Der Knopf erscheint nur an Einträgen, für die
  /// [diceLogEntryKannWiederholtWerden] gilt. Die Sektion selbst würfelt nie.
  final Future<void> Function(DiceLogEntry entry)? onWiederholen;

  /// Zeitpunkt für „Heute“ und „Gestern“; ohne Angabe die aktuelle Zeit. Für
  /// Tests ersetzbar.
  final DateTime? jetzt;

  @override
  State<InspectorDiceLogSection> createState() =>
      _InspectorDiceLogSectionState();
}

class _InspectorDiceLogSectionState extends State<InspectorDiceLogSection> {
  DiceLogFilter _filter = DiceLogFilter.all;

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Noch keine Würfe protokolliert.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Die Abende stehen fest, bevor gefiltert wird: ein Filter darf keine
    // Pause verschlucken und zwei Abende zu einem machen.
    final abende = gruppiereNachSpielabend(widget.entries).reversed.toList();
    final mitUeberschrift = abende.length > 1;
    final jetzt = widget.jetzt ?? DateTime.now();
    final grenze = widget.hoechstens;
    // Knapp gibt es keinen Filter: die neuesten Würfe, gleich welcher Art.
    final filter = grenze == null ? _filter : DiceLogFilter.all;
    var rest = grenze ?? widget.entries.length;
    final gefiltert = [
      for (final abend in abende)
        (
          abend: abend,
          eintraege: () {
            final neueste = abend.eintraege
                .where(filter.matches)
                .toList(growable: false)
                .reversed
                .take(rest)
                .toList(growable: false);
            rest -= neueste.length;
            return neueste;
          }(),
        ),
    ].where((gruppe) => gruppe.eintraege.isNotEmpty).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabelle =
            widget.tabellarisch &&
            constraints.maxWidth >= InspectorDiceLogSection.tabellenBreiteMin &&
            MediaQuery.textScalerOf(context).scale(14) <=
                14 * InspectorDiceLogSection.tabellenSchriftMax;
        return _buildListe(context, gefiltert, mitUeberschrift, jetzt, tabelle);
      },
    );
  }

  Widget _buildListe(
    BuildContext context,
    List<({DiceLogAbend abend, List<DiceLogEntry> eintraege})> gefiltert,
    bool mitUeberschrift,
    DateTime jetzt,
    bool tabelle,
  ) {
    final grenze = widget.hoechstens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (grenze == null) ...[_buildFilterChips(), const SizedBox(height: 8)],
        if (tabelle && gefiltert.isNotEmpty) ...[
          const _DiceLogTabellenKopf(),
          const SizedBox(height: 4),
        ],
        if (gefiltert.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Keine Würfe in dieser Kategorie.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        for (final gruppe in gefiltert) ...[
          if (mitUeberschrift)
            _AbendUeberschrift(
              key: ValueKey(
                'dice-log-abend-${gruppe.abend.eintraege.first.timestamp.millisecondsSinceEpoch}',
              ),
              text: diceLogAbendUeberschrift(gruppe.abend.beginn, jetzt),
              anzahl: gruppe.eintraege.length,
            ),
          for (final entry in gruppe.eintraege) ...[
            _eintragszeile(entry, tabelle),
            const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }

  Widget _eintragszeile(DiceLogEntry entry, bool tabelle) {
    final aktion = widget.aktion?.call(entry);
    final onWiederholen =
        widget.onWiederholen != null && diceLogEntryKannWiederholtWerden(entry)
        ? () => widget.onWiederholen!(entry)
        : null;
    return tabelle
        ? _DiceLogTabellenZeile(
            entry: entry,
            aktion: aktion,
            onWiederholen: onWiederholen,
          )
        : _DiceLogEntryRow(
            entry: entry,
            aktion: aktion,
            onWiederholen: onWiederholen,
          );
  }

  /// Baut die Chip-Leiste zur Auswahl der Filtergruppe.
  Widget _buildFilterChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final filter in DiceLogFilter.values)
          ChoiceChip(
            key: ValueKey('dice-log-filter-${filter.name}'),
            label: Text(filter.label),
            visualDensity: VisualDensity.compact,
            selected: _filter == filter,
            onSelected: (_) => setState(() => _filter = filter),
          ),
      ],
    );
  }
}

/// Überschrift eines Spielabends mit der Zahl seiner (gefilterten) Würfe.
class _AbendUeberschrift extends StatelessWidget {
  const _AbendUeberschrift({
    super.key,
    required this.text,
    required this.anzahl,
  });

  final String text;
  final int anzahl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            anzahl == 1 ? '1 Wurf' : '$anzahl Würfe',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiceLogEntryRow extends StatelessWidget {
  const _DiceLogEntryRow({
    required this.entry,
    this.aktion,
    this.onWiederholen,
  });

  final DiceLogEntry entry;
  final Widget? aktion;
  final VoidCallback? onWiederholen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    final ergebnis = _Ergebnis.von(entry, codex);
    final effectiveStripeColor = ergebnis.farbe;
    final effectiveOutcomeLabel = ergebnis.text;
    final effectiveOutcomeColor = ergebnis.farbe;
    final resultDetail = _ergebnisDetail(entry);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: codex.parchment,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: codex.brassMuted, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: effectiveStripeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.subtitle.isNotEmpty)
                      Text(
                        entry.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (resultDetail.isNotEmpty)
                      Text(
                        resultDetail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        // Ziele und TaP* machen die Zeile bei 3W20 länger.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    effectiveOutcomeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: effectiveOutcomeColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    _formatTime(entry.timestamp.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (onWiederholen != null)
                    IconButton(
                      key: ValueKey(
                        'dice-log-wiederholen-${entry.timestamp.millisecondsSinceEpoch}',
                      ),
                      tooltip: 'Nochmal würfeln',
                      onPressed: onWiederholen,
                      icon: const Icon(Icons.replay, size: 18),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ?aktion,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime ts) {
  final hh = ts.hour.toString().padLeft(2, '0');
  final mm = ts.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Streifen- und Ergebnisfarbe samt Kurzwort eines Eintrags.
class _Ergebnis {
  const _Ergebnis(this.text, this.farbe);

  factory _Ergebnis.von(DiceLogEntry entry, CodexTheme codex) {
    if (entry.isNeutral) return _Ergebnis('WURF', codex.brass);
    final farbe = entry.success ? codex.success : codex.danger;
    final text = entry.automaticOutcome == AutomaticOutcome.none
        ? (entry.success ? 'GELUNGEN' : 'MISSLUNGEN')
        : (entry.automaticOutcome == AutomaticOutcome.success
              ? 'AUTO ✓'
              : 'AUTO ✗');
    return _Ergebnis(text, farbe);
  }

  final String text;
  final Color farbe;
}

/// Restpunkte mit ihrem Namen (`TaP*`, `ZfP*`, `Rest`); `null`, wenn der
/// Eintrag keine nennenswerten hat.
String? _restText(DiceLogEntry entry) {
  final rest = entry.restpunkte;
  if (rest == null || !entry.success || rest < 0) return null;
  final name = switch (entry.type) {
    ProbeType.talent => 'TaP*',
    ProbeType.spell => 'ZfP*',
    _ => 'Rest',
  };
  return '$name: $rest';
}

String _ergebnisDetail(DiceLogEntry entry) {
  final parts = <String>[];
  if (entry.diceValues.isNotEmpty) {
    parts.add('Würfe: ${entry.diceValues.join(', ')}');
  }
  final target = entry.targetValue;
  if (entry.zielwerte.length > 1) {
    // Bei 3W20 gehört zu jedem Würfel ein eigener Zielwert.
    parts.add('Ziele: ${entry.zielwerte.join('/')}');
  } else if (target != null) {
    parts.add('Ziel: $target');
  }
  final total = entry.total;
  if (total != null) {
    parts.add('Gesamt: $total');
  }
  final rest = _restText(entry);
  if (rest != null) parts.add(rest);
  return parts.join(' | ');
}

// Spaltenaufteilung der Tabellenansicht; Kopf und Zeilen teilen sie.
const int _spalteProbe = 5;
const int _spalteWuerfe = 3;
const int _spalteZiel = 3;
const int _spalteErgebnis = 4;
const double _spalteZeit = 44;

/// Kopfzeile der Tabellenansicht.
class _DiceLogTabellenKopf extends StatelessWidget {
  const _DiceLogTabellenKopf();

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 0.4,
    );
    Widget kopf(String text, int flex) => Expanded(
      flex: flex,
      child: Text(text, style: stil),
    );
    return Padding(
      // 4 dp Streifen plus 8 dp Innenabstand der Zeilen.
      padding: const EdgeInsets.fromLTRB(13, 0, 9, 0),
      child: Row(
        key: const ValueKey('dice-log-tabellenkopf'),
        children: [
          SizedBox(
            width: _spalteZeit,
            child: Text('Zeit', style: stil),
          ),
          kopf('Probe', _spalteProbe),
          kopf('Würfe', _spalteWuerfe),
          kopf('Ziel', _spalteZiel),
          kopf('Ergebnis', _spalteErgebnis),
        ],
      ),
    );
  }
}

/// Ein Wurf als Tabellenzeile: Zeit, Probe, Würfe, Ziel, Ergebnis.
///
/// Die Knöpfe („Nochmal würfeln“, Aktion) stehen unter dem Ergebnis, damit die
/// Spalten in jeder Zeile gleich breit bleiben.
class _DiceLogTabellenZeile extends StatelessWidget {
  const _DiceLogTabellenZeile({
    required this.entry,
    this.aktion,
    this.onWiederholen,
  });

  final DiceLogEntry entry;
  final Widget? aktion;
  final VoidCallback? onWiederholen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    final ergebnis = _Ergebnis.von(entry, codex);
    final leise = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final ziel = entry.zielwerte.length > 1
        ? entry.zielwerte.join('/')
        : (entry.targetValue?.toString() ?? '–');
    final total = entry.total;
    final rest = _restText(entry);

    return DecoratedBox(
      key: ValueKey('dice-log-zeile-${entry.timestamp.millisecondsSinceEpoch}'),
      decoration: BoxDecoration(
        color: codex.parchment,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: codex.brassMuted, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: ergebnis.farbe,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _spalteZeit,
                      child: Text(
                        _formatTime(entry.timestamp.toLocal()),
                        style: leise,
                      ),
                    ),
                    Expanded(
                      flex: _spalteProbe,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (entry.subtitle.isNotEmpty)
                            Text(
                              entry.subtitle,
                              style: leise,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: _spalteWuerfe,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.diceValues.isEmpty
                                ? '–'
                                : entry.diceValues.join(' · '),
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (total != null)
                            Text('Gesamt: $total', style: leise),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: _spalteZiel,
                      child: Text(ziel, style: theme.textTheme.bodyMedium),
                    ),
                    Expanded(
                      flex: _spalteErgebnis,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ergebnis.text,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: ergebnis.farbe,
                              letterSpacing: 0.4,
                            ),
                          ),
                          if (rest != null) Text(rest, style: leise),
                          if (onWiederholen != null || aktion != null)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (onWiederholen != null)
                                  IconButton(
                                    key: ValueKey(
                                      'dice-log-wiederholen-${entry.timestamp.millisecondsSinceEpoch}',
                                    ),
                                    tooltip: 'Nochmal würfeln',
                                    onPressed: onWiederholen,
                                    icon: const Icon(Icons.replay, size: 18),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ?aktion,
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
