part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Oeffnet einen adaptiven Detaildialog fuer ein Kampfmanöver.
Future<void> _showCombatManeuverDetailsDialog({
  required BuildContext context,
  required ManeuverDef maneuver,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => _CombatManeuverDetailsDialog(maneuver: maneuver),
  );
}

/// Detaildialog fuer kurze und lange Manövererklärungen.
class _CombatManeuverDetailsDialog extends StatelessWidget {
  const _CombatManeuverDetailsDialog({required this.maneuver});

  final ManeuverDef maneuver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(maneuver.name),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (maneuver.gruppe.trim().isNotEmpty)
                    Chip(label: Text('Gruppe: ${maneuver.gruppe.trim()}')),
                  if (maneuver.typ.trim().isNotEmpty)
                    Chip(label: Text('Typ: ${maneuver.typ.trim()}')),
                  if (maneuver.erschwernis.trim().isNotEmpty)
                    Chip(
                      label: Text(
                        'Erschwernis: ${maneuver.erschwernis.trim()}',
                      ),
                    ),
                  if (maneuver.seite.trim().isNotEmpty)
                    Chip(label: Text('S. ${maneuver.seite.trim()}')),
                ],
              ),
              if (maneuver.erklarung.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Erklärung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(maneuver.erklarung.trim()),
              ],
              if (maneuver.voraussetzungen.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Voraussetzungen', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(maneuver.voraussetzungen.trim()),
              ],
              if (maneuver.verbreitung.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Verbreitung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(maneuver.verbreitung.trim()),
              ],
              if (maneuver.kosten.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Kosten', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(maneuver.kosten.trim()),
              ],
              if (maneuver.erklarungLang.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Lange Erklärung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(maneuver.erklarungLang.trim()),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
