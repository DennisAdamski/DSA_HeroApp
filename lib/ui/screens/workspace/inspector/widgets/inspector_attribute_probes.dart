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
    required this.probenEigenschaften,
    this.grundwerte,
    this.kompakt = false,
  });

  /// ID fuer das Protokollieren des Ergebnisses.
  final String heroId;

  /// Eigenschaftswerte fuer Proben (`HeroComputedSnapshot.probenEigenschaften`),
  /// Wundverluste eingerechnet.
  final Attributes probenEigenschaften;

  /// Effektive Werte ohne Wunden; mit ihnen markieren die Karten den
  /// Wundabzug. Ohne Angabe gibt es keine Markierung.
  final Attributes? grundwerte;

  /// Einzeilige, flache Karten in bis zu acht Spalten (Spielansicht des
  /// Neubaus). Die klassische Optik bleibt beim Standard `false`.
  final bool kompakt;

  /// Reihenfolge der acht Eigenschaften, wie auf dem Heldenbogen.
  List<AttributeProbeEintrag> get entries => _entriesFuer(probenEigenschaften);

  // Die acht Werte in Heldenbogen-Reihenfolge.
  static List<AttributeProbeEintrag> _entriesFuer(
    Attributes probenEigenschaften,
  ) => <AttributeProbeEintrag>[
    (label: 'MU', value: probenEigenschaften.mu),
    (label: 'KL', value: probenEigenschaften.kl),
    (label: 'IN', value: probenEigenschaften.inn),
    (label: 'CH', value: probenEigenschaften.ch),
    (label: 'FF', value: probenEigenschaften.ff),
    (label: 'GE', value: probenEigenschaften.ge),
    (label: 'KO', value: probenEigenschaften.ko),
    (label: 'KK', value: probenEigenschaften.kk),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final basis = grundwerte;
    final ohneWunden = <String, int>{
      if (basis != null)
        for (final eintrag in _entriesFuer(basis)) eintrag.label: eintrag.value,
    };
    return _AttributeGrid(
      entries: entries,
      kompakt: kompakt,
      itemBuilder: (entry) => InspectorAttributeCard(
        key: ValueKey('inspector-probe-attr-${entry.label}'),
        label: entry.label,
        value: entry.value,
        kompakt: kompakt,
        wundAbzug: entry.value - (ohneWunden[entry.label] ?? entry.value),
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
  const _AttributeGrid({
    required this.entries,
    required this.itemBuilder,
    required this.kompakt,
  });

  static const double _spacing = 6;

  final List<AttributeProbeEintrag> entries;
  final Widget Function(AttributeProbeEintrag entry) itemBuilder;
  final bool kompakt;

  double get _minTileWidth => kompakt ? 56 : 48;
  double get _tileHeight => kompakt ? 36 : 58;
  int get _maxColumns => kompakt ? 8 : 4;

  int _columnCount(double availableWidth) {
    final rawCount = ((availableWidth + _spacing) / (_minTileWidth + _spacing))
        .floor();
    final count = rawCount.clamp(1, _maxColumns).toInt();
    // Kompakt nur 8, 4 oder 2 Spalten: ungleiche Zeilen wie 5 + 3 lesen
    // sich schlechter als zwei volle.
    if (!kompakt) return count;
    if (count >= 8) return 8;
    if (count >= 4) return 4;
    return count >= 2 ? 2 : 1;
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
