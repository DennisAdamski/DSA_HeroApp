import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Strg/Cmd+K für die Probensuche, unabhängig vom Tastaturfokus.
///
/// Ein `CallbackShortcuts` greift nur, solange der Fokus in seinem Teilbaum
/// liegt. Im Browser verliert er ihn schon bei einem Klick auf freie Fläche;
/// dann behandelt Flutter die Taste nicht, ruft kein `preventDefault` auf, und
/// der Browser öffnet stattdessen seine eigene Suche. Deshalb hört dieses
/// Kürzel direkt an der Tastatur ([HardwareKeyboard]) mit – aber nur, solange
/// es [aktiv] ist und seine Route oben liegt, damit es weder in einem Dialog
/// noch unter dem Gefecht ein zweites Mal auslöst.
class KartoProbenkuerzel extends StatefulWidget {
  /// Bindet Strg/Cmd+K an [onAusloesen].
  const KartoProbenkuerzel({
    super.key,
    required this.aktiv,
    required this.onAusloesen,
    required this.child,
  });

  /// Ob das Kürzel gerade gilt, etwa nur im sichtbaren Arbeitsbereich.
  final bool aktiv;

  /// Öffnet die Probensuche.
  final VoidCallback onAusloesen;

  /// Inhalt, für den das Kürzel gilt.
  final Widget child;

  @override
  State<KartoProbenkuerzel> createState() => _KartoProbenkuerzelState();
}

class _KartoProbenkuerzelState extends State<KartoProbenkuerzel> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_beiTaste);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_beiTaste);
    super.dispose();
  }

  // `true` markiert die Taste als behandelt; im Browser unterdrückt das die
  // eigene Suche.
  bool _beiTaste(KeyEvent event) {
    if (!widget.aktiv || !mounted) return false;
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyK) {
      return false;
    }
    final tastatur = HardwareKeyboard.instance;
    final mitModifikator = tastatur.isControlPressed || tastatur.isMetaPressed;
    if (!mitModifikator || tastatur.isAltPressed || tastatur.isShiftPressed) {
      return false;
    }
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    widget.onAusloesen();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
