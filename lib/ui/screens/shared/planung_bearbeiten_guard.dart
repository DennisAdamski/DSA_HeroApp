import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Verbindet eingebettete Verwaltungsansichten mit dem zugehörigen Helden.
///
/// Unteransichten ohne eigene Helden-ID können ihre Editor-Einstiege damit
/// schützen, ohne Persistenz oder Regelberechnungen in den Host zu verlagern.
class PlanungsBearbeitungsBereich extends InheritedWidget {
  /// Umschließt die Verwaltungsansichten genau eines Helden.
  const PlanungsBearbeitungsBereich({
    super.key,
    required this.heroId,
    required super.child,
  });

  /// Held, dessen offene Planung vor Änderungen geprüft wird.
  final String heroId;

  /// Erlaubt eigenständige Ansichten ohne Planungskontext unverändert.
  static Future<bool> bestaetige(BuildContext context) {
    final bereich = context
        .getInheritedWidgetOfExactType<PlanungsBearbeitungsBereich>();
    if (bereich == null) return Future<bool>.value(true);
    return bestaetigeBearbeitungBeiPlanung(
      context: context,
      heroId: bereich.heroId,
    );
  }

  /// Liefert die zugehörige Helden-ID auch für reine Leseansichten.
  static String? heldVon(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PlanungsBearbeitungsBereich>()
        ?.heroId;
  }

  /// Baut abhängige Ansichten bei einem Heldenwechsel neu.
  @override
  bool updateShouldNotify(PlanungsBearbeitungsBereich oldWidget) =>
      heroId != oldWidget.heroId;
}

/// Hält bereits geöffnete Ausrüstungsformulare während einer Planung lesbar.
///
/// Liegt innerhalb des Scrollbereichs, damit Scrollen weiter funktioniert.
/// Fokus und Eingaben ruhen bis zur bestätigten Bearbeitung; der bestehende
/// Formularzustand bleibt unter demselben Schlüssel erhalten.
class PlanungsFormularSchutz extends ConsumerWidget {
  /// Schützt [child] anhand des umgebenden Verwaltungsbereichs.
  const PlanungsFormularSchutz({super.key, required this.child});

  /// Bestehendes Formular mit seinen unveränderten Controllern und Callbacks.
  final Widget child;

  /// Sperrt nur Formulareingaben, nicht den umgebenden Scrollbereich.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroId = PlanungsBearbeitungsBereich.heldVon(context);
    final planungOffen =
        heroId != null && ref.watch(advancementSessionProvider(heroId)) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (planungOffen) ...[
          const Text('Die geplante Entwicklung bleibt beim Ansehen erhalten.'),
          TextButton.icon(
            onPressed: () => PlanungsBearbeitungsBereich.bestaetige(context),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Bearbeiten'),
          ),
        ],
        ExcludeFocus(
          key: const ValueKey('planungs-formular-inhalt'),
          excluding: planungOffen,
          child: AbsorbPointer(absorbing: planungOffen, child: child),
        ),
      ],
    );
  }
}

// Je ProviderScope und Held darf nur eine Rückfrage gleichzeitig laufen.
final _bearbeitungsGuardProvider = Provider.family<_BearbeitungsGuard, String>(
  (ref, heroId) => _BearbeitungsGuard(),
);

/// Erlaubt Bearbeiten erst nach bewusstem Verwerfen einer offenen Planung.
///
/// Ansehen und Navigation rufen diesen Guard nicht auf. Abbrechen, Schließen
/// des Dialogs, ein abgebauter Aufrufer oder eine inzwischen andere Sitzung
/// erhalten den Plan. Während einer Übernahme ist Bearbeiten gesperrt.
Future<bool> bestaetigeBearbeitungBeiPlanung({
  required BuildContext context,
  required String heroId,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final guard = container.read(_bearbeitungsGuardProvider(heroId));
  return guard.pruefe(context, container, heroId);
}

class _BearbeitungsGuard {
  Future<bool>? _laufend;

  // Parallele Einstiege dürfen weder einen zweiten Dialog noch zwei Aktionen auslösen.
  Future<bool> pruefe(
    BuildContext context,
    ProviderContainer container,
    String heroId,
  ) async {
    if (_laufend != null) return false;
    final laufend = _laufend = _frage(context, container, heroId);
    try {
      return await laufend && context.mounted;
    } finally {
      if (identical(_laufend, laufend)) _laufend = null;
    }
  }

  // Nur genau die im Dialog angekündigte Sitzung darf verworfen werden.
  Future<bool> _frage(
    BuildContext context,
    ProviderContainer container,
    String heroId,
  ) async {
    final provider = advancementSessionProvider(heroId);
    final session = container.read(provider);
    if (session == null) return true;
    if (session.isSaving) return false;
    final result = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Geplante Entwicklung verwerfen?',
      content:
          'Wenn du den Helden bearbeitest, wird deine geplante Entwicklung '
          'verworfen. Die geplanten Steigerungen werden nicht übernommen.',
      cancelLabel: 'Abbrechen',
      confirmLabel: 'Planung verwerfen und bearbeiten',
      isDestructive: true,
    );
    if (!context.mounted || result != AdaptiveConfirmResult.confirm) {
      return false;
    }
    final aktuell = container.read(provider);
    if (aktuell?.sessionId != session.sessionId || aktuell!.isSaving) {
      return false;
    }
    container.read(provider.notifier).discard();
    return true;
  }
}
