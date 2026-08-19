import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/rules/derived/armatrutz_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/spell_duration_field.dart';

/// Oeffnet die Eingabemaske fuer einen laufenden `Armatrutz`.
///
/// Liefert den erzauberten Ruestungsschutz samt Wirkungsdauer als
/// [ActiveSpellEffectDetail] zurueck oder `null`, wenn abgebrochen wurde.
Future<ActiveSpellEffectDetail?> showArmatrutzInputDialog({
  required BuildContext context,
  ActiveSpellEffectDetail? initialDetail,
}) {
  return showAdaptiveInputDialog<ActiveSpellEffectDetail>(
    context: context,
    builder: (_) => _ArmatrutzInputDialog(initialDetail: initialDetail),
  );
}

class _ArmatrutzInputDialog extends StatefulWidget {
  const _ArmatrutzInputDialog({this.initialDetail});

  final ActiveSpellEffectDetail? initialDetail;

  @override
  State<_ArmatrutzInputDialog> createState() => _ArmatrutzInputDialogState();
}

class _ArmatrutzInputDialogState extends State<_ArmatrutzInputDialog> {
  late final TextEditingController _rsController;
  late final TextEditingController _zfpController;
  SpellDuration? _duration;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDetail;
    _rsController = TextEditingController(
      text: initial == null || initial.amount <= 0 ? '' : '${initial.amount}',
    );
    _zfpController = TextEditingController();
    _duration = initial?.duration;
  }

  @override
  void dispose() {
    _rsController.dispose();
    _zfpController.dispose();
    super.dispose();
  }

  /// Liest den erzauberten RS und begrenzt ihn auf den Eingabebereich.
  int get _rsBonus {
    final parsed = int.tryParse(_rsController.text.trim()) ?? 0;
    return parsed.clamp(0, kArmatrutzMaxRsBonus);
  }

  /// Liest die erwuerfelten ZfP* fuer den Kostenhinweis.
  int get _zfpStar {
    final parsed = int.tryParse(_zfpController.text.trim()) ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdaptiveInputDialog(
      title: 'Armatrutz – magische Rüstung',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Der erzauberte Rüstungsschutz zählt zusätzlich zur getragenen '
            'Rüstung und erzeugt keine Behinderung.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kDialogSectionSpacing),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  key: const ValueKey<String>('armatrutz-input-rs'),
                  controller: _rsController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    labelText: 'Zusätzlicher RS',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: kDialogInlineSpacing),
              SizedBox(
                width: 110,
                child: TextField(
                  key: const ValueKey<String>('armatrutz-input-zfp'),
                  controller: _zfpController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    labelText: 'ZfP*',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: kDialogInlineSpacing),
          Text(
            key: const ValueKey<String>('armatrutz-input-cost-hint'),
            describeArmatrutzAspCost(rsBonus: _rsBonus, zfpStar: _zfpStar),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: kDialogSectionSpacing),
          SpellDurationField(
            fieldKeyPrefix: 'armatrutz-duration',
            initialDuration: _duration,
            defaultUnit: SpellDurationUnit.spielrunden,
            onChanged: (value) => _duration = value,
          ),
          const SizedBox(height: kDialogInlineSpacing),
          Text(
            'Wirkungsdauer laut Liber Cantiones: maximal eine Spielrunde (A).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('armatrutz-input-confirm'),
          onPressed: () {
            final detail = ActiveSpellEffectDetail(
              amount: _rsBonus,
              duration: _duration,
            );
            Navigator.of(context).pop(detail);
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
