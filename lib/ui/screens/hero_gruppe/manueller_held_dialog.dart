import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/externer_held.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Zeigt einen Dialog zum manuellen Hinzufuegen eines externen Helden.
Future<void> showManuellerHeldDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required String gruppenCode,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ManuellerHeldDialog(
      heroId: heroId,
      gruppenCode: gruppenCode,
      ref: ref,
    ),
  );
}

class _ManuellerHeldDialog extends StatefulWidget {
  const _ManuellerHeldDialog({
    required this.heroId,
    required this.gruppenCode,
    required this.ref,
  });

  final String heroId;
  final String gruppenCode;
  final WidgetRef ref;

  @override
  State<_ManuellerHeldDialog> createState() => _ManuellerHeldDialogState();
}

class _ManuellerHeldDialogState extends State<_ManuellerHeldDialog> {
  final _nameController = TextEditingController();
  final _rasseController = TextEditingController();
  final _kulturController = TextEditingController();
  final _professionController = TextEditingController();
  final _stufeController = TextEditingController(text: '1');
  final _lepController = TextEditingController(text: '30');
  final _aspController = TextEditingController(text: '0');
  final _auController = TextEditingController(text: '30');
  final _iniController = TextEditingController(text: '10');
  final _notizenController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _rasseController.dispose();
    _kulturController.dispose();
    _professionController.dispose();
    _stufeController.dispose();
    _lepController.dispose();
    _aspController.dispose();
    _auController.dispose();
    _iniController.dispose();
    _notizenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Held manuell hinzufügen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name *'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rasseController,
                    decoration: const InputDecoration(labelText: 'Rasse'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _kulturController,
                    decoration: const InputDecoration(labelText: 'Kultur'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _professionController,
              decoration: const InputDecoration(labelText: 'Profession'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ZahlFeld(controller: _stufeController, label: 'Stufe'),
                const SizedBox(width: 8),
                _ZahlFeld(controller: _lepController, label: 'LeP'),
                const SizedBox(width: 8),
                _ZahlFeld(controller: _aspController, label: 'AsP'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ZahlFeld(controller: _auController, label: 'Au'),
                const SizedBox(width: 8),
                _ZahlFeld(controller: _iniController, label: 'INI'),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notizenController,
              decoration: const InputDecoration(
                labelText: 'Notizen',
                hintText: 'Optionale Anmerkungen',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _hinzufuegen,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Hinzufügen'),
        ),
      ],
    );
  }

  Future<void> _hinzufuegen() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    final held = ExternerHeld(
      id: const Uuid().v4(),
      name: name,
      rasse: _rasseController.text.trim(),
      kultur: _kulturController.text.trim(),
      profession: _professionController.text.trim(),
      level: int.tryParse(_stufeController.text) ?? 1,
      maxLep: int.tryParse(_lepController.text) ?? 30,
      maxAsp: int.tryParse(_aspController.text) ?? 0,
      maxAu: int.tryParse(_auController.text) ?? 30,
      iniBase: int.tryParse(_iniController.text) ?? 10,
      notizen: _notizenController.text.trim(),
      updatedAt: DateTime.now().toUtc(),
    );

    try {
      await widget.ref.read(heroActionsProvider).addManuellerHeld(
            heroId: widget.heroId,
            gruppenCode: widget.gruppenCode,
            held: held,
          );
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $error')),
      );
    }
  }
}

class _ZahlFeld extends StatelessWidget {
  const _ZahlFeld({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }
}
