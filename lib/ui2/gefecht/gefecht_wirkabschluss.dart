import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_wirken.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/armatrutz_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/attributo_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/resource_stepper_dialog.dart';

/// Abschlüsse können nach Abbruch des Dialogs ohne erneute Probe geöffnet werden.
Future<void> zeigeGefechtsWirkabschluss({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
}) => showDialog<void>(
  context: context,
  builder: (_) => ZustandFehlerBereich(child: _Abschluss(heroId: heroId)),
);

/// Kosten und unterstützte eigene Effekte teilen einen frischen Schreibvorgang.
Future<bool> uebernimmGefechtsWirkfolgen({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  HeroState Function(HeroState)? effekt,
  bool abschliessen = true,
  GefechtsProbenbonus? bonus,
}) async {
  final s = ref.read(gefechtProvider(heroId));
  final h = s?.handlung;
  if (s == null ||
      h?.wirken == null ||
      h!.verbleibend != 0 ||
      h.ergebnis == null ||
      s.auftrag != null) {
    return false;
  }
  final controller = ref.read(gefechtProvider(heroId).notifier);
  final id = UniqueKey().toString();
  if (!controller.reservieren(id)) return false;
  try {
    final erfolg = h.ergebnis!.success && !h.gescheitert;
    final kosten = erfolg
        ? h.wirken!.kosten
        : h.wirken!.misserfolgKosten ??
              gefechtsWirkkosten(h.wirken!.kosten, h.art, erfolg: false);
    final ok = await aendereZustandMitMeldung(
      context: context,
      ref: ref,
      heroId: heroId,
      was: 'Gefechtsfolgen',
      aenderung: (frisch) {
        final bezahlt = h.kostenUebernommen
            ? frisch
            : uebernimmGefechtsWirkkosten(
                frisch,
                kosten,
                karmal: h.wirken!.karmal,
              );
        return effekt == null || !erfolg ? bezahlt : effekt(bezahlt);
      },
    );
    if (ok == null) return false;
    // Release the reservation before changing the immutable session state.
    controller.abbrechen(id);
    final aktuell = ref.read(gefechtProvider(heroId))!;
    final fehlversuche = Map<String, int>.of(aktuell.karmaleFehlversuche);
    if (abschliessen && !erfolg && h.wirken!.karmal) {
      final key = h.wirken!.identitaet;
      fehlversuche[key] = (fehlversuche[key] ?? 0) + 1;
    }
    controller.setzen(
      aktuell.copyWith(
        handlung: abschliessen ? null : h.copyWith(kostenUebernommen: true),
        ohneHandlung: abschliessen,
        karmaleFehlversuche: fehlversuche,
        mirakelbonus: erfolg ? bonus : null,
      ),
    );
    return true;
  } finally {
    controller.abbrechen(id);
  }
}

class _Abschluss extends ConsumerStatefulWidget {
  const _Abschluss({required this.heroId});
  final String heroId;
  @override
  ConsumerState<_Abschluss> createState() => _AbschlussState();
}

class _AbschlussState extends ConsumerState<_Abschluss> {
  bool _busy = false, _folgen = false, _eigenerEffekt = false;
  final _bonus = TextEditingController();
  final _ziel = TextEditingController();
  @override
  void dispose() {
    _bonus.dispose();
    _ziel.dispose();
    super.dispose();
  }

  // Existing effect input dialogs collect values without persisting early.
  Future<HeroState Function(HeroState)?> _effekt(Gefechtshandlung h) async {
    if (!_eigenerEffekt) return null;
    final n = h.titel.toLowerCase();
    if (n.startsWith('armatrutz')) {
      final d = await showArmatrutzInputDialog(context: context);
      return d == null ? null : (s) => aktiviereArmatrutz(s, d);
    }
    if (n.startsWith('attributo')) {
      final b = await showAttributoInputDialog(context: context);
      return b == null ? null : (s) => aktiviereAttributo(s, b);
    }
    return (s) =>
        schalteZaubereffekt(s, activeSpellEffectAxxeleratus, aktiv: true);
  }

  Future<void> _uebernehmen(
    Gefechtshandlung h, {
    bool nurKosten = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    try {
      final effekt = nurKosten ? null : await _effekt(h);
      if (!mounted || _eigenerEffekt && !nurKosten && effekt == null) return;
      final b = int.tryParse(_bonus.text);
      final bonus = b == null || _ziel.text.trim().isEmpty
          ? null
          : GefechtsProbenbonus(_ziel.text.trim(), b);
      final ok = await uebernimmGefechtsWirkfolgen(
        context: context,
        ref: ref,
        heroId: widget.heroId,
        effekt: effekt,
        abschliessen: !nurKosten,
        bonus: bonus,
      );
      if (ok && !nurKosten && mounted) Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = ref.watch(gefechtProvider(widget.heroId))?.handlung;
    final state = ref.watch(heroStateProvider(widget.heroId)).asData?.value;
    if (h?.wirken == null || h!.ergebnis == null) {
      return const SizedBox.shrink();
    }
    final erfolg = h.ergebnis!.success && !h.gescheitert;
    final kosten = erfolg
        ? h.wirken!.kosten
        : h.wirken!.misserfolgKosten ??
              gefechtsWirkkosten(h.wirken!.kosten, h.art, erfolg: false);
    final unterstuetzt = [
      'armatrutz',
      'attributo',
      'axxeleratus',
    ].any((n) => h.titel.toLowerCase().startsWith(n));
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text('${h.titel} · Abschluss'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  erfolg
                      ? 'Erfolgreich · Ergebnis eingefroren'
                      : 'Gescheitert · Ergebnis eingefroren',
                ),
                Text(
                  '${h.wirken!.karmal ? 'KaP' : 'AsP'}: $kosten; verfügbar '
                  '${h.wirken!.karmal ? state?.currentKap : state?.currentAsp}',
                ),
                if (h.kostenUebernommen)
                  const Text(
                    'Kosten bereits übernommen; keine zweite Buchung.',
                  ),
                if (erfolg && unterstuetzt)
                  CheckboxListTile(
                    value: _eigenerEffekt,
                    title: const Text(
                      'Unterstützten Effekt auf eigenen Helden übernehmen',
                    ),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                            _eigenerEffekt = v!;
                          }),
                  ),
                if (erfolg && h.art == Gefechtshandlungsart.mirakel) ...[
                  Text(
                    'LkP*: ${h.ergebnis!.remainingPool}. Eigenschaft/MR: LkP*/2+2; '
                    'Talent/Gabe: LkP*/2+5. Rundung und AW-Zuordnung bestätigen.',
                  ),
                  TextField(
                    controller: _ziel,
                    decoration: const InputDecoration(
                      labelText: 'Exakter Titel der einen folgenden Probe',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  TextField(
                    controller: _bonus,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Bestätigter einmaliger Bonus',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                CheckboxListTile(
                  value: _folgen,
                  title: const Text('Weitere Folgen am Spieltisch bestätigt'),
                  subtitle: Text(
                    h.wirken!.permanentManuell
                        ? 'Permanente KaP, Unterbrechungsfolgen und fremde Ziele manuell übernehmen.'
                        : 'Fremde Zielwirkungen, Patzer und Sonderfälle gezielt prüfen.',
                  ),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _folgen = v!;
                        }),
                ),
                const ZustandFehlerAnzeige(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Später übernehmen'),
          ),
          if (!h.kostenUebernommen)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => showResourceStepperDialog(
                      context: context,
                      heroId: widget.heroId,
                      resource: h.wirken!.karmal
                          ? ResourceType.kap
                          : ResourceType.asp,
                      abschlussKosten: kosten,
                      onAbschlussUebernehmen: () => uebernimmGefechtsWirkfolgen(
                        context: context,
                        ref: ref,
                        heroId: widget.heroId,
                        abschliessen: false,
                      ),
                    ),
              child: const Text('Kosten jetzt übernehmen'),
            ),
          FilledButton(
            onPressed: _busy || !_folgen ? null : () => _uebernehmen(h),
            child: Text(
              h.kostenUebernommen
                  ? 'Folgen abschließen'
                  : 'Kosten und Folgen übernehmen',
            ),
          ),
        ],
      ),
    );
  }
}
