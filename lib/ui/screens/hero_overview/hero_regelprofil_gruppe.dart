import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/rules/derived/regelprofil_vorschau_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_gruppe_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/hero_regelprofil_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

/// Hinweis in der Karte „Regelprofil“: Die primäre Gruppe gibt ein anderes
/// Regelprofil vor (ARCH-04).
///
/// Die Karte rechnet nichts und schreibt nichts. Sie zeigt nur, dass die
/// Vorgabe abweicht, und öffnet die Vorschau; geändert wird der Held erst durch
/// die ausdrückliche Übernahme im Dialog. Ohne primäre Gruppe, ohne Vorgabe,
/// ohne Firestore oder bei gleichem Stand bleibt der Hinweis leer.
class RegelprofilGruppenVorgabeHinweis extends ConsumerWidget {
  /// Erstellt den Hinweis für [heroId].
  const RegelprofilGruppenVorgabeHinweis({super.key, required this.heroId});

  /// Held, dessen primäre Gruppe geprüft wird.
  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vorschau = ref.watch(gruppenVorgabeVorschauProvider(heroId));
    final theme = Theme.of(context);
    final leise = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final v = vorschau.valueOrNull;
    if (v == null) {
      if (!vorschau.hasError) return const SizedBox.shrink();
      // Ohne Verbindung (oder ohne Zugriff) rechnet der Held unverändert mit
      // seinem gespeicherten Profil weiter.
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'Die Regelvorgabe der Gruppe ist gerade nicht abrufbar. Der Held '
          'rechnet mit seinem gespeicherten Profil weiter.',
          key: const ValueKey<String>('regelprofil-gruppe-offline'),
          style: leise,
        ),
      );
    }
    final name = v.gruppenName.isEmpty ? 'Gruppe' : v.gruppenName;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Die primäre Gruppe „$name“ gibt ein anderes Regelprofil vor.',
            key: const ValueKey<String>('regelprofil-gruppe-hinweis'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const ValueKey<String>('regelprofil-gruppe-ansehen'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RegelprofilGruppenVorgabeDialog(heroId: heroId),
            ),
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Gruppenvorgabe ansehen'),
          ),
        ],
      ),
    );
  }
}

/// Vorschau der Gruppenvorgabe mit ausdrücklicher Übernahme.
///
/// Zeigt dieselben Abschnitte wie die Paketupdate-Vorschau. Der Held ändert
/// sich erst mit „Übernehmen“; danach rechnet er mit dem Regelprofil der Gruppe,
/// auch wenn die Gruppe ihre Vorgabe später ändert oder er sie verlässt.
class RegelprofilGruppenVorgabeDialog extends ConsumerStatefulWidget {
  /// Erstellt den Dialog für [heroId].
  const RegelprofilGruppenVorgabeDialog({super.key, required this.heroId});

  /// Held, der die Vorgabe übernehmen soll.
  final String heroId;

  @override
  ConsumerState<RegelprofilGruppenVorgabeDialog> createState() =>
      _RegelprofilGruppenVorgabeDialogState();
}

class _RegelprofilGruppenVorgabeDialogState
    extends ConsumerState<RegelprofilGruppenVorgabeDialog> {
  bool _laeuft = false;

  Future<void> _uebernehmen(RegelProfilVorschau vorschau) async {
    setState(() => _laeuft = true);
    // Das gespeicherte Profil, nicht der Vergleichsstand: Ein Held ohne Profil
    // hat `null`, auch wenn er mit dem globalen Stand verglichen wurde.
    final von = ref.read(heroRegelProfilProvider(widget.heroId));
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Regelprofil',
      aenderung: (held) =>
          uebernehmeRegelProfil(held, von: von, auf: vorschau.auf),
      validationCatalog: vorschau.vergleich.neu.katalog,
    );
    if (!mounted) return;
    setState(() => _laeuft = false);
    if (gespeichert != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vorschau = ref.watch(gruppenVorgabeVorschauProvider(widget.heroId));
    final v = vorschau.valueOrNull;
    final name = v == null || v.gruppenName.isEmpty ? 'Gruppe' : v.gruppenName;
    return ZustandFehlerBereich(
      child: AlertDialog(
        title: const Text('Regelprofil der Gruppe'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const ZustandFehlerAnzeige(),
                if (v != null)
                  RegelprofilVorschauInhalt(
                    vorschau: v.vorschau,
                    einleitung:
                        'Die primäre Gruppe „$name“ gibt dieses Regelprofil '
                        'vor. Der Held rechnet noch mit seinem bisherigen '
                        'Stand. Erst „Übernehmen“ stellt ihn auf die Vorgabe '
                        'um; danach bleibt der Stand auch bestehen, wenn die '
                        'Gruppe ihre Vorgabe ändert oder du sie verlässt.',
                  )
                else
                  Text(
                    vorschau.isLoading
                        ? 'Prüfe Gruppenvorgabe …'
                        : vorschau.hasError
                        ? 'Die Regelvorgabe der Gruppe ist gerade nicht '
                              'abrufbar.'
                        : 'Der Held rechnet bereits mit der Vorgabe der '
                              'Gruppe.',
                    key: const ValueKey<String>('regelprofil-gruppe-status'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey<String>('regelprofil-gruppe-schliessen'),
            onPressed: _laeuft ? null : () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
          if (v != null)
            FilledButton(
              key: const ValueKey<String>('regelprofil-gruppe-uebernehmen'),
              onPressed: _laeuft || !v.vorschau.uebernehmbar
                  ? null
                  : () => _uebernehmen(v.vorschau),
              child: const Text('Übernehmen'),
            ),
        ],
      ),
    );
  }
}
