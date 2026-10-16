import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Schmale Kachel für einen zugekauften Basiswert (LeP, Au, AsP, KaP, MR).
///
/// Sie steht neben den Eigenschaften, trägt aber ein eigenes Gesicht: eine
/// Farbkante je Ressource statt der vollen Karte, die Zukaufzahl groß rechts.
/// Wie [AdvancementValueTile] verwendet sie nur bereits aufgelöste Werte.
class AdvancementBaseValueTile extends StatelessWidget {
  /// Bindet die Kachel an die Regeloption und den Vormerk-Zustand.
  const AdvancementBaseValueTile({
    super.key,
    required this.option,
    required this.planned,
    required this.onPlan,
  });

  /// Regeloption des Zukaufs.
  final AdvancementOption option;

  /// Kennzeichnet Ziele mit vorgemerkten Änderungen.
  final bool planned;

  /// Öffnet den Steigerungsdialog.
  final VoidCallback? onPlan;

  // Kartograph kennt nur für LeP, Au und AsP ein Ressourcentoken; KaP und MR
  // bekommen bewusst keine erfundene Farbe, sondern Messing bzw. Grau.
  Color _akzent(BuildContext context) {
    final karto = kartoVariante(context);
    final scheme = Theme.of(context).colorScheme;
    if (karto != null) {
      return switch (option.targetId) {
        'lep' => karto.lebensenergie,
        'au' => karto.ausdauer,
        'asp' => karto.astralenergie,
        'kap' => karto.messing,
        _ => karto.schriftLeise,
      };
    }
    return switch (option.targetId) {
      'lep' => scheme.error,
      'au' => scheme.tertiary,
      'asp' => scheme.primary,
      'kap' => scheme.secondary,
      _ => scheme.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final karto = kartoVariante(context);
    final leise = karto?.schriftLeise ?? theme.colorScheme.onSurfaceVariant;
    final enabled = option.unavailableReason == null ? onPlan : null;
    final inhalt = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.label, style: theme.textTheme.titleMedium),
                  Text(
                    'Zukauf',
                    style: theme.textTheme.labelSmall?.copyWith(color: leise),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(option.currentValue.toString(), style: _zahl(theme)),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 2,
          children: [
            Text(
              'Maximum ${option.maxValue}',
              style: theme.textTheme.bodySmall,
            ),
            Text('SE ${option.seAvailable}', style: theme.textTheme.bodySmall),
            if (planned)
              Text(
                'Geplant',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        if (option.unavailableReason != null)
          Text(option.unavailableReason!, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        OutlinedButton(
          key: ValueKey(
            'advancement-plan-${option.kind.name}-${option.targetId}',
          ),
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: enabled,
          child: const Text('Steigern'),
        ),
      ],
    );
    final mitKante = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _akzent(context), width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: inhalt,
      ),
    );
    final geklippt = ClipRRect(
      borderRadius: BorderRadius.circular(kartoRadiusOder(context, 12)),
      child: mitKante,
    );
    if (karto != null) {
      return KartoFlaeche(child: geklippt);
    }
    return Card(margin: EdgeInsets.zero, child: geklippt);
  }

  TextStyle? _zahl(ThemeData theme) => theme.textTheme.headlineSmall?.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
