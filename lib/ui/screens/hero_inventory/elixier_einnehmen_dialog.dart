import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_elixier_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_verbrauch_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Öffnet den Dialog „Elixier einnehmen“ (TRANK).
///
/// Zeigt die Eigenschaftsänderungen des Katalogs mit ihrer Dauer. Beim
/// Bestätigen legt der Dialog sie als Wirkungsquellen am Helden an (im
/// Effektdialog änderbar und beendbar) und zieht auf Wunsch ein Stück vom
/// Bestand ab. Liefert `true`, wenn das Elixier eingenommen wurde.
Future<bool> zeigeElixierEinnehmen({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required HeroInventoryEntry eintrag,
}) async {
  final ergebnis = await showAdaptiveDetailSheet<bool>(
    context: context,
    builder: (sheetContext) => AlertDialog(
      key: const ValueKey<String>('elixier-dialog'),
      title: Text('${eintrag.gegenstand} einnehmen'),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: ElixierPanel(
            heroId: heroId,
            eintrag: eintrag,
            onFertig: () => Navigator.of(sheetContext).pop(true),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('elixier-abbrechen'),
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );
  return ergebnis ?? false;
}

/// Anzeige und Bestätigung des Einnehmens.
///
/// Das Panel rechnet nichts: Die Eigenschaftsänderungen stammen aus dem
/// Katalog (`alchimika_elixier_rules.dart`), gespeichert wird über den Ablauf
/// `ElixierEinnehmen`. Die Vorgangs-ID bleibt bis zum Schließen, ein erneuter
/// Versuch legt so nie doppelt an.
class ElixierPanel extends ConsumerStatefulWidget {
  /// Erstellt das Panel.
  const ElixierPanel({
    super.key,
    required this.heroId,
    required this.eintrag,
    required this.onFertig,
  });

  /// Held, der das Elixier einnimmt.
  final String heroId;

  /// Der angezeigte Inventareintrag.
  final HeroInventoryEntry eintrag;

  /// Wird nach erfolgreichem Speichern aufgerufen.
  final VoidCallback onFertig;

  @override
  ConsumerState<ElixierPanel> createState() => _ElixierPanelState();
}

class _ElixierPanelState extends ConsumerState<ElixierPanel> {
  bool _verbrauchen = true;
  bool _schreibt = false;
  bool _eingenommen = false;
  String? _fehler;
  String? _vorgangId;

  Future<void> _uebernehme({required bool verbrauchen}) async {
    if (_schreibt) {
      return;
    }
    final katalog = ref
        .read(heroRulesCatalogProvider(widget.heroId))
        .valueOrNull;
    final bezug = widget.eintrag.alchimikum;
    final mittel = alchimikumZuBezug(katalog, bezug);
    if (mittel == null || bezug == null) {
      return;
    }
    setState(() {
      _schreibt = true;
      _fehler = null;
    });
    try {
      if (!_eingenommen) {
        await ref
            .read(elixierEinnehmenProvider)
            .uebernimm(
              heroId: widget.heroId,
              mittel: mittel,
              stufe: bezug.stufe,
              vorgangId: _vorgangId ??= const Uuid().v4(),
            );
        _eingenommen = true;
      }
      if (verbrauchen) {
        await ref
            .read(heroActionsProvider)
            .updateHero(
              widget.heroId,
              (held) => mitVerbrauchtemInventarEintrag(held, widget.eintrag),
            );
      }
      if (mounted) {
        widget.onFertig();
      }
    } catch (fehler) {
      if (mounted) {
        final text = fehler is StateError ? fehler.message : '$fehler';
        setState(
          () => _fehler = _eingenommen
              ? 'Die Wirkung läuft, das Stück konnte aber nicht abgezogen '
                    'werden: $text'
              : 'Das Elixier konnte nicht eingenommen werden: $text',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _schreibt = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _verbrauchen = inventarAbbuchbar(widget.eintrag);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final katalog = ref
        .watch(heroRulesCatalogProvider(widget.heroId))
        .valueOrNull;
    final bezug = widget.eintrag.alchimikum;
    final mittel = alchimikumZuBezug(katalog, bezug);
    final stufe = mittel == null || bezug == null
        ? null
        : alchimikumStufe(mittel, bezug.stufe);
    if (mittel == null || stufe == null || !stufe.hatEigenschaftsWirkung) {
      return Text(
        'Zu diesem Gegenstand liegt keine Elixierwirkung im Katalog vor.',
        key: const ValueKey<String>('elixier-keine-wirkung'),
        style: theme.textTheme.bodyMedium,
      );
    }
    final planung =
        ref.watch(advancementSessionProvider(widget.heroId)) != null;
    final abbuchbar = inventarAbbuchbar(widget.eintrag) && !planung;
    final menge = inventarMenge(widget.eintrag);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${mittel.name}, Qualität ${bezug!.stufe}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        for (final e in stufe.eigenschaften)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              beschreibeElixierEigenschaft(e),
              key: ValueKey<String>('elixier-eigenschaft-${e.eigenschaft}'),
              style: theme.textTheme.bodyLarge,
            ),
          ),
        if (stufe.wirkung.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            stufe.wirkung,
            key: const ValueKey<String>('elixier-hinweis'),
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Die Änderungen laufen als eigene Wirkungsquellen im Effektdialog. '
          'Dort lässt sich jede Dauer anpassen und die Wirkung beenden. '
          'Mit „(nicht berechnet)“ markierte Folgen trägt die App nicht ein.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: kDialogFieldSpacing),
        if (abbuchbar)
          CheckboxListTile(
            key: const ValueKey<String>('elixier-verbrauchen'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Ein Stück verbrauchen'),
            subtitle: Text('Bestand $menge → ${menge! - 1}'),
            value: _verbrauchen,
            onChanged: _schreibt || _eingenommen
                ? null
                : (wert) => setState(() => _verbrauchen = wert ?? false),
          )
        else
          Text(
            planung
                ? 'Während einer Planung wird das Inventar nicht geändert; das '
                      'Stück bitte danach von Hand abziehen.'
                : 'Die Menge ist nicht eindeutig: Es wird kein Stück '
                      'abgezogen.',
            style: theme.textTheme.bodySmall,
          ),
        if (_fehler != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _fehler!,
              key: const ValueKey<String>('elixier-speicherfehler'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const ValueKey<String>('elixier-einnehmen'),
            onPressed: _schreibt
                ? null
                : () => _uebernehme(verbrauchen: _verbrauchen && abbuchbar),
            child: Text(_eingenommen ? 'Stück abziehen' : 'Einnehmen'),
          ),
        ),
      ],
    );
  }
}
