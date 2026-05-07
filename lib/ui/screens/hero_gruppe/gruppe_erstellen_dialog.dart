import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Zeigt einen Dialog zum Erstellen einer neuen Gruppe.
///
/// Gibt den generierten Gruppencode zurueck, oder `null` bei Abbruch.
Future<String?> showGruppeErstellenDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
}) {
  return showAdaptiveInputDialog<String>(
    context: context,
    builder: (context) => _GruppeErstellenDialog(
      heroId: heroId,
      ref: ref,
    ),
  );
}

class _GruppeErstellenDialog extends StatefulWidget {
  const _GruppeErstellenDialog({
    required this.heroId,
    required this.ref,
  });

  final String heroId;
  final WidgetRef ref;

  @override
  State<_GruppeErstellenDialog> createState() =>
      _GruppeErstellenDialogState();
}

class _GruppeErstellenDialogState extends State<_GruppeErstellenDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveInputDialog(
      title: 'Neue Gruppe erstellen',
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Gruppenname',
          hintText: 'z.B. Die Thorwaler',
        ),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _erstellen(),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _erstellen,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Erstellen'),
        ),
      ],
    );
  }

  Future<void> _erstellen() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final code = await widget.ref.read(heroActionsProvider).erstelleGruppe(
            heroId: widget.heroId,
            gruppenName: name,
          );
      if (mounted) Navigator.of(context).pop(code);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $error')),
      );
    }
  }
}
