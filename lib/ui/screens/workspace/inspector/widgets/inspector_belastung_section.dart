import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_value_row.dart';

/// Auf-/zuklappbare Belastungs-Sektion (Überanstrengung, Erschöpfung).
class InspectorBelastungSection extends ConsumerStatefulWidget {
  const InspectorBelastungSection({
    super.key,
    required this.heroId,
    required this.heroState,
  });

  final String heroId;
  final HeroState heroState;

  @override
  ConsumerState<InspectorBelastungSection> createState() =>
      _InspectorBelastungSectionState();
}

class _InspectorBelastungSectionState
    extends ConsumerState<InspectorBelastungSection> {
  bool _expanded = false;

  // Zählt vom gespeicherten Wert aus, nicht vom Stand beim Rendern: zwei
  // schnelle Klicks zählen so zweimal, andere Felder bleiben unberührt.
  Future<void> _save(
    String was,
    HeroState Function(HeroState aktuell) aenderung,
  ) async {
    await aendereZustandMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: was,
      aenderung: aenderung,
    );
  }

  // Belastungsstufen fallen nie unter 0.
  static int _einsWeniger(int wert) => wert > 0 ? wert - 1 : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.heroState;
    final hasAny = state.erschoepfung > 0 || state.ueberanstrengung > 0;
    final secondary = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Belastung',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hasAny ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: secondary,
                ),
                const SizedBox(width: 8),
                if (hasAny)
                  Expanded(
                    child: Text(
                      'E ${state.erschoepfung} · Ü ${state.ueberanstrengung}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      'Jeder Punkt zählt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 6),
          InspectorValueRow(
            key: const ValueKey<String>('workspace-vital-row-erschoepfung'),
            label: 'Erschöpfung',
            modifier: state.erschoepfung,
            result: state.erschoepfung,
            onDecrement: () => _save(
              'Erschöpfung',
              (aktuell) => aktuell.copyWith(
                erschoepfung: _einsWeniger(aktuell.erschoepfung),
              ),
            ),
            onIncrement: () => _save(
              'Erschöpfung',
              (aktuell) =>
                  aktuell.copyWith(erschoepfung: aktuell.erschoepfung + 1),
            ),
            onReset: state.erschoepfung != 0
                ? () => _save(
                    'Erschöpfung',
                    (aktuell) => aktuell.copyWith(erschoepfung: 0),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          InspectorValueRow(
            key: const ValueKey<String>('workspace-vital-row-ueberanstrengung'),
            label: 'Überanstrengung',
            modifier: state.ueberanstrengung,
            result: state.ueberanstrengung,
            onDecrement: () => _save(
              'Überanstrengung',
              (aktuell) => aktuell.copyWith(
                ueberanstrengung: _einsWeniger(aktuell.ueberanstrengung),
              ),
            ),
            onIncrement: () => _save(
              'Überanstrengung',
              (aktuell) => aktuell.copyWith(
                ueberanstrengung: aktuell.ueberanstrengung + 1,
              ),
            ),
            onReset: state.ueberanstrengung != 0
                ? () => _save(
                    'Überanstrengung',
                    (aktuell) => aktuell.copyWith(ueberanstrengung: 0),
                  )
                : null,
          ),
        ],
      ],
    );
  }
}
