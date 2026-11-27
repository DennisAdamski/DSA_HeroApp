import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dsa_heldenverwaltung/data/freesound/freesound_client.dart';
import 'package:dsa_heldenverwaltung/state/klangkulisse_providers.dart';

/// Anmeldung mit dem eigenen Freesound-Konto („Mit Freesound anmelden“).
///
/// Öffnet die Freesound-Seite im Browser; dort stimmt die Nutzerin zu und
/// kopiert den angezeigten Code zurück in die App. So braucht keine Plattform
/// einen eigenen Rücksprung. Steht in den Einstellungen („Vernetzte Dienste“)
/// und im Klangpult.
class FreesoundAnmeldungBereich extends ConsumerWidget {
  /// Erstellt den Bereich.
  const FreesoundAnmeldungBereich({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texte = Theme.of(context).textTheme;
    if (ref.watch(freesoundOAuthProvider) == null) {
      return Text(
        'Freesound ist in diesem Build nicht eingerichtet.',
        style: texte.bodyMedium,
      );
    }
    final zugang = ref.watch(freesoundZugangProvider);
    if (zugang.isLoading && !zugang.hasValue) {
      return const LinearProgressIndicator();
    }
    final angemeldet = zugang.asData?.value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          angemeldet
              ? 'Mit deinem Freesound-Konto verbunden. Die Anmeldung bleibt '
                    'nur auf diesem Gerät gespeichert.'
              : 'Hintergrundklänge kommen von Freesound. Melde dich mit '
                    'deinem eigenen, kostenlosen Freesound-Konto an.',
          style: texte.bodyMedium,
        ),
        const SizedBox(height: 8),
        if (angemeldet)
          OutlinedButton.icon(
            key: const ValueKey<String>('freesound-abmelden'),
            onPressed: () =>
                ref.read(freesoundZugangProvider.notifier).abmelden(),
            icon: const Icon(Icons.logout),
            label: const Text('Abmelden'),
          )
        else
          FilledButton.tonalIcon(
            key: const ValueKey<String>('freesound-anmelden'),
            onPressed: () => _anmelden(context, ref),
            icon: const Icon(Icons.login),
            label: const Text('Mit Freesound anmelden'),
          ),
      ],
    );
  }

  Future<void> _anmelden(BuildContext context, WidgetRef ref) async {
    final zugang = ref.read(freesoundZugangProvider.notifier);
    final Uri adresse;
    try {
      adresse = zugang.anmeldungStarten();
    } on FreesoundFehler catch (fehler) {
      _melde(context, fehler.meldung);
      return;
    }
    await launchUrl(adresse, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _CodeDialog(adresse: adresse),
    );
  }
}

class _CodeDialog extends ConsumerStatefulWidget {
  const _CodeDialog({required this.adresse});

  final Uri adresse;

  @override
  ConsumerState<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends ConsumerState<_CodeDialog> {
  final TextEditingController _code = TextEditingController();
  bool _laeuft = false;
  String? _fehler;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _bestaetigen() async {
    setState(() {
      _laeuft = true;
      _fehler = null;
    });
    try {
      await ref
          .read(freesoundZugangProvider.notifier)
          .anmeldungAbschliessen(_code.text);
      if (mounted) Navigator.of(context).pop();
    } on FreesoundFehler catch (fehler) {
      if (mounted) {
        setState(() {
          _laeuft = false;
          _fehler = fehler.meldung;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mit Freesound anmelden'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Im Browser hat sich Freesound geöffnet. Melde dich dort an, '
              'erlaube den Zugriff und kopiere den angezeigten Code hierher.',
            ),
            TextButton.icon(
              onPressed: () => launchUrl(
                widget.adresse,
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Freesound erneut öffnen'),
            ),
            TextField(
              key: const ValueKey<String>('freesound-code-feld'),
              controller: _code,
              autofocus: true,
              enabled: !_laeuft,
              decoration: InputDecoration(
                labelText: 'Code',
                errorText: _fehler,
              ),
              onSubmitted: (_) => _bestaetigen(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _laeuft ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('freesound-code-bestaetigen'),
          onPressed: _laeuft ? null : _bestaetigen,
          child: const Text('Anmelden'),
        ),
      ],
    );
  }
}

void _melde(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(text)));
}
