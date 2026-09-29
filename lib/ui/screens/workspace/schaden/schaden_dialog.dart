import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/trefferzonen.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/trefferzonen_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wund_zustand_speichern.dart';

part 'schaden_eingaben.dart';

/// Ergebnis eines übernommenen Schadens, für die anschließende Unterdrückung.
class SchadenDialogErgebnis {
  /// Erstellt ein Ergebnis.
  const SchadenDialogErgebnis({required this.anwendung, required this.zone});

  /// Tatsächlich gespeicherte Anwendung.
  final SchadensAnwendung anwendung;

  /// Getroffene Zone, falls Wunden gebucht wurden.
  final WundZone? zone;
}

/// Öffnet den Dialog „Schaden erhalten“ für einen Helden.
///
/// Der Dialog schließt sich nach dem Übernehmen selbst. Wurden Wunden
/// eingetragen, folgt die vorhandene Unterdrückungsabfrage, einmal für alle
/// Wunden dieses Angriffs gemeinsam.
/// [wuerfler] ersetzt in Tests die Zufallswürfe.
Future<void> showSchadenDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  DiceRoller? wuerfler,
}) async {
  final ergebnis = await showAdaptiveDetailSheet<SchadenDialogErgebnis>(
    context: context,
    builder: (sheetContext) => AlertDialog(
      key: const ValueKey<String>('schaden-dialog'),
      title: const Text('Schaden erhalten'),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: SchadenPanel(
            heroId: heroId,
            wuerfler: wuerfler,
            onUebernommen: (ergebnis) =>
                Navigator.of(sheetContext).pop(ergebnis),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('schaden-dialog-close'),
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );
  final zone = ergebnis?.zone;
  if (ergebnis == null ||
      zone == null ||
      ergebnis.anwendung.hinzugefuegteWunden == 0 ||
      !context.mounted) {
    return;
  }
  await bieteWundUnterdrueckungAn(
    context: context,
    ref: ref,
    heroId: heroId,
    zone: zone,
    gespeichert: ergebnis.anwendung.zustand,
    neueWunden: ergebnis.anwendung.hinzugefuegteWunden,
  );
}

/// Eingaben und Vorschau des Ablaufs „Schaden erhalten“.
///
/// Das Panel sammelt nur Eingaben. Gerechnet wird in `schaden_rules.dart`,
/// gespeichert über den Ablauf `SchadenErhalten` (ARCH-05) auf dem frisch
/// geladenen Zustand. Die Wundzahl ist ein Vorschlag aus den
/// Wundschwellenstufen des Helden und dem Modifikator des Angriffs; die
/// Entscheidung trifft der Nutzer. Speicherfehler zeigt das Panel selbst an.
class SchadenPanel extends ConsumerStatefulWidget {
  /// Erstellt das Panel.
  const SchadenPanel({
    super.key,
    required this.heroId,
    required this.onUebernommen,
    this.wuerfler,
  });

  /// Held, dem der Schaden gebucht wird.
  final String heroId;

  /// Wird nach erfolgreichem Speichern aufgerufen.
  final ValueChanged<SchadenDialogErgebnis> onUebernommen;

  /// Würfel für W20 und Zusatzwürfe; ohne Angabe zufällig.
  final DiceRoller? wuerfler;

  @override
  ConsumerState<SchadenPanel> createState() => _SchadenPanelState();
}

class _SchadenPanelState extends ConsumerState<SchadenPanel> {
  late final DiceRoller _wuerfler = widget.wuerfler ?? RandomDiceRoller();

  SchadensArt _art = SchadensArt.lebensenergie;
  final TextEditingController _tp = TextEditingController();
  TextEditingController? _rs;
  final TextEditingController _wsMod = TextEditingController(text: '0');
  final TextEditingController _w20 = TextEditingController();

  WundZone? _zone;

  /// Vom Nutzer gesetzte Wundzahl; `null` folgt dem Vorschlag.
  int? _wundenUeberschrieben;

  /// Zusatzwurffelder je Wurfsituation und Label. Eine neue Situation
  /// (Zone, Wundzahl, bisherige Wunden) bekommt frische, leere Felder; die
  /// alten bleiben bis zum Schließen bestehen, weil ein Feld seinen
  /// Controller beim Neuaufbau noch abmeldet.
  final Map<String, TextEditingController> _zusatz =
      <String, TextEditingController>{};

  bool _schreibt = false;
  String? _fehler;

  @override
  void dispose() {
    _tp.dispose();
    _rs?.dispose();
    _wsMod.dispose();
    _w20.dispose();
    for (final controller in _zusatz.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Jede Eingabe, die den Vorschlag ändert, verwirft die eigene Wundzahl.
  void _eingabeGeaendert() {
    setState(() => _wundenUeberschrieben = null);
  }

  void _setzeZone(WundZone? zone) {
    setState(() {
      _zone = zone;
      _wundenUeberschrieben = null;
    });
  }

  // Eine von Hand gewählte Zone verwirft einen W20-Wurf, der auf eine andere
  // Zone zeigen würde.
  void _zoneGewaehlt(WundZone? zone) {
    _w20.clear();
    _setzeZone(zone);
  }

  void _w20Geaendert(String text) {
    final wurf = int.tryParse(text.trim());
    if (wurf == null || wurf < 1 || wurf > 20) {
      return;
    }
    final ergebnis = resolveTrefferzone(
      roll: wurf,
      tabelle: humanoidTrefferzonenTabelle,
    );
    _setzeZone(ergebnis?.zone);
  }

  void _wuerfleZone() {
    final wurf = _wuerfler.rollDie(20);
    _w20.text = '$wurf';
    _w20Geaendert(_w20.text);
  }

  // TP(A)-Treffer schlagen seltener Wunden: die Wundschwelle ist
  // üblicherweise um 2 erhöht (WdS S. 58). Der Wert bleibt änderbar.
  void _setzeArt(SchadensArt art) {
    setState(() {
      _art = art;
      _wsMod.text = art == SchadensArt.ausdauer ? '2' : '0';
      _wundenUeberschrieben = null;
    });
  }

  void _setzeWunden(int wunden) {
    setState(() => _wundenUeberschrieben = wunden);
  }

  void _neuZeichnen() => setState(() {});

  TextEditingController _zusatzFeld(String situation, String label) {
    return _zusatz.putIfAbsent('$situation#$label', TextEditingController.new);
  }

  void _wuerfleZusatz(TextEditingController feld, SchadensZusatzwurf wurf) {
    var summe = wurf.diceSpec.modifier;
    for (var i = 0; i < wurf.diceSpec.count; i++) {
      summe += _wuerfler.rollDie(wurf.diceSpec.sides);
    }
    setState(() => feld.text = '$summe');
  }

  // Ganze Zahl aus einem Feld; das typografische Minus zählt wie `-`.
  int? _zahl(TextEditingController controller) {
    return int.tryParse(controller.text.trim().replaceAll('−', '-'));
  }

  Future<void> _uebernehme(SchadensBuchung buchung) async {
    if (_schreibt) {
      return;
    }
    setState(() {
      _schreibt = true;
      _fehler = null;
    });
    try {
      final anwendung = await ref
          .read(schadenErhaltenProvider)
          .uebernehmeSchaden(heroId: widget.heroId, buchung: buchung);
      if (mounted) {
        widget.onUebernommen(
          SchadenDialogErgebnis(anwendung: anwendung, zone: buchung.zone),
        );
      }
    } catch (fehler) {
      if (mounted) {
        final text = fehler is StateError ? fehler.message : '$fehler';
        setState(() {
          _fehler = 'Schaden konnte nicht gespeichert werden: $text';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _schreibt = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(heroStateProvider(widget.heroId)).valueOrNull;
    final computed = ref.watch(heroComputedProvider(widget.heroId)).valueOrNull;
    if (state == null || computed == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final rs = _rs ??= TextEditingController(
      text: '${computed.combatPreviewStats.rsTotal}',
    );
    return _buildInhalt(context, state, computed, rs);
  }
}
