import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rest_dialog.dart';

/// Kompakte Rast-Karte für den Inspector.
class InspectorRestCard extends StatelessWidget {
  /// Erzeugt die Inspector-Karte für Rast und Regeneration.
  const InspectorRestCard({
    super.key,
    required this.heroId,
    required this.heroState,
  });

  /// Zielheld für den Rast-Dialog.
  final String heroId;

  /// Aktueller Laufzeitzustand des Helden.
  final HeroState heroState;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Rast', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  key: const ValueKey<String>('workspace-rest-open'),
                  tooltip: 'Rast öffnen',
                  onPressed: () {
                    showRestDialog(context: context, heroId: heroId);
                  },
                  icon: const Icon(Icons.local_fire_department_outlined),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Überanstrengung: ${heroState.ueberanstrengung}'),
            Text('Erschöpfung: ${heroState.erschoepfung}'),
          ],
        ),
      ),
    );
  }
}
