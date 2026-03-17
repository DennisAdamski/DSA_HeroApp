part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Konstanten
// ---------------------------------------------------------------------------
const double _sectionSpacing = 16;
const double _fieldSpacing = 12;
const double _innerFieldSpacing = 8;

// ---------------------------------------------------------------------------
// Hilfs-Widgets
// ---------------------------------------------------------------------------

/// Abschnittsheader mit Trennlinie.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
