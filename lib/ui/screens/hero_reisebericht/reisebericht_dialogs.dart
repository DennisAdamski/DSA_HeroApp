part of 'package:dsa_heldenverwaltung/ui/screens/hero_reisebericht_tab.dart';

// ---------------------------------------------------------------------------
// Ruecknahme-Bestaetigungsdialog
// ---------------------------------------------------------------------------

/// Bestaetigungsdialog fuer die Ruecknahme eines bereits angewendeten Eintrags.
class _RevokeConfirmDialog extends StatelessWidget {
  const _RevokeConfirmDialog({required this.buchung});

  /// Was die Änderung an der Buchung bewirkt; [ReiseberichtBuchung.zurueck]
  /// ist nicht leer.
  final ReiseberichtBuchung buchung;

  static List<String> _teile(ReiseberichtRewards rewards) {
    return <String>[
      if (rewards.ap > 0) '${rewards.ap} AP',
      for (final se in rewards.seRewards) 'SE auf ${se.talentName}',
      for (final tb in rewards.talentBoni) '+${tb.wert} ${tb.talentName}',
      for (final eb in rewards.eigenschaftsBoni)
        '+${eb.wert} ${eb.eigenschaft.toUpperCase()}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final farben = _ReiseberichtFarben.von(context);
    final zurueck = _teile(buchung.zurueck);
    final neu = _teile(buchung.neu);

    Widget zeile(String text, IconData icon, Color farbe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: farbe),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
    }

    return AlertDialog(
      title: const Text('Belohnungen zurücknehmen?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Beim Speichern werden diese Belohnungen rückgängig gemacht:',
          ),
          const SizedBox(height: 12),
          for (final teil in zurueck)
            zeile(teil, Icons.remove_circle_outline, farben.fehler),
          if (neu.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Stattdessen gebucht:'),
            const SizedBox(height: 8),
            for (final teil in neu)
              zeile(teil, Icons.add_circle_outline, farben.erledigt),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Zurücknehmen'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog: Offenen Eintrag hinzufuegen (collection_open)
// ---------------------------------------------------------------------------

class _OpenItemAddDialog extends StatefulWidget {
  const _OpenItemAddDialog({required this.def});

  final ReiseberichtDef def;

  @override
  State<_OpenItemAddDialog> createState() => _OpenItemAddDialogState();
}

class _OpenItemAddDialogState extends State<_OpenItemAddDialog> {
  final _nameController = TextEditingController();
  String _selectedKlassifikation = '';
  int _computedAp = 0;

  @override
  void initState() {
    super.initState();
    if (widget.def.klassifikationen.isNotEmpty) {
      _selectedKlassifikation = widget.def.klassifikationen.first.id;
      _computedAp = widget.def.klassifikationen.first.ap;
    } else {
      _computedAp = widget.def.apProEintrag;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasKlassifikationen = widget.def.klassifikationen.isNotEmpty;

    return AdaptiveInputDialog(
      title: '${widget.def.name}: Eintrag hinzufuegen',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.def.beschreibung.isNotEmpty) ...[
            Text(
              widget.def.beschreibung,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Bezeichnung',
              border: OutlineInputBorder(),
            ),
          ),
          if (hasKlassifikationen) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedKlassifikation,
              decoration: const InputDecoration(
                labelText: 'Klassifikation',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final k in widget.def.klassifikationen)
                  DropdownMenuItem(
                    value: k.id,
                    child: Text('${k.name} (+${k.ap} AP)'),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                final klass = widget.def.klassifikationen
                    .where((k) => k.id == value)
                    .firstOrNull;
                setState(() {
                  _selectedKlassifikation = value;
                  _computedAp = klass?.ap ?? widget.def.apProEintrag;
                });
              },
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'AP: +$_computedAp',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _ReiseberichtFarben.von(context).belohnungText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              ReiseberichtOpenItem(
                name: name,
                klassifikation: _selectedKlassifikation,
                ap: _computedAp,
              ),
            );
          },
          child: const Text('Hinzufuegen'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog: Wahl-SE Zuordnung
// ---------------------------------------------------------------------------

/// Dialog zur Auswahl des Ziel-Talents fuer eine Wahl-SE.
class _WahlSeDialog extends StatefulWidget {
  const _WahlSeDialog({
    required this.entryName,
    required this.seDef,
    required this.currentChoice,
  });

  final String entryName;
  final ReiseberichtSeDef seDef;
  final String? currentChoice;

  @override
  State<_WahlSeDialog> createState() => _WahlSeDialogState();
}

class _WahlSeDialogState extends State<_WahlSeDialog> {
  late String? _selected;
  final _customController = TextEditingController();

  bool get _hasOptions => widget.seDef.optionen.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentChoice;
    if (!_hasOptions && widget.currentChoice != null) {
      _customController.text = widget.currentChoice!;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveInputDialog(
      title: 'SE-Ziel wählen: ${widget.entryName}',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.seDef.name,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (_hasOptions)
            RadioGroup<String>(
              groupValue: _selected ?? '',
              onChanged: (value) => setState(() => _selected = value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in widget.seDef.optionen)
                    RadioListTile<String>(title: Text(option), value: option),
                ],
              ),
            )
          else
            TextField(
              controller: _customController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Talentname',
                border: OutlineInputBorder(),
                hintText: 'z. B. Schwerter, Reiten, ...',
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final result = _hasOptions
                ? _selected
                : _customController.text.trim();
            if (result == null || result.isEmpty) return;
            Navigator.of(context).pop(result);
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
