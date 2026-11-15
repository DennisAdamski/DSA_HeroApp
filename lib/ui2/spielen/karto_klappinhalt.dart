import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';

/// Animiert nur explizites Einklappen, nicht jede inhaltliche Höhenänderung.
///
/// Das freie Raster misst seine Kinder mehrfach. Ein eigener Größenfaktor
/// vermeidet dabei die Rückkopplung einer automatisch gemessenen Animation.
class KartoKlappinhalt extends StatefulWidget {
  /// Zeigt [child] geöffnet oder lässt es bei [eingeklappt] ausklingen.
  const KartoKlappinhalt({
    super.key,
    required this.eingeklappt,
    required this.child,
  });

  /// Ob der Inhalt nach dem Übergang vollständig aus dem Baum verschwindet.
  final bool eingeklappt;

  /// Bestehender Inhalt, der während des Schließens nicht bedienbar ist.
  final Widget child;

  @override
  State<KartoKlappinhalt> createState() => _KlappinhaltState();
}

class _KlappinhaltState extends State<KartoKlappinhalt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _auf = AnimationController(
    vsync: this,
    value: widget.eingeklappt ? 0 : 1,
  );
  late final CurvedAnimation _verlauf = CurvedAnimation(
    parent: _auf,
    curve: Bewegung.kurve,
  );

  // Direkte Zielwerte stoppen auch einen schon laufenden Übergang sofort.
  void _abgleichen({bool bewegen = false}) {
    final dauer = kartoDauer(context, Bewegung.mittel);
    final ziel = widget.eingeklappt ? 0.0 : 1.0;
    if (dauer == Duration.zero) {
      _auf.stop();
      _auf.value = ziel;
    } else if (bewegen) {
      _auf.animateTo(ziel, duration: dauer);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _abgleichen();
  }

  @override
  void didUpdateWidget(KartoKlappinhalt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eingeklappt != widget.eingeklappt) {
      _abgleichen(bewegen: true);
    }
  }

  @override
  void dispose() {
    _verlauf.dispose();
    _auf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _auf,
      builder: (context, _) {
        if (_auf.value == 0 && widget.eingeklappt) return const SizedBox();
        return SizeTransition(
          sizeFactor: _verlauf,
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            ignoring: widget.eingeklappt,
            child: ExcludeFocus(
              excluding: widget.eingeklappt,
              child: ExcludeSemantics(
                excluding: widget.eingeklappt,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
