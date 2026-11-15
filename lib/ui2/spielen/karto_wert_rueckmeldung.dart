import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';

/// Hebt eine tatsächliche Wertänderung kurz hervor, ohne Zahlen zu verzögern.
class KartoWertRueckmeldung extends StatefulWidget {
  /// Beobachtet [wert] und lässt bei Änderungen die Ressourcenfarbe ausklingen.
  const KartoWertRueckmeldung({
    super.key,
    required this.wert,
    required this.farbe,
    required this.child,
  });

  /// Unveränderter fachlicher Wert; beim ersten Aufbau gibt es keinen Effekt.
  final int wert;

  /// Bestehende semantische Ressourcenfarbe.
  final Color farbe;

  /// Direkt aktualisierte Wertanzeige, einschließlich ihrer Semantik.
  final Widget child;

  @override
  State<KartoWertRueckmeldung> createState() => _WertRueckmeldungState();
}

class _WertRueckmeldungState extends State<KartoWertRueckmeldung>
    with SingleTickerProviderStateMixin {
  late final AnimationController _impuls = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1,
  );

  @override
  void didUpdateWidget(KartoWertRueckmeldung oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wert != oldWidget.wert &&
        kartoDauer(context, Bewegung.kurz) != Duration.zero) {
      _impuls.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kartoDauer(context, Bewegung.kurz) == Duration.zero) {
      _impuls.stop();
      _impuls.value = 1;
    }
  }

  @override
  void dispose() {
    _impuls.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _impuls,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: widget.farbe.withValues(alpha: (1 - _impuls.value) * 0.14),
          borderRadius: BorderRadius.circular(4),
        ),
        child: child,
      ),
    );
  }
}
