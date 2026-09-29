import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Schlüssel der eingeblendeten Fehlermeldung ([ZustandFehlerAnzeige]).
const ValueKey<String> kZustandFehlerSchluessel = ValueKey<String>(
  'zustand-speicherfehler',
);

/// Ändert den gespeicherten Laufzeitzustand frisch und meldet Fehler sichtbar.
///
/// Gemeinsamer Schreibweg der Bedienelemente für Laufzeitwerte (Ressourcen,
/// Belastung, Wunden, Zaubereffekte). [aenderung] bekommt den **gespeicherten**
/// Zustand und ersetzt nur ihre eigenen Felder; ein beim Rendern erfasster
/// Stand wird nie zurückgeschrieben (ARCH-05). Änderungen desselben Helden
/// laufen nacheinander (`aendereGespeichertenZustand`).
///
/// Scheitert das Speichern, erscheint `„[was] nicht gespeichert: …“` im
/// nächsten umgebenden [ZustandFehlerBereich], wie beim Rastpanel direkt im
/// Blatt oder Dialog; ein erfolgreiches Speichern blendet sie wieder aus.
/// Ohne Bereich bleibt eine Snackbar der Rückfall. Das Ergebnis ist dann
/// `null`, sonst der gespeicherte Zustand. Ein fehlgeschlagener Write darf
/// nie als stille Übernahme erscheinen.
Future<HeroState?> aendereZustandMitMeldung({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required String was,
  required HeroState Function(HeroState aktuell) aenderung,
}) async {
  // Vor dem Warten greifen: das Bedienelement kann danach abgebaut sein.
  final bereich = ZustandFehlerBereich._meldungVon(context);
  final bote = bereich == null ? ScaffoldMessenger.maybeOf(context) : null;
  final aktionen = ref.read(heroActionsProvider);
  try {
    final gespeichert = await aktionen.updateHeroState(heroId, aenderung);
    bereich?.melde(null);
    return gespeichert;
  } catch (fehler) {
    final text = '$was nicht gespeichert: $fehler';
    if (bereich != null) {
      bereich.melde(text);
    } else {
      bote?.showSnackBar(SnackBar(content: Text(text)));
    }
    return null;
  }
}

/// Bereich eines Blatts, Dialogs oder Panels, in dem Speicherfehler von
/// [aendereZustandMitMeldung] erscheinen.
///
/// Eine Snackbar läge hinter einem geöffneten Blatt oder Dialog, auf
/// iOS/macOS sogar vollständig verdeckt. Der Bereich hält deshalb die letzte
/// Meldung; [ZustandFehlerAnzeige] zeigt sie an der Stelle, die der Aufbau
/// dafür vorsieht.
class ZustandFehlerBereich extends StatefulWidget {
  /// Umschließt [child]; darin platziert der Aufrufer [ZustandFehlerAnzeige].
  const ZustandFehlerBereich({super.key, required this.child});

  /// Inhalt des Bereichs.
  final Widget child;

  // Meldung des nächsten umgebenden Bereichs, ohne Abhängigkeit anzumelden.
  static _Meldung? _meldungVon(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_FehlerScope>();
    return scope?.notifier;
  }

  @override
  State<ZustandFehlerBereich> createState() => _ZustandFehlerBereichState();
}

class _ZustandFehlerBereichState extends State<ZustandFehlerBereich> {
  final _Meldung _meldung = _Meldung();

  @override
  void dispose() {
    _meldung.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FehlerScope(notifier: _meldung, child: widget.child);
  }
}

/// Zeigt die letzte Fehlermeldung des umgebenden [ZustandFehlerBereich];
/// ohne Meldung nimmt sie keinen Platz ein.
class ZustandFehlerAnzeige extends StatelessWidget {
  /// Erstellt die Anzeige.
  const ZustandFehlerAnzeige({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FehlerScope>();
    final text = scope?.notifier?.value;
    if (text == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        key: kZustandFehlerSchluessel,
        style: TextStyle(color: theme.colorScheme.error),
      ),
    );
  }
}

// Meldung, die ein Speichern nach dem Schließen des Bereichs still verwirft.
class _Meldung extends ValueNotifier<String?> {
  _Meldung() : super(null);

  bool _entsorgt = false;

  // Setzt die Meldung, solange der Bereich noch steht.
  void melde(String? text) {
    if (!_entsorgt) {
      value = text;
    }
  }

  @override
  void dispose() {
    _entsorgt = true;
    super.dispose();
  }
}

// Reicht die Meldung an Anzeige und Schreibweg weiter.
class _FehlerScope extends InheritedNotifier<_Meldung> {
  const _FehlerScope({required super.notifier, required super.child});
}
