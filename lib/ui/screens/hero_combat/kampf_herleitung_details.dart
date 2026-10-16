import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/herleitung_abschnitt.dart';

/// Aufklappbare Berechnungsschritte der Kampfvorschau (ARCH-04).
///
/// Zeigt ausschließlich die Herleitungen aus `computeCombatPreviewStats`;
/// das Ergebnis jedes Abschnitts ist [Herleitung.wert] und damit der Wert,
/// den die Vorschau verwendet. Hier wird nichts gerechnet.
class KampfHerleitungDetails extends StatelessWidget {
  /// Erzeugt die Berechnungsschritte für [preview].
  const KampfHerleitungDetails({super.key, required this.preview});

  /// Kampfvorschau mit ihren Herleitungen.
  final CombatPreviewStats preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = preview.herleitungen;
    final neben = preview.offhandPreview;
    final nebenHerleitungen = neben != null && neben.isWeapon
        ? neben.herleitungen
        : null;
    if (h == null) {
      return const SizedBox.shrink();
    }
    final fernkampf = preview.isRangedWeapon;
    return Column(
      children: [
        ExpansionTile(
          key: const ValueKey<String>('combat-weapon-calculation-details'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(
            neben != null
                ? 'Berechnungsschritte (Haupthand)'
                : 'Berechnungsschritte',
            style: theme.textTheme.titleSmall,
          ),
          initiallyExpanded: false,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Abschnitt(
                    titel: fernkampf ? 'Fernkampf (AT)' : 'Attacke (AT)',
                    herleitung: h.at,
                  ),
                  if (h.paMitIniParade case final pa?) ...[
                    const Divider(),
                    _Abschnitt(titel: 'Parade (PA)', herleitung: pa),
                  ],
                  if (h.schildPaMitIniParade ?? h.schildPa
                      case final schildPa?) ...[
                    const Divider(),
                    _Abschnitt(titel: 'Schild-Parade', herleitung: schildPa),
                  ],
                  const Divider(),
                  _Abschnitt(
                    titel: 'Trefferpunkte (TP)',
                    herleitung: h.tpZuschlag,
                    ergebnis: preview.tpExpression,
                    wuerfel:
                        '${preview.damageDiceSpec.count}'
                        'W${preview.damageDiceSpec.sides}',
                  ),
                  const Divider(),
                  _Abschnitt(titel: 'Initiative (INI)', herleitung: h.kampfIni),
                  if (!fernkampf) ...[
                    const Divider(),
                    _Abschnitt(titel: 'Ausweichen', herleitung: h.ausweichen),
                  ],
                  const Divider(),
                  _Abschnitt(titel: 'Rüstungsschutz (RS)', herleitung: h.rs),
                  _Abschnitt(titel: 'Behinderung (BE)', herleitung: h.beKampf),
                  _Abschnitt(
                    titel: 'Effektive Behinderung (eBE)',
                    herleitung: h.ebe,
                  ),
                  if (fernkampf) ...[
                    const Divider(),
                    _LadezeitAbschnitt(preview: preview),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (nebenHerleitungen != null)
          ExpansionTile(
            key: const ValueKey<String>('combat-offhand-calculation-details'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(
              'Berechnungsschritte (Nebenhand)',
              style: theme.textTheme.titleSmall,
            ),
            initiallyExpanded: false,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Abschnitt(
                      titel: neben!.isRangedWeapon
                          ? 'Fernkampf (AT)'
                          : 'Attacke (AT)',
                      herleitung: nebenHerleitungen.at,
                    ),
                    if (nebenHerleitungen.paMitIniParade case final pa?) ...[
                      const Divider(),
                      _Abschnitt(titel: 'Parade (PA)', herleitung: pa),
                    ],
                    const Divider(),
                    _Abschnitt(
                      titel: 'Trefferpunkte (TP)',
                      herleitung: nebenHerleitungen.tpZuschlag,
                      ergebnis: neben.tpExpression,
                      wuerfel: neben.damageDiceSpec == null
                          ? null
                          : '${neben.damageDiceSpec!.count}'
                                'W${neben.damageDiceSpec!.sides}',
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// Ein Abschnitt „Titel = Ergebnis“ mit den sichtbaren Schritten.
class _Abschnitt extends StatelessWidget {
  const _Abschnitt({
    required this.titel,
    required this.herleitung,
    this.ergebnis,
    this.wuerfel,
  });

  final String titel;
  final Herleitung herleitung;

  /// Abweichende Ergebnisanzeige, etwa der TP-Ausdruck „1W6+4“.
  final String? ergebnis;

  /// Würfel vor dem festen Zuschlag (nur TP).
  final String? wuerfel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Kopf(titel: titel, ergebnis: ergebnis ?? '${herleitung.wert}'),
          if (wuerfel != null)
            _TextZeile(bezeichnung: 'Würfel', text: wuerfel!),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: HerleitungsSchritte(herleitung: herleitung),
          ),
        ],
      ),
    );
  }
}

class _Kopf extends StatelessWidget {
  const _Kopf({required this.titel, required this.ergebnis});

  final String titel;
  final String ergebnis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stil = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.bold,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Flexible(child: Text(titel, style: stil)),
          const SizedBox(width: 8),
          Text(
            '= $ergebnis',
            style: stil?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _TextZeile extends StatelessWidget {
  const _TextZeile({required this.bezeichnung, required this.text});

  final String bezeichnung;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 0, 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              bezeichnung,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

// Ladezeit bleibt eine Aufzählung: Halbierung und Teilung sind nicht additiv.
class _LadezeitAbschnitt extends StatelessWidget {
  const _LadezeitAbschnitt({required this.preview});

  final CombatPreviewStats preview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Kopf(titel: 'Ladezeit', ergebnis: preview.reloadTimeDisplay),
        _TextZeile(bezeichnung: 'Basis', text: '${preview.baseReloadTime}'),
        if (preview.schnellladenBogenActive)
          _TextZeile(
            bezeichnung: preview.schnellladenBogenTemporary
                ? 'Schnellladen (Bogen) via Axxeleratus'
                : 'Schnellladen (Bogen)',
            text: 'aktiv',
          ),
        if (preview.schnellladenArmbrustActive)
          _TextZeile(
            bezeichnung: preview.schnellladenArmbrustTemporary
                ? 'Schnellladen (Armbrust) via Axxeleratus'
                : 'Schnellladen (Armbrust)',
            text: 'aktiv',
          ),
        if (preview.waffenmeisterReloadTimeHalved)
          const _TextZeile(
            bezeichnung: 'Waffenmeister',
            text: 'Ladezeit halbiert',
          ),
      ],
    );
  }
}
