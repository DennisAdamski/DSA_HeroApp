part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Freie Werte eines Machtvollen Vertrauten (WdZ S. 124, WdH S. 255)
// ---------------------------------------------------------------------------

// Anzeigenamen der frei setzbaren Startwerte.
const Map<String, String> _kFreieWertLabels = <String, String>{
  'mu': 'MU',
  'kl': 'KL',
  'inn': 'IN',
  'ch': 'CH',
  'ff': 'FF',
  'ge': 'GE',
  'ko': 'KO',
  'kk': 'KK',
  'lep': 'LeP',
  'asp': 'AsP',
  'aup': 'AuP',
  'ini': 'INI-Basis',
  'mr': 'MR',
  'rs': 'RS',
};

/// Formular für einen Machtvollen Vertrauten: eigener Artname, alle
/// Startwerte, Angriffe und Geschwindigkeiten frei ab der Vorlage [art].
///
/// Kosten tragen nur die markierten geistigen Werte, AE und MR; den Rest
/// passt der Meister an das größere Tier an.
class _MachtvollWerteForm extends StatelessWidget {
  const _MachtvollWerteForm({
    required this.art,
    required this.artName,
    required this.werte,
    required this.angriffe,
    required this.tempi,
    required this.onWert,
    required this.onAngriff,
    required this.onTempo,
  });

  final VertrautenArtDef art;
  final TextEditingController artName;
  final Map<String, int> werte;
  final List<VertrautenAngriffDef> angriffe;
  final List<VertrautenTempoDef> tempi;
  final void Function(String key, int wert) onWert;
  final void Function(int index, VertrautenAngriffDef angriff) onAngriff;
  final void Function(int index, VertrautenTempoDef tempo) onTempo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey<String>('vertrauten-machtvoll-name'),
          controller: artName,
          decoration: InputDecoration(
            labelText: 'Art des Tiers',
            hintText: 'z. B. Luchs (Vorlage: ${art.name})',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Die Vorlage bestimmt die Vertrautenzauber. Mit „AP“ markierte Werte '
          'kosten je Punkt über der Vorlage 2 AP, über dem Maximum zusätzlich '
          '5 AP; körperliche Werte und Kampfwerte legt der Meister ohne Kosten '
          'fest.',
          style: muted,
        ),
        for (final key in kVertrautenFreieWertKeys)
          _WertStepper(
            key: ValueKey<String>('vertrauten-machtvoll-$key'),
            label:
                '${_kFreieWertLabels[key]}'
                '${kVertrautenGeistigeKeys.contains(key) ? ' · AP' : ''} '
                '(Vorlage ${vertrautenVorlagenwert(art, key)})',
            wert: werte[key] ?? vertrautenVorlagenwert(art, key),
            onChanged: (v) => onWert(key, v),
          ),
        if (angriffe.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Angriffe (DK H)', style: theme.textTheme.labelMedium),
          for (var i = 0; i < angriffe.length; i++) ...[
            _WertStepper(
              label: '${angriffe[i].name} AT',
              wert: angriffe[i].at,
              onChanged: (v) => onAngriff(i, _mitAngriff(angriffe[i], at: v)),
            ),
            _WertStepper(
              label: '${angriffe[i].name} PA',
              wert: angriffe[i].pa,
              onChanged: (v) => onAngriff(i, _mitAngriff(angriffe[i], pa: v)),
            ),
            TextFormField(
              initialValue: angriffe[i].tp,
              decoration: InputDecoration(labelText: '${angriffe[i].name} TP'),
              onChanged: (v) => onAngriff(i, _mitAngriff(angriffe[i], tp: v)),
            ),
          ],
        ],
        const SizedBox(height: 8),
        Text('Geschwindigkeit', style: theme.textTheme.labelMedium),
        for (var i = 0; i < tempi.length; i++)
          _WertStepper(
            label: 'GS ${tempi[i].art}',
            wert: tempi[i].wert,
            onChanged: (v) => onTempo(i, VertrautenTempoDef(tempi[i].art, v)),
          ),
      ],
    );
  }

  static VertrautenAngriffDef _mitAngriff(
    VertrautenAngriffDef a, {
    int? at,
    int? pa,
    String? tp,
  }) => VertrautenAngriffDef(
    name: a.name,
    at: at ?? a.at,
    pa: pa ?? a.pa,
    tp: tp ?? a.tp,
  );
}

// Eine Zeile mit −/+ für einen absoluten Wert (nicht unter 0).
class _WertStepper extends StatelessWidget {
  const _WertStepper({
    super.key,
    required this.label,
    required this.wert,
    required this.onChanged,
  });

  final String label;
  final int wert;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: '$label senken',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove, size: 18),
          onPressed: wert > 0 ? () => onChanged(wert - 1) : null,
        ),
        SizedBox(width: 32, child: Text('$wert', textAlign: TextAlign.center)),
        IconButton(
          tooltip: '$label erhöhen',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add, size: 18),
          onPressed: () => onChanged(wert + 1),
        ),
      ],
    );
  }
}
