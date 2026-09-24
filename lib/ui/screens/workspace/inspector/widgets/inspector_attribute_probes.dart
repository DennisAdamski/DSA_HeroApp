import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_request_factory.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_attribute_card.dart';

/// Tupel aus Eigenschaftslabel und effektivem Wert.
typedef AttributeProbeEintrag = ({String label, int value});

/// Acht Eigenschafts-Schnellproben als eigener Baustein.
///
/// Aus dem Probe-Tab herausgeloest, damit die neue Spielansicht dieselben
/// Karten und denselben Wuerfelweg benutzt statt einer zweiten Umsetzung.
/// Der Request entsteht ausschliesslich in [buildAttributeProbeRequest],
/// gewuerfelt und protokolliert wird ueber [showLoggedProbeDialog].
class InspectorAttributeProbes extends ConsumerWidget {
  /// Erstellt die Eigenschaftsproben fuer die uebergebenen Werte.
  const InspectorAttributeProbes({
    super.key,
    required this.heroId,
    required this.effectiveAttributes,
  });

  /// ID fuer das Protokollieren des Ergebnisses.
  final String heroId;

  /// Bereits berechnete effektive Eigenschaften.
  final Attributes effectiveAttributes;

  /// Reihenfolge der acht Eigenschaften, wie auf dem Heldenbogen.
  List<AttributeProbeEintrag> get entries => <AttributeProbeEintrag>[
    (label: 'MU', value: effectiveAttributes.mu),
    (label: 'KL', value: effectiveAttributes.kl),
    (label: 'IN', value: effectiveAttributes.inn),
    (label: 'CH', value: effectiveAttributes.ch),
    (label: 'FF', value: effectiveAttributes.ff),
    (label: 'GE', value: effectiveAttributes.ge),
    (label: 'KO', value: effectiveAttributes.ko),
    (label: 'KK', value: effectiveAttributes.kk),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AttributeGrid(
      entries: entries,
      itemBuilder: (entry) => InspectorAttributeCard(
        key: ValueKey('inspector-probe-attr-${entry.label}'),
        label: entry.label,
        value: entry.value,
        onTap: () => showLoggedProbeDialog(
          context: context,
          ref: ref,
          heroId: heroId,
          request: buildAttributeProbeRequest(
            label: entry.label,
            effectiveValue: entry.value,
          ),
        ),
      ),
    );
  }
}

// Haelt die Eigenschaftskarten auch in einer schmalen Spalte lesbar.
class _AttributeGrid extends StatelessWidget {
  const _AttributeGrid({required this.entries, required this.itemBuilder});

  static const double _spacing = 6;
  static const double _minTileWidth = 48;
  static const double _tileHeight = 58;
  static const int _maxColumns = 4;

  final List<AttributeProbeEintrag> entries;
  final Widget Function(AttributeProbeEintrag entry) itemBuilder;

  int _columnCount(double availableWidth) {
    final rawCount = ((availableWidth + _spacing) / (_minTileWidth + _spacing))
        .floor();
    return rawCount.clamp(1, _maxColumns).toInt();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = _maxColumns * (_minTileWidth + _spacing);
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : fallbackWidth;
        final crossAxisCount = _columnCount(availableWidth);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            mainAxisExtent: _tileHeight,
          ),
          itemBuilder: (context, index) => itemBuilder(entries[index]),
        );
      },
    );
  }
}
