import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/gefecht_hand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Inhalt der Kampf-Kachel in ihrer Größenstufe (SPIEL-07).
///
/// In `kompakt` und `normal` stehen nur die Probenchips [proben] des Bestands,
/// wie bisher. In einer **weiten** Kachel ([KartoKachelGroesse.weit]) kommt
/// rechts daneben das Panel „Kampfwerte“ hinzu: die Werte, die sonst nur im
/// Gefecht sichtbar sind. Es ordnet nur vorhandene Felder der Kampfvorschau an
/// und rechnet nichts; das Würfeln von INI und TP bleibt im Gefecht.
class KartoKampfInhalt extends StatelessWidget {
  /// Kampf-Kachelinhalt aus den Probenchips [proben] und dem Snapshot [werte].
  const KartoKampfInhalt({
    super.key,
    required this.proben,
    required this.werte,
  });

  /// Schnellproben des Bestands (AT, PA, AW, Nebenhand, Schild).
  final Widget proben;

  /// Gemeinsamer Snapshot, aus dem das Panel seine Werte liest.
  final HeroComputedSnapshot werte;

  @override
  Widget build(BuildContext context) {
    if (KartoKachelSteuerung.groesseVon(context) != KartoKachelGroesse.weit) {
      return proben;
    }
    final karto = context.karto;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: proben),
        const SizedBox(width: Abstand.block),
        Expanded(
          flex: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: karto.hoehenlinie,
                  width: Strich.hoehenlinie,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: Abstand.block),
              child: KartoKampfwerte(werte: werte),
            ),
          ),
        ),
      ],
    );
  }
}

/// Panel „Kampfwerte“: belegte Hände, INI, TP, RS, BE und was zur Waffe gehört.
///
/// Das Wichtigste steht oben (Kopfzeile und das Raster aus INI, TP, RS und
/// BE), seltene Zeilen darunter: der Anordnen-Modus zeigt nur die oberen
/// Zeilen der Kachel.
class KartoKampfwerte extends StatelessWidget {
  /// Panel für den Helden aus [werte].
  const KartoKampfwerte({super.key, required this.werte});

  /// Gemeinsamer Snapshot.
  final HeroComputedSnapshot werte;

  // Betrag eines Wundabzugs (≤ 0) mit echtem Minuszeichen.
  static String _abzug(int wert) => wert < 0 ? '−${-wert}' : '$wert';

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final c = werte.combatPreviewStats;
    final angriff = gefechtsAngriffsanzeige(werte);
    final kopf = c.waffenlos
        ? 'Waffenlos · ${angriff?.name ?? 'Raufen'}'
        : gefechtsHandbelegung(werte.hero.combatConfig);

    final raster = <({String schluessel, String name, String wert})>[
      (
        schluessel: 'karto-kampf-ini',
        name: 'INI',
        wert: '${c.kampfInitiative} + ${c.initiativeDiceSpec.label}',
      ),
      (schluessel: 'karto-kampf-tp', name: 'TP', wert: angriff?.tp ?? '–'),
      (schluessel: 'karto-kampf-rs', name: 'RS', wert: '${c.rsTotal}'),
      (schluessel: 'karto-kampf-be', name: 'BE', wert: '${c.beKampf}'),
    ];

    final zeilen = <({String schluessel, String name, String wert})>[
      if (c.isRangedWeapon) ...[
        if (c.reloadTimeDisplay.isNotEmpty)
          (
            schluessel: 'karto-kampf-ladezeit',
            name: 'Ladezeit',
            wert: c.reloadTimeDisplay,
          ),
        if (c.activeProjectileName.isNotEmpty)
          (
            schluessel: 'karto-kampf-geschoss',
            name: 'Geschoss',
            wert: c.activeProjectileCount > 1
                ? '${c.activeProjectileName} × ${c.activeProjectileCount}'
                : c.activeProjectileName,
          ),
        if (c.activeDistanceLabel.isNotEmpty)
          (
            schluessel: 'karto-kampf-entfernung',
            name: 'Entfernung',
            wert: c.activeDistanceLabel,
          ),
      ],
    ];

    final hinweise = <({String schluessel, String text})>[
      if (c.schwertarmWundMalus != 0)
        (
          schluessel: 'karto-kampf-wundabzug-schwertarm',
          text: 'Schwertarm: ${_abzug(c.schwertarmWundMalus)} auf AT und PA',
        ),
      if (c.schildarmWundMalus != 0)
        (
          schluessel: 'karto-kampf-wundabzug-schildarm',
          text:
              'Schildarm: ${_abzug(c.schildarmWundMalus)} auf Schild und '
              'Nebenhand',
        ),
      if (c.waffenmeisterActive && c.waffenmeisterName.isNotEmpty)
        (
          schluessel: 'karto-kampf-waffenmeister',
          text: 'Waffenmeister: ${c.waffenmeisterName}',
        ),
    ];

    return Column(
      key: const ValueKey<String>('karto-kampf-werte'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Kampfwerte',
          style: texte.marke.copyWith(color: karto.schriftLeise),
        ),
        const SizedBox(height: Abstand.eng),
        Text(
          kopf,
          key: const ValueKey<String>('karto-kampf-haende'),
          style: texte.etikett.copyWith(color: karto.schriftLeise),
        ),
        const SizedBox(height: Abstand.normal),
        LayoutBuilder(
          builder: (context, constraints) {
            // Zwei Spalten, solange jede für „14 + 1W6“ reicht.
            final zweispaltig = constraints.maxWidth >= 200;
            final breite = zweispaltig
                ? (constraints.maxWidth - Abstand.block) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: Abstand.block,
              runSpacing: Abstand.normal,
              children: [
                for (final eintrag in raster)
                  SizedBox(
                    width: breite,
                    child: _Wert(
                      schluessel: eintrag.schluessel,
                      name: eintrag.name,
                      wert: eintrag.wert,
                    ),
                  ),
              ],
            );
          },
        ),
        if (zeilen.isNotEmpty) ...[
          const SizedBox(height: Abstand.weit),
          for (final zeile in zeilen)
            Padding(
              padding: const EdgeInsets.only(bottom: Abstand.eng),
              child: _Zeile(
                schluessel: zeile.schluessel,
                name: zeile.name,
                wert: zeile.wert,
              ),
            ),
        ],
        if (hinweise.isNotEmpty) ...[
          const SizedBox(height: Abstand.normal),
          for (final hinweis in hinweise)
            Padding(
              padding: const EdgeInsets.only(bottom: Abstand.eng),
              child: Text(
                hinweis.text,
                key: ValueKey<String>(hinweis.schluessel),
                style: texte.etikett.copyWith(color: karto.schriftLeise),
              ),
            ),
        ],
      ],
    );
  }
}

// Ein Wert des Rasters: Name klein und leise, darunter der Wert.
class _Wert extends StatelessWidget {
  const _Wert({
    required this.schluessel,
    required this.name,
    required this.wert,
  });

  final String schluessel;
  final String name;
  final String wert;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: texte.etikett.copyWith(color: karto.schriftLeise)),
        Text(
          wert,
          key: ValueKey<String>(schluessel),
          style: texte.wert.copyWith(color: karto.schrift),
        ),
      ],
    );
  }
}

// Eine Zeile aus Name und Wert, der Wert darf umbrechen.
class _Zeile extends StatelessWidget {
  const _Zeile({
    required this.schluessel,
    required this.name,
    required this.wert,
  });

  final String schluessel;
  final String name;
  final String wert;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$name  ',
            style: texte.etikett.copyWith(color: karto.schriftLeise),
          ),
          TextSpan(
            text: wert,
            style: texte.fliess.copyWith(color: karto.schrift),
          ),
        ],
      ),
      key: ValueKey<String>(schluessel),
    );
  }
}
