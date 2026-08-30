import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Blockiert das Oeffnen eines Helden, solange der Regelkatalog laedt.
///
/// Der Dialog verwaltet seine Lebensdauer **selbst**, und das ist der Kern
/// dieser Klasse: Frueher schloss ihn der Aufrufer per `Navigator.pop()`, aber
/// nur solange dessen `context.mounted` galt. Die Dialog-Route haengt jedoch am
/// Root-Navigator der `MaterialApp`, waehrend `SyncConflictGate` den
/// `HeroesHomeScreen` darunter jederzeit austauschen kann. Genau dann blieb ein
/// `canPop: false`-Dialog ohne Barrier-Tap und ohne Zurueck-Weg stehen — die
/// App war hart blockiert.
///
/// Zusaetzlich endet das Warten nach [timeout], statt unbegrenzt zu drehen.
class CatalogPreparationDialog extends StatefulWidget {
  const CatalogPreparationDialog({
    super.key,
    required this.task,
    required this.timeout,
    required this.onRetry,
  });

  /// Laufender Katalog-Ladevorgang.
  final Future<void> task;

  /// Zeit, nach der ein nicht abgeschlossener Ladevorgang als Fehlschlag gilt.
  final Duration timeout;

  /// Startet einen echten neuen Ladeversuch und liefert dessen Future.
  final Future<void> Function() onRetry;

  @override
  State<CatalogPreparationDialog> createState() =>
      _CatalogPreparationDialogState();
}

class _CatalogPreparationDialogState extends State<CatalogPreparationDialog> {
  Object? _error;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    unawaited(_observe(widget.task));
  }

  /// Begleitet einen Ladeversuch und schliesst den Dialog bei Erfolg selbst.
  Future<void> _observe(Future<void> task) async {
    try {
      await task.timeout(widget.timeout);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _timedOut = true;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _timedOut = false;
        _error = error;
      });
    }
  }

  void _retry() {
    setState(() {
      _timedOut = false;
      _error = null;
    });
    unawaited(_observe(widget.onRetry()));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final failed = _timedOut || error != null;

    if (!failed) {
      return const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Flexible(child: Text('Regelkatalog wird vorbereitet ...')),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Regelkatalog nicht bereit'),
      content: Text(
        _timedOut
            ? 'Der Regelkatalog braucht ungewöhnlich lange. Du kannst es '
                  'erneut versuchen oder abbrechen und später weitermachen.'
            : 'Der Regelkatalog konnte nicht geladen werden.\n\n$error',
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('catalog-preparation-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('catalog-preparation-retry'),
          onPressed: _retry,
          child: const Text('Erneut versuchen'),
        ),
      ],
    );
  }
}

class CreateHeroDialog extends StatefulWidget {
  const CreateHeroDialog({super.key});

  @override
  State<CreateHeroDialog> createState() => _CreateHeroDialogState();
}

class _CreateHeroDialogState extends State<CreateHeroDialog> {
  late final TextEditingController _nameController;
  late final Map<String, TextEditingController> _attributeControllers;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _attributeControllers = <String, TextEditingController>{
      'mu': TextEditingController(text: '11'),
      'kl': TextEditingController(text: '11'),
      'inn': TextEditingController(text: '11'),
      'ch': TextEditingController(text: '11'),
      'ff': TextEditingController(text: '11'),
      'ge': TextEditingController(text: '11'),
      'ko': TextEditingController(text: '11'),
      'kk': TextEditingController(text: '11'),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _attributeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuen Helden anlegen'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: kDialogWidthSmall,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey<String>('create-hero-name'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _attributeFields(_attributeControllers),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              CreateHeroDraft(
                name: _nameController.text.trim(),
                rawStartAttributes: Attributes(
                  mu: _readCreateAttributeValue(_attributeControllers, 'mu'),
                  kl: _readCreateAttributeValue(_attributeControllers, 'kl'),
                  inn: _readCreateAttributeValue(_attributeControllers, 'inn'),
                  ch: _readCreateAttributeValue(_attributeControllers, 'ch'),
                  ff: _readCreateAttributeValue(_attributeControllers, 'ff'),
                  ge: _readCreateAttributeValue(_attributeControllers, 'ge'),
                  ko: _readCreateAttributeValue(_attributeControllers, 'ko'),
                  kk: _readCreateAttributeValue(_attributeControllers, 'kk'),
                ),
              ),
            );
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }

  List<Widget> _attributeFields(
    Map<String, TextEditingController> attributeControllers,
  ) {
    final labels = <(String, String)>[
      ('MU', 'mu'),
      ('KL', 'kl'),
      ('IN', 'inn'),
      ('CH', 'ch'),
      ('FF', 'ff'),
      ('GE', 'ge'),
      ('KO', 'ko'),
      ('KK', 'kk'),
    ];

    return labels
        .map(
          (entry) => SizedBox(
            width: 88,
            child: TextField(
              key: ValueKey<String>('create-hero-${entry.$2}'),
              controller: attributeControllers[entry.$2],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: entry.$1,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  int _readCreateAttributeValue(
    Map<String, TextEditingController> attributeControllers,
    String key,
  ) {
    final value = int.tryParse(attributeControllers[key]!.text.trim()) ?? 8;
    if (value < 0) {
      return 0;
    }
    if (value > 99) {
      return 99;
    }
    return value;
  }
}

class CreateHeroDraft {
  const CreateHeroDraft({required this.name, required this.rawStartAttributes});

  final String name;
  final Attributes rawStartAttributes;
}
