import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_breakpoints.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_tiefe.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_kartenraster.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_papier.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_seitenkopf.dart';

/// Baut das Bild eines Helden um den uebergebenen Ersatz herum.
///
/// Dieselbe Signatur wie `KartoBestandsAdapter.heldenbild`, damit der Host die
/// Adaptermethode direkt hereinreichen kann: Avatare rendert ausschliesslich
/// `AvatarGalleryImage` hinter der Bruecke.
typedef KartoHeldenbild = Widget Function({
  required String heroId,
  required String dateiname,
  required double groesse,
  required Widget ersatz,
});

/// Reaktive Auswahl aus dem gemeinsamen Heldenspeicher ohne eigene Selektion.
///
/// Die Helden liegen als Karten auf dem Papiergrund, jede mit Bild oder
/// Monogramm im Kompassring. Eine grosse Kompassrose und Hoehenlinien stehen
/// als Wasserzeichen dahinter.
class KartoHeldenwahl extends ConsumerWidget {
  /// Überlässt die Auswahl dem Host, der Fehler und Navigation koordiniert.
  const KartoHeldenwahl({
    super.key,
    required this.onAuswahl,
    required this.onVerwalten,
    this.onAnmelden,
    this.heldenbild,
    this.fehlendeAuswahl = false,
  });

  /// Speichert die ausgewählte ID über die bestehende Schreib-API.
  final ValueChanged<String> onAuswahl;

  /// Öffnet die Bestandsliste zum Anlegen und Importieren.
  final VoidCallback onVerwalten;

  /// Öffnet Login (`false`) oder Registrierung (`true`).
  ///
  /// Ohne Callback entfällt die Konto-Karte im leeren Zustand.
  final ValueChanged<bool>? onAnmelden;

  /// Rendert das aktive Bild eines Helden. Ohne ihn zeigen alle Karten das
  /// Monogramm.
  final KartoHeldenbild? heldenbild;

  /// Erklärt eine gespeicherte, inzwischen nicht mehr vorhandene ID.
  final bool fehlendeAuswahl;

  /// Zeigt Lade-, Fehler- und Leerzustand samt nutzbaren Rückwegen.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helden = ref.watch(heroListProvider);
    final Widget inhalt;
    if (helden.hasError) {
      inhalt = _liste(context, ref, const [], fehler: helden.error);
    } else if (!helden.hasValue) {
      inhalt = const Center(child: CircularProgressIndicator());
    } else {
      inhalt = _liste(context, ref, helden.requireValue);
    }
    final token = KartoTheme.of(context);
    return KartoPapier(
      child: Stack(
        children: [
          // Wasserzeichen: sie liegen hinter allem und nehmen keine Tipps an.
          Positioned(
            top: -Abstand.rand * 2,
            right: -Abstand.rand * 2,
            child: IgnorePointer(
              child: KartoKompassrose(
                groesse: 360,
                farbe: token.messing.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FractionallySizedBox(
                widthFactor: 0.8,
                heightFactor: 0.6,
                child: KartoHoehenlinien(
                  farbe: token.schrift.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
          Positioned.fill(child: inhalt),
        ],
      ),
    );
  }

  // Auch Fehler und leere Speicher behalten den Einstieg zur Bestandsliste.
  Widget _liste(
    BuildContext context,
    WidgetRef ref,
    List<HeroSheet> helden, {
    Object? fehler,
  }) {
    // Ohne Helden und ohne Konto liegen die Helden oft schon online.
    final kontoKarte =
        fehler == null &&
        helden.isEmpty &&
        onAnmelden != null &&
        ref.watch(authServiceProvider) != null &&
        ref.watch(authUserProvider).asData?.value == null;
    final verwalten = kontoKarte
        ? OutlinedButton.icon(
            onPressed: onVerwalten,
            icon: const Icon(Icons.people_outline),
            label: const Text('Helden verwalten'),
          )
        : FilledButton.icon(
            onPressed: onVerwalten,
            icon: const Icon(Icons.people_outline),
            label: const Text('Helden verwalten'),
          );
    final texte = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final breite = kartoBreiteFuer(constraints.maxWidth);
        final schmal = breite == KartoBreite.schmal;
        return ListView(
          padding: EdgeInsets.all(breite.seitenrand),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KartoSeitenkopf(
                      kontext: 'Heldenverwaltung',
                      titel: 'Deine Helden',
                      kompakt: schmal,
                      // Schmal steht der Knopf unter dem Titel, sonst draengte
                      // er ihn in eine zweite Zeile.
                      aktion: schmal ? null : verwalten,
                    ),
                    if (schmal) ...[
                      const SizedBox(height: Abstand.weit),
                      Align(alignment: Alignment.centerLeft, child: verwalten),
                    ],
                    const SizedBox(height: Abstand.bahn),
                    if (kontoKarte) ...[
                      _KontoKarte(onAnmelden: onAnmelden!),
                      const SizedBox(height: Abstand.bahn),
                    ],
                    if (fehlendeAuswahl) ...[
                      Text(
                        'Der zuletzt gewählte Held ist nicht mehr verfügbar. '
                        'Bitte wähle einen vorhandenen Helden.',
                        style: texte.fliess,
                      ),
                      const SizedBox(height: Abstand.weit),
                    ],
                    if (fehler != null) ...[
                      Text(
                        'Helden konnten nicht geladen werden: $fehler',
                        style: texte.fliess,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => ref.invalidate(heroListProvider),
                          child: const Text('Wiederholen'),
                        ),
                      ),
                    ] else if (helden.isEmpty)
                      const _Leerzustand()
                    else
                      KartoKartenraster(
                        mindestbreite: 300,
                        kinder: [
                          for (final held in helden)
                            _Heldenkarte(
                              held: held,
                              heldenbild: heldenbild,
                              onTap: () => onAuswahl(held.id),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ein Held als antippbare Karte.
///
/// Liegt flach auf dem Papier wie jeder Abschnitt; erst unter Mauszeiger oder
/// Fokus hebt sie sich mit [KartoTiefe.angehoben] ab und bekommt eine
/// Messingkante.
class _Heldenkarte extends StatefulWidget {
  const _Heldenkarte({
    required this.held,
    required this.heldenbild,
    required this.onTap,
  });

  final HeroSheet held;
  final KartoHeldenbild? heldenbild;
  final VoidCallback onTap;

  @override
  State<_Heldenkarte> createState() => _HeldenkarteState();
}

class _HeldenkarteState extends State<_Heldenkarte> {
  static const double _ring = 76;

  bool _schwebt = false;
  bool _fokussiert = false;

  // Erster Buchstabe; leere Namen bekommen ein neutrales Zeichen, damit die
  // Fassung nie leer steht.
  String get _monogramm {
    final name = widget.held.name.trim();
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  // Rasse und Kultur, soweit gepflegt; die Profession steht eine Zeile hoeher.
  String get _herkunft => <String>[
    widget.held.background.rasse,
    widget.held.background.kultur,
  ].map((teil) => teil.trim()).where((teil) => teil.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final token = KartoTheme.of(context);
    final texte = Theme.of(context).textTheme;
    final held = widget.held;
    final aktiv = _schwebt || _fokussiert;
    final radius = BorderRadius.circular(kKartoRadius);
    final profession = held.background.profession.trim();
    final herkunft = _herkunft;

    final monogramm = ColoredBox(
      color: token.senke,
      child: Center(
        child: Text(
          _monogramm,
          style: texte.titel.copyWith(color: token.schriftLeise, height: 1),
        ),
      ),
    );
    final dateiname = held.appearance.aktivesBild?.fileName;
    final bild = dateiname == null || widget.heldenbild == null
        ? monogramm
        : widget.heldenbild!(
            heroId: held.id,
            dateiname: dateiname,
            groesse: _ring - 2 * KartoKompassring.randFuer(_ring),
            ersatz: monogramm,
          );

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: AnimatedContainer(
          duration: kartoDauer(context, Bewegung.kurz),
          curve: Bewegung.kurve,
          decoration: BoxDecoration(
            color: token.feld,
            borderRadius: radius,
            border: Border.all(
              color: aktiv ? token.messing : token.hoehenlinie,
              width: aktiv ? Strich.grat : Strich.hoehenlinie,
            ),
            boxShadow: aktiv
                ? KartoTiefe.angehoben.schatten(token)
                : const <BoxShadow>[],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey<String>('karto-heldenwahl-held-${held.id}'),
              borderRadius: radius,
              onTap: widget.onTap,
              onHover: (wert) => setState(() => _schwebt = wert),
              onFocusChange: (wert) => setState(() => _fokussiert = wert),
              child: Padding(
                padding: Abstand.blockInnen,
                child: Row(
                  children: [
                    KartoKompassring(groesse: _ring, child: bild),
                    const SizedBox(width: Abstand.block),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            held.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: texte.abschnitt,
                          ),
                          if (profession.isNotEmpty) ...[
                            const SizedBox(height: Abstand.haar),
                            Text(
                              profession,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: texte.etikett,
                            ),
                          ],
                          if (herkunft.isNotEmpty) ...[
                            const SizedBox(height: Abstand.haar),
                            Text(
                              herkunft,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: texte.etikett.copyWith(
                                color: token.schriftStumm,
                              ),
                            ),
                          ],
                          const SizedBox(height: Abstand.normal),
                          // Zahl und Bezugsgroesse in einem Text, damit der
                          // Wert das Gewicht traegt und die Zeile als Ganzes
                          // auffindbar bleibt.
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${held.apAvailable}',
                                  style: texte.wert,
                                ),
                                TextSpan(
                                  text: ' AP frei',
                                  style: texte.etikett,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Abstand.normal),
                    Icon(
                      Icons.chevron_right,
                      color: aktiv ? token.messing : token.schriftStumm,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Leerer Speicher: Kompassrose statt leerer Flaeche.
class _Leerzustand extends StatelessWidget {
  const _Leerzustand();

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Abstand.rand),
      child: Column(
        children: [
          const KartoKompassrose(groesse: 120),
          const SizedBox(height: Abstand.block),
          Text(
            'Noch keine Helden vorhanden.',
            style: texte.abschnitt,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Abstand.eng),
          Text(
            'Lege über „Helden verwalten“ einen Helden an oder importiere '
            'einen bestehenden.',
            style: texte.legende,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Hervorgehobener Einstieg in Login und Registrierung.
class _KontoKarte extends StatelessWidget {
  const _KontoKarte({required this.onAnmelden});

  final ValueChanged<bool> onAnmelden;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return KartoFlaeche(
      key: const ValueKey('karto-heldenwahl-konto'),
      innen: Abstand.blockInnen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_sync_outlined, color: context.karto.meer, size: 32),
          const SizedBox(width: Abstand.block),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Helden schon in einem Konto?', style: text.abschnitt),
                const SizedBox(height: Abstand.eng),
                Text(
                  'Melde dich an, um deine Helden von anderen Geräten zu laden '
                  'und künftig zu synchronisieren. Ohne Konto bleibt alles '
                  'lokal.',
                  style: text.fliess,
                ),
                const SizedBox(height: Abstand.weit),
                Wrap(
                  spacing: Abstand.normal,
                  runSpacing: Abstand.normal,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('home-sign-in'),
                      onPressed: () => onAnmelden(false),
                      icon: const Icon(Icons.login),
                      label: const Text('Anmelden'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('home-register'),
                      onPressed: () => onAnmelden(true),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Konto anlegen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
