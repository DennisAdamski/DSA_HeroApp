import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseweg_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisezeit_rules.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_routen_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_reiseplan_bausteine.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Ergebnis des Reisewegdialogs: die gewählte Anreise, `null` für die
/// Vorgabe.
class KartoReisewegWahl {
  /// Erstellt das Ergebnis.
  const KartoReisewegWahl(this.anreise);

  /// Gewählte Anreise; `null` heißt Vorgabe (schnellste, alle Wege).
  final HeroReiseAnreise? anreise;
}

/// Öffnet den Reisewegdialog für die [etappe].
///
/// Liefert `null` bei Abbruch. Der Dialog fragt Avesmaps nur auf Knopfdruck
/// („Berechnen“, „Vergleichen“) und schreibt selbst nichts am Helden.
Future<KartoReisewegWahl?> zeigeReisewegDialog(
  BuildContext context, {
  required ReiseEtappe etappe,
}) {
  return showDialog<KartoReisewegWahl>(
    context: context,
    builder: (_) => KartoReisewegDialog(etappe: etappe),
  );
}

/// Wahl des Reisewegs einer Etappe: erlaubte Wege, Optimierung, Ergebnis
/// von Avesmaps, der Vergleich mit drei Vorgaben und der Plan nach Regelwerk
/// (Reisemittel, Eile, Wetter).
class KartoReisewegDialog extends ConsumerStatefulWidget {
  /// Dialog für die [etappe]; sie braucht eine vorige Station.
  const KartoReisewegDialog({super.key, required this.etappe});

  /// Die Etappe, deren Anreise gewählt wird.
  final ReiseEtappe etappe;

  @override
  ConsumerState<KartoReisewegDialog> createState() =>
      _KartoReisewegDialogState();
}

class _KartoReisewegDialogState extends ConsumerState<KartoReisewegDialog> {
  late Set<String> _wege = anreiseWege(widget.etappe.station.anreise);
  late String _optimierung = anreiseOptimierung(widget.etappe.station.anreise);
  late String _mittel = reiseMittelOderFuss(
    widget.etappe.station.anreise?.mittel ?? '',
  );
  late bool _eil = widget.etappe.station.anreise?.tempo == kReiseTempoEil;
  late String _wetter = reiseWetter(widget.etappe.station.anreise?.wetter ?? '')
      .schluessel;
  bool _laedt = false;
  String? _fehler;

  AvesmapsRoutenAnfrage? _anfrage(Set<String> wege, String optimierung) =>
      reisewegAnfrage(
        widget.etappe.vorherige,
        widget.etappe.station,
        anreise:
            anreiseAus(wege: wege, optimierung: optimierung) ??
            const HeroReiseAnreise(),
      );

  Future<void> _hole(List<AvesmapsRoutenAnfrage> anfragen) async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    final ergebnis = await ref
        .read(avesmapsReisewegeProvider.notifier)
        .hole(anfragen);
    if (!mounted) return;
    setState(() {
      _laedt = false;
      _fehler = ergebnis.fehler;
    });
  }

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final karto = context.karto;
    final wege =
        ref.watch(avesmapsReisewegeProvider).asData?.value ??
        const <String, AvesmapsRoute>{};
    final anfrage = _anfrage(_wege, _optimierung);
    final weg = anfrage == null ? null : wege[anfrage.schluessel];
    final von = widget.etappe.vorherige?.ort.trim() ?? '';
    final nach = widget.etappe.station.ort.trim();
    final leise = texte.legende.copyWith(color: karto.schriftLeise);
    final plan = weg == null || !weg.gefunden
        ? null
        : reisezeitPlan(
            weg: weg,
            mittel: _mittel,
            tempo: _eil ? kReiseTempoEil : kReiseTempoNormal,
            wetter: _wetter,
          );

    return AlertDialog(
      title: const Text('Reiseweg'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$von → $nach', style: texte.abschnitt),
            const SizedBox(height: Abstand.weit),
            Text('Erlaubte Wege', style: leise),
            const SizedBox(height: Abstand.knapp),
            Wrap(
              spacing: Abstand.knapp,
              runSpacing: Abstand.knapp,
              children: [
                for (final art in kReiseWegArten)
                  FilterChip(
                    key: ValueKey<String>('karto-reiseweg-weg-$art'),
                    label: Text(reiseWegArtName(art)),
                    selected: _wege.contains(art),
                    // Mindestens eine Wegart bleibt gewählt.
                    onSelected: _laedt
                        ? null
                        : (an) => setState(() {
                            if (an) {
                              _wege = {..._wege, art};
                            } else if (_wege.length > 1) {
                              _wege = {..._wege}..remove(art);
                            }
                          }),
                  ),
              ],
            ),
            const SizedBox(height: Abstand.weit),
            SegmentedButton<String>(
              key: const ValueKey<String>('karto-reiseweg-optimierung'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: kReiseOptimierungSchnellste,
                  label: Text('Schnellster'),
                ),
                ButtonSegment(
                  value: kReiseOptimierungKuerzeste,
                  label: Text('Kürzester'),
                ),
              ],
              selected: {_optimierung},
              onSelectionChanged: _laedt
                  ? null
                  : (auswahl) => setState(() => _optimierung = auswahl.first),
            ),
            const SizedBox(height: Abstand.weit),
            KartoReiseplanWahl(
              kennung: 'karto-reiseweg',
              mittel: _mittel,
              eil: _eil,
              wetter: _wetter,
              gesperrt: _laedt,
              onMittel: (m) => setState(() => _mittel = m),
              onEil: (e) => setState(() => _eil = e),
              onWetter: (w) => setState(() => _wetter = w),
            ),
            const SizedBox(height: Abstand.weit),
            if (weg != null) ...[
              Text(
                reisewegText(weg),
                key: const ValueKey<String>('karto-reiseweg-ergebnis'),
                style: texte.fliess,
              ),
              if (plan != null) ...[
                const SizedBox(height: Abstand.normal),
                KartoReiseplanHerleitung(plan: plan),
              ],
            ] else
              Text(
                'Noch nicht berechnet. Ohne Weg gilt die Luftlinie.',
                style: leise,
              ),
            if (_laedt) ...[
              const SizedBox(height: Abstand.normal),
              const LinearProgressIndicator(),
            ],
            if (_fehler != null) ...[
              const SizedBox(height: Abstand.normal),
              Text(
                _fehler!,
                key: const ValueKey<String>('karto-reiseweg-fehler'),
                style: texte.legende.copyWith(color: karto.siegel),
              ),
            ],
            ...[
              const SizedBox(height: Abstand.weit),
              Text('Vorgaben', style: leise),
              for (final variante in kReisewegVarianten)
                _VariantenZeile(
                  variante: variante,
                  weg: switch (_anfrage(variante.wege, variante.optimierung)) {
                    final a? => wege[a.schluessel],
                    null => null,
                  },
                  gewaehlt:
                      _wege.length == variante.wege.length &&
                      _wege.containsAll(variante.wege) &&
                      _optimierung == variante.optimierung,
                  onTap: () => setState(() {
                    _wege = {...variante.wege};
                    _optimierung = variante.optimierung;
                  }),
                ),
            ],
            const SizedBox(height: Abstand.weit),
            Text('Wege: Avesmaps (avesmaps.de)', style: leise),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('karto-reiseweg-vergleichen'),
          onPressed: _laedt
              ? null
              : () => _hole(<AvesmapsRoutenAnfrage>[
                  for (final v in kReisewegVarianten)
                    ?_anfrage(v.wege, v.optimierung),
                ]),
          child: const Text('Vergleichen'),
        ),
        if (anfrage != null && weg == null)
          TextButton(
            key: const ValueKey<String>('karto-reiseweg-berechnen'),
            onPressed: _laedt ? null : () => _hole([anfrage]),
            child: const Text('Berechnen'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-reiseweg-uebernehmen'),
          onPressed: () => Navigator.of(context).pop(
            KartoReisewegWahl(
              anreiseMitPlan(
                alt: widget.etappe.station.anreise,
                wege: _wege,
                optimierung: _optimierung,
                mittel: _mittel,
                eil: _eil,
                wetter: _wetter,
                plan: plan,
              ),
            ),
          ),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

class _VariantenZeile extends StatelessWidget {
  const _VariantenZeile({
    required this.variante,
    required this.weg,
    required this.gewaehlt,
    required this.onTap,
  });

  final ReisewegVariante variante;
  final AvesmapsRoute? weg;
  final bool gewaehlt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final karto = context.karto;
    final weg = this.weg;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey<String>('karto-reiseweg-variante-${variante.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Abstand.knapp),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                gewaehlt ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: gewaehlt ? karto.meer : karto.schriftLeise,
              ),
              const SizedBox(width: Abstand.normal),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(variante.name, style: texte.fliess),
                    Text(
                      weg == null ? 'Noch nicht berechnet' : reisewegText(weg),
                      style: texte.legende.copyWith(color: karto.schriftLeise),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
