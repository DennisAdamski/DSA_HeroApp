import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
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
  // Ersten verschluesselten Wert aus dem Katalog als Probe verwenden.
  final catalog = ref.read(rulesCatalogProvider).valueOrNull;
  String? probeValue;
  if (catalog != null) {
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
  }

  if (probeValue == null) {
    // Kein verschluesselter Inhalt vorhanden — nichts zu entsperren.
    return false;
  }

  if (!context.mounted) return false;
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
  String? _errorText;

  @override
  void dispose() {
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
          obscureText: true,
          autofocus: true,
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
