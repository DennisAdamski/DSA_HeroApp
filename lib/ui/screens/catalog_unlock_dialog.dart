import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Oeffnet einen Dialog zur Eingabe des Katalog-Entschluesselungspassworts.
///
/// Das Passwort wird durch Probe-Entschluesselung eines verschluesselten
/// Katalogwerts validiert. Bei Erfolg wird es in den App-Einstellungen
/// persistiert und der Dialog gibt `true` zurueck.
Future<bool> showCatalogUnlockDialog({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  // Roh-Quelle benutzen, nicht den bulk-entschluesselten Katalog: hier sind
  // die Werte garantiert noch verschluesselt, unabhaengig davon ob ein
  // Passwort gespeichert ist (sonst ware der Dialog nach Setzen des
  // Passworts nutzlos, weil keine `enc:`-Werte mehr gefunden werden).
  final CatalogSourceData sourceData;
  try {
    sourceData = await ref.read(baseCatalogSourceDataProvider.future);
  } on Object {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Katalog konnte nicht geladen werden.')),
    );
    return false;
  }

  final probeValue = _findProbeEncryptedValue(sourceData);

  if (!context.mounted) return false;

  if (probeValue == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Keine geschuetzten Katalog-Inhalte vorhanden.'),
      ),
    );
    return false;
  }

  final result = await showAdaptiveInputDialog<bool>(
    context: context,
    builder: (_) => _CatalogUnlockDialog(
      ref: ref,
      probeValue: probeValue,
      saltV3: sourceData.catalogSaltV3,
    ),
  );
  return result ?? false;
}

/// Sucht einen `enc:`-Wert in den geschuetzten Asset-Sektionen, der als
/// Probe fuer die Passwort-Validierung dient.
///
/// Reihenfolge: Manoever → Kampf-Sonderfertigkeiten → Zauber. Felder werden
/// per String-Lookup gepruefft, weil die [CatalogSourceData] Roh-Maps haelt.
String? _findProbeEncryptedValue(CatalogSourceData sourceData) {
  const sectionFieldCandidates = <(CatalogSectionId, List<String>)>[
    (CatalogSectionId.maneuvers, <String>['erklarung_lang']),
    (CatalogSectionId.combatSpecialAbilities, <String>['erklarung_lang']),
    (CatalogSectionId.spells, <String>['wirkung', 'variants']),
  ];
  for (final (section, fields) in sectionFieldCandidates) {
    for (final entry in sourceData.entriesFor(section)) {
      for (final field in fields) {
        final value = entry[field];
        if (value is String && isEncryptedValue(value)) {
          return value;
        }
      }
    }
  }
  return null;
}

class _CatalogUnlockDialog extends StatefulWidget {
  const _CatalogUnlockDialog({
    required this.ref,
    required this.probeValue,
    required this.saltV3,
  });

  final WidgetRef ref;
  final String probeValue;
  final Uint8List? saltV3;

  @override
  State<_CatalogUnlockDialog> createState() => _CatalogUnlockDialogState();
}

class _CatalogUnlockDialogState extends State<_CatalogUnlockDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // Mobile-Browser ignorieren `autofocus` beim Dialog-Aufbau gerne — Fokus
    // explizit nach dem ersten Frame anfordern, damit die Soft-Tastatur
    // zuverlaessig hochkommt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorText = 'Bitte Passwort eingeben.';
      });
      return;
    }
    // Validierung durch Probe-Entschluesselung. Bei v3-Werten wird der
    // catalog_salt_v3 aus dem Manifest mitgegeben.
    final decrypted = decryptCatalogValue(
      widget.probeValue,
      input,
      saltV3: widget.saltV3,
    );
    if (decrypted != null) {
      // Passwort korrekt — dauerhaft persistieren.
      await widget.ref
          .read(settingsActionsProvider)
          .setCatalogContentPassword(input);
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorText = 'Falsches Passwort.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveInputDialog(
      title: 'Katalog-Inhalte freischalten',
      maxWidth: 360,
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        obscureText: true,
        autofocus: true,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Passwort',
          border: const OutlineInputBorder(),
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Freischalten'),
        ),
      ],
    );
  }
}
