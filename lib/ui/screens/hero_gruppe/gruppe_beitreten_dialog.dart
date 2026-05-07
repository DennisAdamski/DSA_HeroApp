import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Zeigt einen Dialog zum Beitreten einer bestehenden Gruppe via Code.
///
/// Gibt den Gruppencode zurueck, oder `null` bei Abbruch.
Future<String?> showGruppeBeitretenDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
}) {
  return showAdaptiveInputDialog<String>(
    context: context,
    builder: (context) => _GruppeBeitretenDialog(
      heroId: heroId,
      ref: ref,
    ),
  );
}

class _GruppeBeitretenDialog extends StatefulWidget {
  const _GruppeBeitretenDialog({
    required this.heroId,
    required this.ref,
  });

  final String heroId;
  final WidgetRef ref;

  @override
  State<_GruppeBeitretenDialog> createState() =>
      _GruppeBeitretenDialogState();
}

class _GruppeBeitretenDialogState extends State<_GruppeBeitretenDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _fehler;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveInputDialog(
      title: 'Gruppe beitreten',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Gib den Gruppencode ein, den du von einem '
            'Gruppenmitglied erhalten hast.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Gruppencode',
              hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              errorText: _fehler,
            ),
            onSubmitted: (_) => _beitreten(),
            onChanged: (_) {
              if (_fehler != null) setState(() => _fehler = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _beitreten,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Beitreten'),
        ),
      ],
    );
  }

  Future<void> _beitreten() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _fehler = 'Bitte Code eingeben');
      return;
    }

    setState(() {
      _isLoading = true;
      _fehler = null;
    });

    try {
      await widget.ref.read(heroActionsProvider).trittGruppeBei(
            heroId: widget.heroId,
            gruppenCode: code,
          );
      if (mounted) Navigator.of(context).pop(code);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _fehler = error.message;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _fehler = 'Fehler: $error';
      });
    }
  }
}
