import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
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
}) {
  final aktionen = ref.read(heroActionsProvider);
  return _schreibeMitMeldung(
    context: context,
    was: was,
    schreibe: () => aktionen.updateHeroState(heroId, aenderung),
  );
}

/// Ändert den gespeicherten Heldenbogen frisch und meldet Fehler sichtbar.
///
/// Gegenstück zu [aendereZustandMitMeldung] für Sofortaktionen am Bogen
/// (Dauermodifikatoren, Wundschwelle, Übersicht, Dukaten …): [aenderung]
/// bekommt den **gespeicherten** Helden und ersetzt nur ihre eigenen Felder;
/// ein beim Rendern erfasster Bogen wird nie zurückgeschrieben (ARCH-05).
/// Änderungen desselben Helden laufen nacheinander (`updateHero`), auch
/// gegenüber einem Speichern aus einem Editor.
///
/// Solange eine Steigerungsrunde offen ist, wird nichts geschrieben: jede
/// Heldenänderung bräche den Inhalts-Hash der Runde und damit ihre
/// Übernahme. Die Meldung erscheint dann wie ein Speicherfehler. Das
/// Ergebnis ist bei einem Fehler `null`, sonst der gespeicherte Held.
Future<HeroSheet?> aendereHeldMitMeldung({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required String was,
  required HeroSheet Function(HeroSheet aktuell) aenderung,
}) {
  return _schreibeMitMeldung(
    context: context,
    was: was,
    schreibe: () =>
        aendereHeldImEditor(ref: ref, heroId: heroId, aenderung: aenderung),
  );
}

/// Ändert den gespeicherten Heldenbogen frisch und reicht Fehler weiter.
///
/// Für Editoren, die einen Fehler selbst anzeigen und dabei offen bleiben
/// (etwa der Inventareditor); sonst wie [aendereHeldMitMeldung], einschließlich
/// der Sperre während einer offenen Steigerungsrunde. Liefert den
/// gespeicherten Helden.
Future<HeroSheet> aendereHeldImEditor({
  required WidgetRef ref,
  required String heroId,
  required HeroSheet Function(HeroSheet aktuell) aenderung,
}) {
  if (ref.read(advancementSessionProvider(heroId)) != null) {
    return Future<HeroSheet>.error(StateError(kBogenWaehrendPlanungGesperrt));
  }
  return ref.read(heroActionsProvider).updateHero(heroId, aenderung);
}

/// Grund, aus dem Sofortaktionen am Bogen während einer Planung ruhen.
const String kBogenWaehrendPlanungGesperrt =
    'Während einer Planung ist der Heldenbogen gesperrt.';

// Gemeinsamer Fehlerweg beider Einstiege. [schreibe] läuft synchron beim
// Aufruf an, damit schnelle, nicht abgewartete Klicks in ihrer Reihenfolge
// eingereiht werden.
Future<T?> _schreibeMitMeldung<T>({
  required BuildContext context,
  required String was,
  required Future<T> Function() schreibe,
}) async {
  // Vor dem Warten greifen: das Bedienelement kann danach abgebaut sein.
  final bereich = ZustandFehlerBereich._meldungVon(context);
  final bote = bereich == null ? ScaffoldMessenger.maybeOf(context) : null;
  try {
    final gespeichert = await schreibe();
    bereich?.melde(null);
    return gespeichert;
  } catch (fehler) {
    final text = '$was nicht gespeichert: ${_fehlertext(fehler)}';
    if (bereich != null) {
      bereich.melde(text);
    } else {
      bote?.showSnackBar(SnackBar(content: Text(text)));
    }
    return null;
  }
}

// Fachliche Gründe (`StateError`) ohne das technische „Bad state:“.
String _fehlertext(Object fehler) {
  if (fehler is StateError) {
    return fehler.message;
  }
  return '$fehler';
}

/// Bereich eines Blatts, Dialogs oder Panels, in dem Speicherfehler von
/// [aendereZustandMitMeldung] und [aendereHeldMitMeldung] erscheinen.
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
