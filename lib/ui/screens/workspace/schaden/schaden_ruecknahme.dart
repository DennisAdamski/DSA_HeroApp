import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_ruecknahme_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Aktion am Protokolleintrag einer Schadensbuchung (ARCH-06).
///
/// Liefert „Zurücknehmen“ für eine zurücknehmbare Buchung, die Marke
/// „zurückgenommen“ für eine bereits zurückgenommene und sonst `null` —
/// auch für Einträge ohne Buchung (ältere Protokolle) und für die
/// Rücknahme selbst. Entschieden wird über [schadensBuchungsStatus] auf dem
/// angezeigten Zustand; der Ablauf prüft beim Speichern erneut.
Widget? schadenRuecknahmeAktion({
  required DiceLogEntry eintrag,
  required String heroId,
  required HeroState zustand,
}) {
  final buchungId = eintrag.buchungId;
  if (buchungId == null) {
    return null;
  }
  return switch (schadensBuchungsStatus(zustand, buchungId)) {
    SchadensBuchungsStatus.ruecknehmbar => SchadenRuecknahmeKnopf(
      heroId: heroId,
      buchungId: buchungId,
    ),
    SchadensBuchungsStatus.zurueckgenommen => _ZurueckgenommenMarke(
      buchungId: buchungId,
    ),
    SchadensBuchungsStatus.keine ||
    SchadensBuchungsStatus.nichtMehrVerfuegbar => null,
  };
}

/// Knopf „Zurücknehmen“, der die Rückfrage öffnet.
class SchadenRuecknahmeKnopf extends StatelessWidget {
  /// Erzeugt den Knopf.
  const SchadenRuecknahmeKnopf({
    super.key,
    required this.heroId,
    required this.buchungId,
  });

  /// Held der Buchung.
  final String heroId;

  /// Zurückzunehmende Buchung.
  final String buchungId;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: ValueKey<String>('dice-log-ruecknahme-$buchungId'),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => showSchadenRuecknahmeDialog(
        context: context,
        heroId: heroId,
        buchungId: buchungId,
      ),
      child: const Text('Zurücknehmen'),
    );
  }
}

class _ZurueckgenommenMarke extends StatelessWidget {
  const _ZurueckgenommenMarke({required this.buchungId});

  final String buchungId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'zurückgenommen',
      key: ValueKey<String>('dice-log-zurueckgenommen-$buchungId'),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// Fragt nach, was die Rücknahme ändert, und nimmt die Buchung zurück.
///
/// Der Dialog zeigt den Plan auf dem aktuell gespeicherten Zustand, schreibt
/// über den Ablauf `SchadenZuruecknehmen` und schließt sich nach Erfolg
/// selbst. Fehler zeigt er selbst an.
Future<void> showSchadenRuecknahmeDialog({
  required BuildContext context,
  required String heroId,
  required String buchungId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _SchadenRuecknahmeDialog(heroId: heroId, buchungId: buchungId),
  );
}

class _SchadenRuecknahmeDialog extends ConsumerStatefulWidget {
  const _SchadenRuecknahmeDialog({
    required this.heroId,
    required this.buchungId,
  });

  final String heroId;
  final String buchungId;

  @override
  ConsumerState<_SchadenRuecknahmeDialog> createState() =>
      _SchadenRuecknahmeDialogState();
}

class _SchadenRuecknahmeDialogState
    extends ConsumerState<_SchadenRuecknahmeDialog> {
  /// ID der Gegenbuchung; bleibt für Wiederholungen nach einem Fehler gleich.
  String? _vorgangId;
  bool _schreibt = false;
  String? _fehler;

  Future<void> _nimmZurueck() async {
    if (_schreibt) {
      return;
    }
    setState(() {
      _schreibt = true;
      _fehler = null;
    });
    try {
      await ref
          .read(schadenZuruecknehmenProvider)
          .nimmZurueck(
            heroId: widget.heroId,
            buchungId: widget.buchungId,
            vorgangId: _vorgangId ??= const Uuid().v4(),
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (fehler) {
      if (mounted) {
        final text = fehler is StateError ? fehler.message : '$fehler';
        setState(() => _fehler = 'Rücknahme nicht gespeichert: $text');
      }
    } finally {
      if (mounted) {
        setState(() => _schreibt = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zustand = ref.watch(heroStateProvider(widget.heroId)).valueOrNull;
    final werte = ref.watch(heroComputedProvider(widget.heroId)).valueOrNull;
    final pruefung = zustand == null
        ? null
        : planeSchadensRuecknahme(zustand, widget.buchungId);
    final plan = switch (pruefung) {
      RuecknahmeMoeglich(:final plan) => plan,
      _ => null,
    };
    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey<String>('schaden-ruecknahme-dialog'),
      title: const Text('Schaden zurücknehmen'),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (zustand == null)
                const Center(child: CircularProgressIndicator())
              else if (pruefung case RuecknahmeUnmoeglich(:final hindernis))
                Text(ruecknahmeHindernisText(hindernis))
              else if (plan != null)
                ..._planZeilen(
                  zustand,
                  plan,
                  maxLep: werte?.derivedStats.maxLep,
                  maxAu: werte?.derivedStats.maxAu,
                ),
              if (_fehler != null) ...[
                const SizedBox(height: 12),
                Text(
                  _fehler!,
                  key: const ValueKey<String>('schaden-ruecknahme-fehler'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('schaden-ruecknahme-abbrechen'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('schaden-ruecknahme-bestaetigen'),
          onPressed: plan == null || _schreibt ? null : _nimmZurueck,
          child: const Text('Zurücknehmen'),
        ),
      ],
    );
  }

  List<Widget> _planZeilen(
    HeroState zustand,
    SchadensRuecknahmePlan plan, {
    required int? maxLep,
    required int? maxAu,
  }) {
    final zeilen = <String>[];
    final hinweise = <String>[];
    if (plan.lepPlus > 0) {
      final neu = zustand.currentLep + plan.lepPlus;
      zeilen.add('LeP: ${zustand.currentLep} → $neu');
      if (maxLep != null && neu > maxLep) {
        hinweise.add(
          'Die LeP liegen danach über dem Maximum ($maxLep). Eine '
          'zwischenzeitliche Heilung bitte von Hand anpassen.',
        );
      }
    }
    if (plan.auPlus > 0) {
      final neu = zustand.currentAu + plan.auPlus;
      zeilen.add('AuP: ${zustand.currentAu} → $neu');
      if (maxAu != null && neu > maxAu) {
        hinweise.add('Die AuP liegen danach über dem Maximum ($maxAu).');
      }
    }
    final zone = plan.zone;
    if (zone != null && plan.wundenEntfernt > 0) {
      final vorher = zustand.wpiZustand.wundenInZone(zone);
      zeilen.add(
        'Wunden ${wundZoneLabel[zone]}: $vorher → '
        '${vorher - plan.wundenEntfernt}',
      );
    }
    if (plan.kopfIniMalusMinus > 0) {
      final malus = zustand.wpiZustand.kopfIniMalus;
      zeilen.add('INI-Malus Kopf: $malus → ${malus - plan.kopfIniMalusMinus}');
    }
    if (plan.wundenNichtMehrVorhanden > 0) {
      final n = plan.wundenNichtMehrVorhanden;
      hinweise.add(
        n == 1
            ? '1 Wunde dieses Treffers ist bereits geheilt.'
            : '$n Wunden dieses Treffers sind bereits geheilt.',
      );
    }
    if (plan.zoneUnbekannt) {
      hinweise.add(
        'Die Wunden dieses Treffers stammen aus einer neueren App-Version '
        'und bleiben eingetragen.',
      );
    }
    if (zeilen.isEmpty) {
      zeilen.add('Der Treffer hat keine Werte verändert.');
    }
    return <Widget>[
      for (final zeile in zeilen) Text(zeile),
      for (final hinweis in hinweise) ...[
        const SizedBox(height: 8),
        Text(hinweis, style: Theme.of(context).textTheme.bodySmall),
      ],
    ];
  }
}
