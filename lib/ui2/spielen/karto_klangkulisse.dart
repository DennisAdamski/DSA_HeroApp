import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dsa_heldenverwaltung/data/freesound/freesound_client.dart';
import 'package:dsa_heldenverwaltung/domain/klangstimmung.dart';
import 'package:dsa_heldenverwaltung/state/klangkulisse_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_breakpoints.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui_shared/freesound_anmeldung.dart';

/// Legt das Klangpult über die ganze App: eine Lasche am rechten Rand öffnet
/// es auf jeder Route, auch im Gefecht.
///
/// Sitzt in `MaterialApp.builder` oberhalb des App-Navigators. Das Pult bringt
/// deshalb einen eigenen [Navigator] mit, damit Tooltips, Regler und der
/// Anmeldedialog ein Overlay finden. Schreibt nichts am Helden.
class KartoKlangpultHuelle extends ConsumerStatefulWidget {
  /// Erstellt die Hülle um [child].
  const KartoKlangpultHuelle({
    super.key,
    required this.sichtbar,
    required this.child,
  });

  /// Ob Lasche und Pult erscheinen.
  final bool sichtbar;

  /// Die App darunter.
  final Widget child;

  @override
  ConsumerState<KartoKlangpultHuelle> createState() =>
      _KartoKlangpultHuelleState();
}

class _KartoKlangpultHuelleState extends ConsumerState<KartoKlangpultHuelle> {
  bool _offen = false;

  void _schliessen() => setState(() => _offen = false);

  @override
  Widget build(BuildContext context) {
    if (!widget.sichtbar) return Stack(children: [widget.child]);
    final groesse = MediaQuery.sizeOf(context);
    final schmal = kartoBreiteFuer(groesse.width) == KartoBreite.schmal;
    final laeuft = ref.watch(klangkulisseProvider.select((z) => z.laeuft));
    final token = context.karto;
    return Stack(
      children: [
        widget.child,
        if (!_offen)
          Align(
            alignment: const Alignment(1, 0.35),
            child: Material(
              color: token.navigation,
              elevation: 3,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(kKartoRadius),
              ),
              child: InkWell(
                key: const ValueKey<String>('karto-klangpult-lasche'),
                onTap: () => setState(() => _offen = true),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(kKartoRadius),
                ),
                child: Semantics(
                  button: true,
                  label: 'Klangpult öffnen',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Abstand.normal,
                      vertical: Abstand.block,
                    ),
                    child: Badge(
                      isLabelVisible: laeuft,
                      backgroundColor: token.messingNavigation,
                      smallSize: 8,
                      child: Icon(
                        Icons.graphic_eq,
                        color: token.messingNavigation,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_offen)
          Positioned(
            top: schmal ? groesse.height * 0.25 : 0,
            bottom: 0,
            right: 0,
            left: schmal ? 0 : null,
            width: schmal ? null : 380,
            child: Material(
              elevation: 12,
              color: token.blatt,
              clipBehavior: Clip.antiAlias,
              borderRadius: schmal
                  ? const BorderRadius.vertical(
                      top: Radius.circular(kKartoRadius),
                    )
                  : BorderRadius.zero,
              child: SafeArea(
                left: false,
                top: !schmal,
                // Der App-Navigator teilt seinen HeroController nicht.
                child: HeroControllerScope.none(
                  child: Navigator(
                    onGenerateRoute: (_) => PageRouteBuilder<void>(
                      pageBuilder: (_, _, _) =>
                          KartoKlangpult(onSchliessen: _schliessen),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Das Pult: Szenen, Musik, Ambiente-Ebenen, Effekte und Quellen.
class KartoKlangpult extends ConsumerWidget {
  /// Erstellt das Pult.
  const KartoKlangpult({super.key, required this.onSchliessen});

  /// Schließt das Pult; der Klang läuft weiter.
  final VoidCallback onSchliessen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(klangkulisseProvider);
    final pult = ref.read(klangkulisseProvider.notifier);
    final angemeldet = ref.watch(freesoundZugangProvider).asData?.value != null;
    final texte = Theme.of(context).textTheme;
    final leise = texte.fliess.copyWith(color: context.karto.schriftLeise);
    final szene = zustand.szene;

    Widget titel(String text) => Padding(
      padding: const EdgeInsets.only(
        top: Abstand.block,
        bottom: Abstand.normal,
      ),
      child: Text(text, style: texte.abschnitt),
    );

    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.all(Abstand.block),
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq),
              const SizedBox(width: Abstand.normal),
              Expanded(child: Text('Klangpult', style: texte.titel)),
              IconButton(
                key: const ValueKey<String>('karto-klangpult-stopp'),
                tooltip: 'Alles anhalten',
                onPressed: zustand.laeuft ? pult.allesStopp : null,
                icon: const Icon(Icons.stop_circle_outlined),
              ),
              IconButton(
                key: const ValueKey<String>('karto-klangpult-schliessen'),
                tooltip: 'Schließen',
                onPressed: onSchliessen,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (!angemeldet)
            const FreesoundAnmeldungBereich()
          else ...[
            Row(
              children: [
                const Icon(Icons.volume_up_outlined),
                Expanded(
                  child: Slider(
                    key: const ValueKey<String>('karto-klangpult-gesamt'),
                    value: zustand.gesamt,
                    label: 'Gesamt',
                    onChanged: pult.gesamtLautstaerke,
                  ),
                ),
              ],
            ),
            if (zustand.laedt > 0) const LinearProgressIndicator(),
            if (zustand.fehler case final fehler?)
              Padding(
                padding: const EdgeInsets.only(top: Abstand.normal),
                child: Text(fehler, style: leise),
              ),
            titel('Szene'),
            Wrap(
              spacing: Abstand.normal,
              runSpacing: Abstand.normal,
              children: [
                for (final s in kKlangszenen)
                  _Szenenkachel(
                    szene: s,
                    aktiv: s.id == zustand.szeneId,
                    onTap: () => pult.szeneWaehlen(s),
                  ),
              ],
            ),
            if (szene != null) ...[
              titel('Musik'),
              SegmentedButton<Musiklage?>(
                key: const ValueKey<String>('karto-klangpult-musik'),
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(value: null, label: Text('Aus')),
                  for (final lage in Musiklage.values)
                    ButtonSegment(value: lage, label: Text(lage.titel)),
                ],
                selected: {zustand.musiklage},
                onSelectionChanged: (wahl) => pult.musik(wahl.first),
              ),
              Slider(
                value: zustand.musikStaerke,
                onChanged: zustand.musiklage == null ? null : pult.musikStaerke,
              ),
              titel('Ambiente'),
              for (final ebene in szene.ambiente)
                if (zustand.ebenen[ebene.id] case final e?)
                  Row(
                    children: [
                      Switch(
                        key: ValueKey<String>(
                          'karto-klangpult-ebene-${ebene.id}',
                        ),
                        value: e.an,
                        onChanged: (_) => pult.ebeneUmschalten(ebene.id),
                      ),
                      const SizedBox(width: Abstand.normal),
                      SizedBox(width: 88, child: Text(ebene.titel)),
                      Expanded(
                        child: Slider(
                          value: e.staerke,
                          onChanged: e.an
                              ? (v) => pult.ebenenStaerke(ebene.id, v)
                              : null,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Anderer Klang',
                        onPressed: e.an && e.klang != null
                            ? () => pult.andererKlang(ebene.id)
                            : null,
                        icon: const Icon(Icons.shuffle),
                      ),
                    ],
                  ),
              titel('Effekte'),
              Wrap(
                spacing: Abstand.normal,
                runSpacing: Abstand.normal,
                children: [
                  for (final effekt in szene.effekte)
                    FilledButton.tonal(
                      key: ValueKey<String>(
                        'karto-klangpult-effekt-${effekt.id}',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 52),
                      ),
                      onPressed: () => pult.effekt(effekt),
                      child: Text(effekt.titel),
                    ),
                ],
              ),
            ],
            if (zustand.quellen.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Quellen (${zustand.quellen.length})'),
                children: [
                  for (final klang in zustand.quellen) _Nennung(klang: klang),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Szenenkachel extends StatelessWidget {
  const _Szenenkachel({
    required this.szene,
    required this.aktiv,
    required this.onTap,
  });

  final Klangszene szene;
  final bool aktiv;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final token = context.karto;
    final radius = BorderRadius.circular(kKartoRadius);
    return SizedBox(
      width: 104,
      height: 76,
      child: Material(
        color: aktiv ? token.messing.withValues(alpha: 0.18) : token.feld,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: aktiv ? token.messing : token.hoehenlinie,
            width: aktiv ? 2 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey<String>('karto-klangpult-szene-${szene.id}'),
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Abstand.knapp),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_symbol(szene.id)),
                const SizedBox(height: Abstand.eng),
                Text(
                  szene.titel,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.etikett,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _symbol(String id) => switch (id) {
    'taverne' => Icons.sports_bar_outlined,
    'stadt' => Icons.storefront_outlined,
    'wald' => Icons.forest_outlined,
    'nachtlager' => Icons.local_fire_department_outlined,
    'hoehle' => Icons.terrain_outlined,
    'sturm' => Icons.thunderstorm_outlined,
    'meer' => Icons.sailing_outlined,
    'tempel' => Icons.account_balance_outlined,
    'wueste' => Icons.wb_sunny_outlined,
    'gebirge' => Icons.ac_unit_outlined,
    'sumpf' => Icons.water_outlined,
    _ => Icons.graphic_eq,
  };
}

/// Namensnennung eines Klangs mit Rücklink zu Freesound (CC BY verlangt sie).
class _Nennung extends StatelessWidget {
  const _Nennung({required this.klang});

  final FreesoundKlang klang;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse(klang.seite),
        mode: LaunchMode.externalApplication,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Abstand.eng),
        child: Text(
          '„${klang.name}“ von ${klang.urheber} · ${klang.lizenzKurz} · '
          'Freesound',
          style: texte.fliess.copyWith(color: context.karto.schriftLeise),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
