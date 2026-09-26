import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_rahmen.dart';

/// Hervorgehobene Konto-Karte fuer den leeren Heldenstart ohne Login.
///
/// Wer auf einem neuen Geraet startet, hat seine Helden meist schon im Konto.
/// Deshalb steht die Anmeldung dort vor dem Anlegen eines neuen Helden.
class HeroHomeAccountPrompt extends StatelessWidget {
  /// Erstellt die Karte mit beiden Einstiegen in den Login-Bildschirm.
  const HeroHomeAccountPrompt({
    super.key,
    required this.onSignIn,
    required this.onRegister,
  });

  /// Oeffnet den Login.
  final VoidCallback onSignIn;

  /// Oeffnet die Registrierung.
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);
    // Unter Kartograph eine Kartusche: feld mit Messingkante oben, statt des
    // Rahmens in der Interaktionsfarbe.
    final karto = kartoVariante(context);

    return Container(
      key: const ValueKey('home-account-prompt'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: karto == null
          ? BoxDecoration(
              color: codex.panelRaised,
              borderRadius: BorderRadius.circular(codex.sectionRadius),
              border: Border.all(color: codex.brass, width: 1.5),
            )
          : ShapeDecoration(
              color: karto.feld,
              shape: KartoRahmen(
                side: BorderSide(
                  color: karto.hoehenlinie,
                  width: Strich.hoehenlinie,
                ),
                akzent: karto.messing,
              ),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_sync_outlined,
            size: 40,
            color: karto?.messing ?? codex.brass,
          ),
          const SizedBox(height: 12),
          Text(
            'Helden schon in einem Konto?',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Melde dich an, um deine Helden von anderen Geräten zu laden und '
            'künftig zu synchronisieren. Ohne Konto bleibt alles lokal.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('home-sign-in'),
                onPressed: onSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Anmelden'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('home-register'),
                onPressed: onRegister,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Konto anlegen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
