import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_anzeige_rules.dart';

/// Antwort des Herkunftsdialogs eines Merkmals.
///
/// [herkunft] ist `null` für „Nicht angegeben“. Der Dialog selbst liefert
/// `null`, wenn er abgebrochen wurde; ein Abbruch ändert deshalb nichts.
class MerkmalHerkunftWahl {
  /// Erstellt eine Wahl.
  const MerkmalHerkunftWahl(this.herkunft);

  /// Gewählte Herkunft; `null` entfernt die Angabe.
  final HeroHerkunft? herkunft;
}

/// Fragt, woher ein Vor- oder Nachteil stammt (Rasse, Kultur, Profession).
///
/// Gemeinsam für die Übersicht und das Merkmalsblatt des Neubaus. Das ist ein
/// reines Metadatum: Es ändert weder AP noch Regelwirkung. Der Dialog schließt
/// sich selbst.
Future<MerkmalHerkunftWahl?> zeigeMerkmalHerkunftDialog({
  required BuildContext context,
  required String merkmalName,
  HeroHerkunft? aktuell,
}) {
  return showDialog<MerkmalHerkunftWahl>(
    context: context,
    builder: (dialogContext) =>
        _MerkmalHerkunftDialog(merkmalName: merkmalName, aktuell: aktuell),
  );
}

class _MerkmalHerkunftDialog extends StatelessWidget {
  const _MerkmalHerkunftDialog({
    required this.merkmalName,
    required this.aktuell,
  });

  final String merkmalName;
  final HeroHerkunft? aktuell;

  @override
  Widget build(BuildContext context) {
    final optionen = <(Key, String, HeroHerkunft?)>[
      (
        const ValueKey<String>('merkmal-herkunft-nicht-angegeben'),
        'Nicht angegeben',
        null,
      ),
      for (final herkunft in HeroHerkunft.values)
        (
          ValueKey<String>('merkmal-herkunft-${herkunft.name}'),
          herkunftBezeichnung(herkunft),
          herkunft,
        ),
    ];
    return AlertDialog(
      title: const Text('Herkunft ändern'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(merkmalName, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Woher stammt dieser Eintrag? Das ist nur eine Angabe und '
                'ändert weder AP noch Regelwirkung.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final (schluessel, text, herkunft) in optionen)
                ListTile(
                  key: schluessel,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(text),
                  trailing: herkunft == aktuell
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: () =>
                      Navigator.of(context).pop(MerkmalHerkunftWahl(herkunft)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('merkmal-herkunft-abbrechen'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}
