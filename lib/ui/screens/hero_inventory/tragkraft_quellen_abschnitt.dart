import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_tragkraft_bonus.dart';
import 'package:dsa_heldenverwaltung/rules/derived/tragkraft_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

/// Tragkraft des Helden und ihre dauerhaften Quellen im Inventar-Tab.
///
/// Zeigt die Tragkraft samt Herleitung (`berechneTragkraft`, Tooltip mit
/// `tragkraftFormel`) und die Quellen aus `HeroSheet.tragkraftBoni`. Nur
/// **Dauerhaftes** gehört dorthin (Bärenrune bis zur Sonnenwende, dauerhafte
/// Gegenstände), keine Kurzzeitzauber. Jede Änderung schreibt frisch auf den
/// gespeicherten Helden (`mitTragkraftBonus`, `ohneTragkraftBonus`); während
/// einer Planung ist der Abschnitt gesperrt ([readOnly]). Die Spielansicht
/// zeigt in „Dabei“ nur die Last gegen diese Tragkraft.
class TragkraftQuellenAbschnitt extends ConsumerWidget {
  /// Erstellt den Abschnitt für den Helden [heroId].
  const TragkraftQuellenAbschnitt({
    super.key,
    required this.heroId,
    required this.quellen,
    this.readOnly = false,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Gespeicherte Tragkraftquellen des Helden.
  final List<HeroTragkraftBonus> quellen;

  /// Sperrt Hinzufügen und Entfernen (offene Planung).
  final bool readOnly;

  Future<void> _schreibe(
    BuildContext context,
    WidgetRef ref,
    HeroSheet Function(HeroSheet aktuell) aenderung,
  ) async {
    await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: heroId,
      was: 'Tragkraftquelle',
      aenderung: aenderung,
    );
  }

  Future<void> _baerenrune(BuildContext context, WidgetRef ref) async {
    final ergebnis = await showDialog<({int rkp, bool kk})>(
      context: context,
      builder: (_) => const _BaerenruneDialog(),
    );
    if (ergebnis == null || !context.mounted) return;
    final bonus = baerenruneBonus(
      id: const Uuid().v4(),
      rkp: ergebnis.rkp,
      hausregelKk: ergebnis.kk,
    );
    await _schreibe(context, ref, (held) => mitTragkraftBonus(held, bonus));
  }

  Future<void> _quelle(BuildContext context, WidgetRef ref) async {
    final ergebnis = await showDialog<HeroTragkraftBonus>(
      context: context,
      builder: (_) => const _QuelleDialog(),
    );
    if (ergebnis == null || !context.mounted) return;
    final bonus = ergebnis.copyWith(id: const Uuid().v4());
    await _schreibe(context, ref, (held) => mitTragkraftBonus(held, bonus));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tragkraft = ref
        .watch(heroComputedProvider(heroId))
        .valueOrNull
        ?.tragkraft;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (tragkraft != null)
          Tooltip(
            message: 'Tragkraft ${tragkraftFormel(tragkraft.tragkraft)}',
            child: Text(
              'Tragkraft ${tragkraft.tragkraftStein} Stein',
              key: const ValueKey<String>('inventory-tragkraft-wert'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        for (var i = 0; i < quellen.length; i++)
          InputChip(
            key: ValueKey<String>('inventory-tragkraft-quelle-$i'),
            label: Text(_quellenText(quellen[i])),
            deleteButtonTooltipMessage: '${quellen[i].anzeigeName} entfernen',
            onDeleted: readOnly
                ? null
                : () => _schreibe(
                    context,
                    ref,
                    (held) => ohneTragkraftBonus(held, quellen[i].id),
                  ),
          ),
        TextButton(
          key: const ValueKey<String>('inventory-tragkraft-baerenrune'),
          onPressed: readOnly ? null : () => _baerenrune(context, ref),
          child: const Text('+ Bärenrune'),
        ),
        TextButton(
          key: const ValueKey<String>('inventory-tragkraft-quelle'),
          onPressed: readOnly ? null : () => _quelle(context, ref),
          child: const Text('+ Andere Tragkraftquelle'),
        ),
      ],
    );
  }

  static String _quellenText(HeroTragkraftBonus quelle) => [
    quelle.anzeigeName,
    if (quelle.stein != 0) '+${quelle.stein} Stein',
    if (quelle.kk != 0) 'KK ${quelle.kk > 0 ? '+' : ''}${quelle.kk}',
  ].join(' · ');
}

/// Dialog „Bärenrune“: RkP* der Rune, dazu die Hausregel „KK +1“.
///
/// Liefert RkP* und den Schalter der Hausregel oder nichts bei Abbruch. Die
/// Tragkraft (RkP* × 10 Stein) rechnet `baerenruneBonus`.
class _BaerenruneDialog extends StatefulWidget {
  const _BaerenruneDialog();

  @override
  State<_BaerenruneDialog> createState() => _BaerenruneDialogState();
}

class _BaerenruneDialogState extends State<_BaerenruneDialog> {
  final TextEditingController _rkp = TextEditingController();
  bool _kk = false;
  String? _fehler;

  @override
  void dispose() {
    _rkp.dispose();
    super.dispose();
  }

  void _uebernehmen() {
    final rkp = int.tryParse(_rkp.text.trim());
    if (rkp == null || rkp <= 0) {
      setState(() => _fehler = 'Bitte die RkP* als Zahl über 0 eingeben.');
      return;
    }
    Navigator.of(context).pop((rkp: rkp, kk: _kk));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bärenrune'),
      content: SizedBox(
        width: kDialogWidthSmall,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey<String>('inventory-tragkraft-baerenrune-rkp'),
              controller: _rkp,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'RkP*',
                helperText: 'Tragkraft + RkP* × 10 Stein (WdA S. 161)',
                errorText: _fehler,
              ),
              onChanged: (_) {
                if (_fehler != null) setState(() => _fehler = null);
              },
              onSubmitted: (_) => _uebernehmen(),
            ),
            CheckboxListTile(
              key: const ValueKey<String>('inventory-tragkraft-baerenrune-kk'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _kk,
              onChanged: (wert) => setState(() => _kk = wert ?? false),
              title: const Text('Hausregel: zusätzlich KK +1'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('inventory-tragkraft-baerenrune-ok'),
          onPressed: _uebernehmen,
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}

/// Dialog „Tragkraftquelle“: Name, zusätzliche Stein und KK nur für die
/// Tragkraft. Liefert die Quelle (ohne ID) oder nichts bei Abbruch.
class _QuelleDialog extends StatefulWidget {
  const _QuelleDialog();

  @override
  State<_QuelleDialog> createState() => _QuelleDialogState();
}

class _QuelleDialogState extends State<_QuelleDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _stein = TextEditingController();
  final TextEditingController _kk = TextEditingController();
  String? _fehler;

  @override
  void dispose() {
    _name.dispose();
    _stein.dispose();
    _kk.dispose();
    super.dispose();
  }

  void _uebernehmen() {
    final name = _name.text.trim();
    final stein = _stein.text.trim().isEmpty
        ? 0
        : int.tryParse(_stein.text.trim());
    final kk = _kk.text.trim().isEmpty ? 0 : int.tryParse(_kk.text.trim());
    if (name.isEmpty) {
      setState(() => _fehler = 'Bitte einen Namen eingeben.');
      return;
    }
    if (stein == null || stein < 0 || kk == null) {
      setState(() => _fehler = 'Stein und KK müssen ganze Zahlen sein.');
      return;
    }
    if (stein == 0 && kk == 0) {
      setState(() => _fehler = 'Stein oder KK muss ungleich 0 sein.');
      return;
    }
    Navigator.of(context)
        .pop(HeroTragkraftBonus(id: '', name: name, stein: stein, kk: kk));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tragkraftquelle'),
      content: SizedBox(
        width: kDialogWidthSmall,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey<String>('inventory-tragkraft-quelle-name'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name',
                helperText: 'Nur Dauerhaftes, keine Kurzzeitzauber',
                errorText: _fehler,
              ),
              onChanged: (_) {
                if (_fehler != null) setState(() => _fehler = null);
              },
            ),
            TextField(
              key: const ValueKey<String>('inventory-tragkraft-quelle-stein'),
              controller: _stein,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Zusätzliche Stein'),
            ),
            TextField(
              key: const ValueKey<String>('inventory-tragkraft-quelle-kk'),
              controller: _kk,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'KK nur für die Tragkraft',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('inventory-tragkraft-quelle-ok'),
          onPressed: _uebernehmen,
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}
