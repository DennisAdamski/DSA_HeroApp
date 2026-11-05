import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_gruppe_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_vorschau_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/hero_regelprofil_section.dart';

/// Regelprofil-Vorgabe einer Konto-Gruppe (ARCH-04).
///
/// Zeigt die Vorgabe der Gruppe, lässt den Helden diese Gruppe zur primären
/// machen (nur ihr Regelprofil wird dem Helden angeboten) und gibt dem
/// Besitzer die Möglichkeit, sein Profil als Vorgabe zu setzen. Die Karte
/// ändert nie das Profil eines Helden.
class GruppeRegelprofilKarte extends ConsumerWidget {
  /// Erstellt die Karte für [gruppenCode] aus Sicht von [heroId].
  const GruppeRegelprofilKarte({
    super.key,
    required this.heroId,
    required this.gruppenCode,
  });

  /// Held, dessen Gruppenansicht offen ist.
  final String heroId;

  /// ID der Konto-Gruppe.
  final String gruppenCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final leise = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final vorgabe = ref.watch(gruppenRegelVorgabeProvider(gruppenCode));
    final istBesitzer =
        ref
            .watch(gruppenAnsichtProvider(gruppenCode))
            .valueOrNull
            ?.istBesitzer ??
        false;
    final primaer =
        ref.watch(heroPrimaereGruppeProvider(heroId))?.gruppenCode ==
        gruppenCode;
    final profil = vorgabe.valueOrNull;

    final Widget vorgabeText;
    if (vorgabe.hasError && profil == null) {
      vorgabeText = Text(
        'Die Regelvorgabe konnte nicht geladen werden.',
        key: const ValueKey<String>('gruppe-regelprofil-fehler'),
        style: leise,
      );
    } else if (vorgabe.isLoading && profil == null) {
      vorgabeText = const LinearProgressIndicator();
    } else if (profil == null) {
      vorgabeText = Text(
        'Die Gruppe gibt kein Regelprofil vor.',
        key: const ValueKey<String>('gruppe-regelprofil-leer'),
        style: theme.textTheme.bodyMedium,
      );
    } else {
      vorgabeText = Column(
        key: const ValueKey<String>('gruppe-regelprofil-pakete'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vorgabe (Katalog ${profil.catalogVersion}):',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          if (profil.pakete.isEmpty)
            Text('• keine Hausregelpakete', style: theme.textTheme.bodyMedium)
          else
            for (final p in profil.pakete)
              Text(
                '• ${regelprofilPaketTitel(p)}',
                style: theme.textTheme.bodyMedium,
              ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Regelprofil der Gruppe', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Ein Held kann mehreren Gruppen angehören, folgt aber nur dem '
              'Regelprofil seiner primären Gruppe. Eine geänderte Vorgabe '
              'wird ihm als Vorschau angeboten und nie von selbst übernommen.',
              style: leise,
            ),
            const SizedBox(height: 12),
            vorgabeText,
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (primaer)
                  const Chip(
                    key: ValueKey<String>('gruppe-regelprofil-primaer'),
                    avatar: Icon(Icons.star, size: 18),
                    label: Text('Primäre Gruppe'),
                  )
                else
                  OutlinedButton.icon(
                    key: const ValueKey<String>(
                      'gruppe-regelprofil-primaer-setzen',
                    ),
                    onPressed: () => _primaerSetzen(context, ref),
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Als primäre Gruppe festlegen'),
                  ),
                if (istBesitzer)
                  FilledButton.tonalIcon(
                    key: const ValueKey<String>('gruppe-regelprofil-setzen'),
                    onPressed: () => _vorgabeSetzen(context, ref),
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Mein Regelprofil als Vorgabe'),
                  ),
                if (istBesitzer && profil != null)
                  TextButton.icon(
                    key: const ValueKey<String>('gruppe-regelprofil-entfernen'),
                    onPressed: () => _vorgabeEntfernen(context, ref),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Vorgabe entfernen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _primaerSetzen(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(heroActionsProvider)
          .setzePrimaereGruppe(heroId: heroId, gruppenCode: gruppenCode);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Primäre Gruppe festgelegt. Das Regelprofil des Helden bleibt '
            'unverändert.',
          ),
        ),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $error')));
    }
  }

  Future<void> _vorgabeSetzen(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    // Das Profil des Helden, sonst der globale Stand, den er heute hat.
    final HeroRegelProfil? profil =
        ref.read(heroRegelProfilProvider(heroId)) ??
        ref.read(globalesRegelProfilProvider).valueOrNull;
    if (profil == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Das Regelprofil ist noch nicht berechnet.'),
        ),
      );
      return;
    }
    final ja = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regelprofil als Gruppenvorgabe?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Die Gruppe gibt danach diese Hausregelpakete vor. Mitglieder, '
                'für die sie die primäre Gruppe ist, bekommen die Vorgabe als '
                'Vorschau angeboten; niemand wird automatisch umgestellt.',
              ),
              const SizedBox(height: 8),
              if (profil.pakete.isEmpty)
                const Text('• keine Hausregelpakete')
              else
                for (final p in profil.pakete)
                  Text('• ${regelprofilPaketTitel(p)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const ValueKey<String>('gruppe-regelprofil-setzen-ok'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vorgabe setzen'),
          ),
        ],
      ),
    );
    if (ja != true) return;
    try {
      await ref
          .read(heroActionsProvider)
          .veroeffentlicheRegelVorgabe(
            gruppenCode: gruppenCode,
            profil: profil,
          );
      ref.invalidate(gruppenRegelVorgabeProvider(gruppenCode));
      messenger.showSnackBar(
        const SnackBar(content: Text('Regelprofil-Vorgabe gesetzt')),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $error')));
    }
  }

  Future<void> _vorgabeEntfernen(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ja = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vorgabe entfernen?'),
        content: const Text(
          'Die Gruppe gibt danach kein Regelprofil mehr vor. Helden, die die '
          'Vorgabe übernommen haben, behalten ihr Profil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const ValueKey<String>('gruppe-regelprofil-entfernen-ok'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (ja != true) return;
    try {
      await ref.read(heroActionsProvider).entferneRegelVorgabe(gruppenCode);
      ref.invalidate(gruppenRegelVorgabeProvider(gruppenCode));
      messenger.showSnackBar(
        const SnackBar(content: Text('Regelprofil-Vorgabe entfernt')),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $error')));
    }
  }
}
