import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_wirken.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import 'gefecht_fremdwirkung.dart';

/// Abschlüsse können nach Abbruch des Dialogs ohne erneute Probe geöffnet werden.
///
/// Schreibwege und Eingabedialoge des Bestands erreicht der Abschluss
/// ausschließlich über [bestand].
Future<void> zeigeGefechtsWirkabschluss({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
}) => showDialog<void>(
  context: context,
  builder: (_) => bestand.gefechtsFehlerBereich(
    builder: (fehleranzeige) => _Abschluss(
      heroId: heroId,
      bestand: bestand,
      fehleranzeige: fehleranzeige,
    ),
  ),
);

/// Kosten und unterstützte eigene Effekte teilen einen frischen Schreibvorgang.
Future<bool> uebernimmGefechtsWirkfolgen({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
  HeroState Function(HeroState)? effekt,
  bool abschliessen = true,
  GefechtsProbenbonus? bonus,
}) async {
  final s = ref.read(gefechtMitInitiativeProvider(heroId));
  final h = s?.handlung;
  if (s == null ||
      h?.wirken == null ||
      h!.verbleibend != 0 ||
      (h.ergebnis == null && h.abbruchKosten == null) ||
      s.auftrag != null) {
    return false;
  }
  final controller = ref.read(gefechtProvider(heroId).notifier);
  final id = UniqueKey().toString();
  if (!controller.reservieren(id)) return false;
  try {
    final erfolg = h.ergebnis?.success == true && !h.gescheitert;
    final fremd = erfolg && h.abbruchKosten == null
        ? h.fremdwirkungswurf
        : null;
    if (erfolg &&
        h.abbruchKosten == null &&
        h.wirken!.fremdwirkung != null &&
        fremd == null) {
      return false;
    }
    if (fremd != null &&
        !ref
            .read(gefechtBegegnungProvider)
            .gegner
            .containsKey(fremd.ziel.gegnerId)) {
      return false;
    }
    final kosten = gefechtsAbschlusskosten(h);
    final ok = await bestand.gefechtsZustand(
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
    final aktuell = ref.read(gefechtMitInitiativeProvider(heroId))!;
    // Own costs are marked before a separate transient enemy booking can fail.
    controller.setzen(
      aktuell.copyWith(handlung: h.copyWith(kostenUebernommen: true)),
    );
    if (abschliessen && fremd != null) {
      final gegner = ref.read(gefechtBegegnungProvider);
      if (!gegner.gegner.containsKey(fremd.ziel.gegnerId)) return false;
      ref
          .read(gefechtBegegnungProvider.notifier)
          .schaden(
            gegnerId: fremd.ziel.gegnerId,
            buchungId:
                h.wirkungId ??
                'wirkung:$heroId:${identityHashCode(h.ergebnis)}',
            tp: fremd.schaden,
            direkt: true,
          );
    }
    final fehlversuche = Map<String, int>.of(aktuell.karmaleFehlversuche);
    if (abschliessen && h.ergebnis?.success == false && h.wirken!.karmal) {
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
  const _Abschluss({
    required this.heroId,
    required this.bestand,
    required this.fehleranzeige,
  });
  final String heroId;
  final KartoGefechtsAdapter bestand;

  /// Anzeige der Speicherfehler aus [KartoGefechtsAdapter.gefechtsZustand].
  final Widget fehleranzeige;
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
      final d = await widget.bestand.gefechtsArmatrutzWerte(context);
      return d == null ? null : (s) => uebernimmGefechtsArmatrutz(s, d);
    }
    if (n.startsWith('attributo')) {
      final b = await widget.bestand.gefechtsAttributoWerte(context);
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
      if (!await _fremdwurf(h)) return;
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
        bestand: widget.bestand,
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

  // Captures the damage once; reopening the completion never rerolls it.
  Future<bool> _fremdwurf(Gefechtshandlung h) async {
    final ziel = h.wirken?.fremdwirkung;
    if (ziel == null ||
        h.fremdwirkungswurf != null ||
        h.ergebnis?.success != true ||
        h.gescheitert ||
        h.abbruchKosten != null) {
      return true;
    }
    final wurf = await zeigeGefechtsFremdwirkungswurf(
      context: context,
      ziel: ziel,
      probe: h.ergebnis!,
    );
    if (wurf == null || !mounted) return false;
    final s = ref.read(gefechtMitInitiativeProvider(widget.heroId));
    if (s?.handlung != h || s!.auftrag != null) return false;
    ref
        .read(gefechtProvider(widget.heroId).notifier)
        .setzen(s.copyWith(handlung: h.copyWith(fremdwirkungswurf: wurf)));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final h = ref.watch(gefechtMitInitiativeProvider(widget.heroId))?.handlung;
    final state = ref.watch(heroStateProvider(widget.heroId)).asData?.value;
    if (h?.wirken == null || (h!.ergebnis == null && h.abbruchKosten == null)) {
      return const SizedBox.shrink();
    }
    final erfolg = h.ergebnis?.success == true && !h.gescheitert;
    final brauchtWurf =
        erfolg &&
        h.abbruchKosten == null &&
        h.wirken!.fremdwirkung != null &&
        h.fremdwirkungswurf == null;
    final kosten = brauchtWurf ? null : gefechtsAbschlusskosten(h);
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
                  h.abbruchKosten != null
                      ? 'Abgebrochen · Kosten manuell bestätigt'
                      : erfolg
                      ? 'Erfolgreich · Ergebnis eingefroren'
                      : 'Gescheitert · Ergebnis eingefroren',
                ),
                Text(
                  '${h.wirken!.karmal ? 'KaP' : 'AsP'}: ${kosten ?? 'Schadenswurf offen'}; verfügbar '
                  '${h.wirken!.karmal ? state?.currentKap : state?.currentAsp}',
                ),
                if (h.kostenUebernommen)
                  const Text(
                    'Kosten bereits übernommen; keine zweite Buchung.',
                  ),
                if (h.wirken!.fremdwirkung != null)
                  Text(
                    'Ursprüngliches Ziel: ${h.wirken!.fremdwirkung!.gegnerId}. '
                    'Direkte SP: ${h.fremdwirkungswurf?.schaden ?? 'Wurf offen'}. '
                    'Kosten und Gegnerfolge werden einmal übernommen.',
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
                if (h.wirken!.fremdwirkung == null &&
                    !h.wirken!.permanentManuell)
                  const Text(
                    'Fremde Zielwirkungen, Patzer und Sonderfälle am Tisch prüfen.',
                  ),
                if (h.wirken!.fremdwirkung == null &&
                    h.wirken!.permanentManuell)
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
                widget.fehleranzeige,
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Später übernehmen'),
          ),
          if (!h.kostenUebernommen && !brauchtWurf)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => widget.bestand.gefechtsWirkkosten(
                      context: context,
                      heroId: widget.heroId,
                      karmal: h.wirken!.karmal,
                      kosten: kosten,
                      onUebernehmen: (blatt) => uebernimmGefechtsWirkfolgen(
                        context: blatt,
                        ref: ref,
                        heroId: widget.heroId,
                        bestand: widget.bestand,
                        abschliessen: false,
                      ),
                    ),
              child: const Text('Kosten jetzt übernehmen'),
            ),
          FilledButton(
            // Nur permanente Kosten verlangen eine eigene Bestätigung.
            onPressed:
                _busy ||
                    (!_folgen &&
                        h.wirken!.fremdwirkung == null &&
                        h.wirken!.permanentManuell)
                ? null
                : () => _uebernehmen(h),
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
