import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Oeffnet einen Dialog zur Eingabe des Katalog-Inhaltspassworts.
///
/// Gibt `true` zurueck wenn das Passwort korrekt war und die Session
/// freigeschaltet wurde, sonst `false`.
Future<bool> showCatalogUnlockDialog({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _CatalogUnlockDialog(ref: ref),
  );
  return result ?? false;
}

class _CatalogUnlockDialog extends StatefulWidget {
  const _CatalogUnlockDialog({required this.ref});

  final WidgetRef ref;

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

  void _submit() {
    final input = _controller.text.trim();
    final stored = widget.ref
        .read(appSettingsProvider)
        .valueOrNull
        ?.catalogContentPassword;
    if (stored == null || stored.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    if (input == stored) {
      widget.ref.read(catalogContentUnlockedProvider.notifier).state = true;
      Navigator.of(context).pop(true);
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
