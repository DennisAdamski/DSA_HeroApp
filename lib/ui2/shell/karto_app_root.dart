import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_shell.dart';

/// Waehlt zwischen bestehender und neuer Oberflaeche.
///
/// Dies ist die einzige Stelle, an der beide Oberflaechen aufeinandertreffen,
/// und damit die einzige Datei unter `lib/ui2/`, die aus `lib/ui/` importiert.
///
/// Die Weiche sitzt bewusst unterhalb von `SyncConflictGate` und innerhalb des
/// von `AppStartupGate` aufgebauten `ProviderScope`: ein zweites Gate wuerde
/// Heldenspeicher, Sync und Katalog ein zweites Mal aufbauen. Weil der
/// Settings-Listener des Gates nur auf `heroStoragePath` reagiert, tauscht ein
/// Wechsel hier nur diesen Teilbaum aus und laesst alles darunter stehen.
///
/// Mit der alten Oberflaeche faellt auch diese Datei wieder weg.
class AppRootSwitch extends ConsumerWidget {
  /// Erstellt die Weiche zwischen den Oberflaechen.
  const AppRootSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(oberflaecheProvider)) {
      Oberflaeche.codex => const HeroesHomeScreen(),
      Oberflaeche.kartograph => const KartoShell(),
    };
  }
}
