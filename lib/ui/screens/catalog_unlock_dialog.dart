import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Oeffnet einen Dialog zur Eingabe des Katalog-Entschluesselungspassworts.
///
/// Das Passwort wird durch Probe-Entschluesselung eines verschluesselten
/// Katalogwerts validiert. Bei Erfolg wird es in den App-Einstellungen
/// persistiert und der Dialog gibt `true` zurueck.
Future<bool> showCatalogUnlockDialog({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  // Auf den Katalog warten — sonst greift `valueOrNull` ins Leere, solange der
  // Provider noch laedt (typisch nach Tab-/App-Start im Web), und der Dialog
  // wuerde stillschweigend nicht oeffnen.
  final RulesCatalog catalog;
  try {
    catalog = await ref.read(rulesCatalogProvider.future);
  } on Object {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Katalog konnte nicht geladen werden.')),
    );
    return false;
  }

  // Ersten verschluesselten Wert aus dem Katalog als Probe verwenden.
  String? probeValue;
  for (final m in catalog.maneuvers) {
    if (isEncryptedValue(m.erklarungLang)) {
      probeValue = m.erklarungLang;
      break;
    }
  }
  if (probeValue == null) {
    for (final a in catalog.combatSpecialAbilities) {
      if (isEncryptedValue(a.erklarungLang)) {
        probeValue = a.erklarungLang;
        break;
      }
    }
  }
  if (probeValue == null) {
    for (final s in catalog.spells) {
      if (isEncryptedValue(s.wirkung)) {
        probeValue = s.wirkung;
        break;
      }
    }
  }

  if (!context.mounted) return false;

  if (probeValue == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Keine geschuetzten Katalog-Inhalte vorhanden.'),
      ),
    );
    return false;
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _CatalogUnlockDialog(ref: ref, probeValue: probeValue!),
  );
  return result ?? false;
}

class _CatalogUnlockDialog extends StatefulWidget {
  const _CatalogUnlockDialog({
    required this.ref,
    required this.probeValue,
  });

  final WidgetRef ref;
  final String probeValue;

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
    // Validierung durch Probe-Entschluesselung.
    final decrypted = decryptCatalogValue(widget.probeValue, input);
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
    return AlertDialog(
      title: const Text('Katalog-Inhalte freischalten'),
      content: SizedBox(
        width: 320,
        child: TextField(
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
