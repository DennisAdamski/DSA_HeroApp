import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
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

  Future<void> _save(HeroState updated) async {
    await ref.read(heroActionsProvider).saveHeroState(widget.heroId, updated);
  }

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
              state.copyWith(
                erschoepfung: state.erschoepfung > 0
                    ? state.erschoepfung - 1
                    : 0,
              ),
            ),
            onIncrement: () =>
                _save(state.copyWith(erschoepfung: state.erschoepfung + 1)),
            onReset: state.erschoepfung != 0
                ? () => _save(state.copyWith(erschoepfung: 0))
                : null,
          ),
          const SizedBox(height: 4),
          InspectorValueRow(
            key: const ValueKey<String>('workspace-vital-row-ueberanstrengung'),
            label: 'Überanstrengung',
            modifier: state.ueberanstrengung,
            result: state.ueberanstrengung,
            onDecrement: () => _save(
              state.copyWith(
                ueberanstrengung: state.ueberanstrengung > 0
                    ? state.ueberanstrengung - 1
                    : 0,
              ),
            ),
            onIncrement: () => _save(
              state.copyWith(ueberanstrengung: state.ueberanstrengung + 1),
            ),
            onReset: state.ueberanstrengung != 0
                ? () => _save(state.copyWith(ueberanstrengung: 0))
                : null,
          ),
        ],
      ],
    );
  }
}
