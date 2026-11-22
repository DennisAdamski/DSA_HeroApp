import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_event_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_protection_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_wirkungszeile.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';

/// Laufende Zauberwirkungen im Gefecht: einsehen, anpassen und anlegen.
///
/// Zeigt jede Wirkung des Helden mit Quelle, Ziel, Dauer und Schutzvorrat
/// (dieselben Regelfunktionen wie der Effektedialog der Spielansicht). Schreiben
/// läuft frisch über [KartoGefechtsAdapter.gefechtsZustand] bzw.
/// [KartoGefechtsAdapter.gefechtsWirkung]; die Kachel hält keinen Stand.
/// Alte Einzelwirkungen (Axxeleratus, Armatrutz, Legacy-Attributo) bleiben im
/// Effektedialog ([effekteVerwalten]).
class GefechtZauberwirkungen extends ConsumerWidget {
  /// Erstellt die Kachel.
  const GefechtZauberwirkungen({
    super.key,
    required this.heroId,
    required this.bestand,
    required this.gesperrt,
    required this.onAktion,
    required this.effekteVerwalten,
  });

  /// Held, dessen Wirkungen gezeigt werden.
  final String heroId;

  /// Löst die Gefechtsbrücke erst beim Bedienen auf; die Anzeige braucht sie nicht.
  final KartoGefechtsAdapter Function() bestand;

  /// Sperrt die Bedienung, solange eine andere Handlung läuft.
  final bool gesperrt;

  /// Führt eine Bedienung unter dem gemeinsamen Guard der Gefechtsansicht aus.
  final Future<void> Function(Future<void> Function()) onAktion;

  /// Öffnet den vollständigen Effektedialog.
  final VoidCallback effekteVerwalten;

  // Schreibt frisch auf den gespeicherten Zustand; Fehler zeigt der Zustandsweg.
  void _schreibe(
    BuildContext context,
    WidgetRef ref,
    HeroState Function(HeroState aktuell) aenderung,
  ) => onAktion(() async {
    await bestand().gefechtsZustand(
      context: context,
      ref: ref,
      heroId: heroId,
      was: 'Zaubereffekt',
      aenderung: aenderung,
    );
  });

  void _wirkung(
    BuildContext context,
    WidgetRef ref,
    GefechtsWirkungAktion aktion, [
    String? instanzId,
  ]) => onAktion(
    () => bestand().gefechtsWirkung(
      context: context,
      ref: ref,
      heroId: heroId,
      aktion: aktion,
      instanzId: instanzId,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(heroComputedProvider(heroId)).asData?.value.state;
    final katalog = ref.watch(heroRulesCatalogProvider(heroId)).asData?.value;
    if (zustand == null) return const SizedBox.shrink();
    final wirkungen = aktiveEffektInstanzen(zustand);
    final aufrechterhalten = aufrechterhaltungsBefund(zustand, katalog).anzahl;
    final kannAnlegen =
        katalog != null && spellEffectAuswahl(katalog).isNotEmpty;
    return KartoAbschnitt(
      key: ValueKey<String>('gefecht-zauberwirkungen-$heroId'),
      titel: 'Zauberwirkungen',
      symbol: Icons.auto_awesome_outlined,
      akzent: KartoAkzent.astral,
      hinweis: wirkungen.isEmpty
          ? null
          : '${wirkungen.length} laufend'
                '${aufrechterhalten > 0 ? ' · $aufrechterhalten aufrechtzuerhalten' : ''}',
      aktion: TextButton(
        key: const ValueKey<String>('gefecht-wirkungen-verwalten'),
        onPressed: gesperrt ? null : effekteVerwalten,
        child: const Text('Alle verwalten'),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wirkungen.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Keine Zauberwirkung läuft.'),
              ),
            for (var i = 0; i < wirkungen.length; i++)
              _zeile(context, ref, zustand, katalog, wirkungen, i),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (kannAnlegen)
                  OutlinedButton.icon(
                    key: const ValueKey<String>('gefecht-wirkung-hinzu'),
                    onPressed: gesperrt
                        ? null
                        : () => _wirkung(
                            context,
                            ref,
                            GefechtsWirkungAktion.zauberHinzufuegen,
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('Zauberwirkung hinzufügen'),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey<String>(
                    'gefecht-wirkung-attributo-hinzu',
                  ),
                  onPressed: gesperrt
                      ? null
                      : () => _wirkung(
                          context,
                          ref,
                          GefechtsWirkungAktion.attributoHinzufuegen,
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('Attributo als Quelle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _zeile(
    BuildContext context,
    WidgetRef ref,
    HeroState zustand,
    RulesCatalog? katalog,
    List<SpellEffectInstance> wirkungen,
    int index,
  ) {
    final w = wirkungen[index];
    final name = effektName(w.effectId, katalog);
    final aufrecht = effektVerlangtAufrechterhaltung(w.effectId, katalog);
    // Alte Einzelwerte tragen keine eigene Instanz: nur Anzeige, bedient im Dialog.
    if (istLegacyInstanz(w.id)) {
      return GefechtWirkungszeile(
        instanz: w,
        titel: '$name (alt)',
        mussAufrechterhaltenWerden: aufrecht,
        gesperrt: gesperrt,
      );
    }
    final schild = kSchutzZauberIds.contains(w.effectId);
    final gleicheQuellen = wirkungen
        .where((x) => x.effectId == w.effectId && !istLegacyInstanz(x.id))
        .toList();
    final nummer = gleicheQuellen.indexWhere((x) => x.id == w.id) + 1;
    final kannEinsetzen =
        w.effectId == kAengsteLindernZauberId ||
        (schild && !w.unterdrueckt && schutzRestVon(w) > 0);
    return GefechtWirkungszeile(
      instanz: w,
      titel: gleicheQuellen.length > 1 ? '$name · Quelle $nummer' : name,
      ueberlagert: ueberlagerteEigenschaften(zustand, w.id),
      mussAufrechterhaltenWerden: aufrecht,
      gesperrt: gesperrt,
      onWirktChanged: (wirkt) => _schreibe(
        context,
        ref,
        (aktuell) =>
            unterdrueckeEffektInstanz(aktuell, w.id, unterdrueckt: !wirkt),
      ),
      onDauerMinus: () => _schreibe(
        context,
        ref,
        (aktuell) =>
            zaehleEffektInstanzDauer(aktuell, w.id, zuruecksetzen: false),
      ),
      onDauer: () => _wirkung(context, ref, GefechtsWirkungAktion.dauer, w.id),
      onEinsetzen: kannEinsetzen
          ? () => _wirkung(context, ref, GefechtsWirkungAktion.einsetzen, w.id)
          : null,
      einsetzenLabel: schild
          ? 'Magischen Treffer auffangen'
          : 'In Mut-Probe einsetzen',
      onSchutz: schild
          ? () =>
                _wirkung(context, ref, GefechtsWirkungAktion.schutzvorrat, w.id)
          : null,
      onBeenden: () => _schreibe(
        context,
        ref,
        (aktuell) => beendeEffektInstanz(aktuell, w.id),
      ),
    );
  }
}
