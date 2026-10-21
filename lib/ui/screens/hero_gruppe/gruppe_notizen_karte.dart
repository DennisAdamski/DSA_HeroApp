import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Gemeinsame Notizen einer Gruppe, die alle Mitglieder lesen und ändern.
class GruppeNotizenKarte extends ConsumerStatefulWidget {
  /// Erstellt die Notizenkarte für die Gruppe [gruppenCode].
  const GruppeNotizenKarte({super.key, required this.gruppenCode});

  /// ID der Konto-Gruppe.
  final String gruppenCode;

  @override
  ConsumerState<GruppeNotizenKarte> createState() => _GruppeNotizenKarteState();
}

class _GruppeNotizenKarteState extends ConsumerState<GruppeNotizenKarte> {
  final _controller = TextEditingController();
  String? _geladen;
  bool _speichert = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _geaendert => _controller.text != (_geladen ?? '');

  @override
  Widget build(BuildContext context) {
    final notizen = ref.watch(gruppenNotizenProvider(widget.gruppenCode));
    final theme = Theme.of(context);

    // Nur den ersten Ladestand übernehmen; spätere Eingaben nie überschreiben.
    final text = notizen.valueOrNull;
    if (text != null && _geladen == null) {
      _geladen = text;
      _controller.text = text;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gemeinsame Notizen', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Alle Mitglieder der Gruppe können diese Notizen lesen und '
              'ändern.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (notizen.hasError && _geladen == null)
              Text(
                'Die Notizen konnten nicht geladen werden.',
                style: theme.textTheme.bodySmall,
              )
            else if (_geladen == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              TextField(
                controller: _controller,
                minLines: 3,
                maxLines: 8,
                maxLength: 20000,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'z. B. Treffpunkt, offene Aufträge, Vorräte …',
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _geaendert && !_speichert ? _speichern : null,
                  child: const Text('Notizen speichern'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _speichern() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _speichert = true);
    try {
      await ref
          .read(heroActionsProvider)
          .speichereGruppenNotizen(
            gruppenCode: widget.gruppenCode,
            text: _controller.text,
          );
      _geladen = _controller.text;
      messenger.showSnackBar(
        const SnackBar(content: Text('Notizen gespeichert')),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $error')));
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }
}
