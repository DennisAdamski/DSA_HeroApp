import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_magie_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';

/// Tatsächliche Katalogzauber und karmale Einträge mit klarer manueller Grenze.
///
/// Zauber stehen zuletzt gewirkt zuerst, sonst alphabetisch, jeweils mit ZfW*,
/// Zauberdauer und Kosten (`gefechtsZauberliste`); ab sieben gelernten
/// Zaubern gibt es eine Suche.
class GefechtMagie extends StatefulWidget {
  /// Führt die Probe über den gemeinsamen, aktionsgebundenen Auftrag aus.
  const GefechtMagie({
    super.key,
    required this.werte,
    required this.katalog,
    required this.gesperrt,
    required this.onAuftrag,
    this.onZauber,
    this.onKarma,
    this.zuletzt = const [],
  });
  final HeroComputedSnapshot werte;
  final RulesCatalog? katalog;
  final bool gesperrt;
  final ValueChanged<SpellDef>? onZauber;
  final ValueChanged<TalentDef>? onKarma;
  final void Function(
    String titel,
    ResolvedProbeRequest? probe,
    String beschreibung,
  )
  onAuftrag;

  /// Katalog-IDs der zuletzt begonnenen Zauber dieses Gefechts.
  final List<String> zuletzt;

  @override
  State<GefechtMagie> createState() => _GefechtMagieState();
}

class _GefechtMagieState extends State<GefechtMagie> {
  String _suche = '';

  // Startet Wirken oder fällt auf den manuellen Auftrag zurück.
  void _zauber(SpellDef z) {
    final onZauber = widget.onZauber;
    if (onZauber != null) {
      onZauber(z);
      return;
    }
    widget.onAuftrag(
      z.name,
      gefechtsZauberprobe(widget.werte, z),
      '${z.wirkung}\nDauer: ${z.castingTime}\nKosten: ${z.aspCost}\n'
      'Reichweite: ${z.range}\nZiel: ${z.targetObject}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final werte = widget.werte;
    final katalog = widget.katalog;
    final gesperrt = widget.gesperrt;
    final onKarma = widget.onKarma;
    final onAuftrag = widget.onAuftrag;
    if (!werte.resourceActivation.magic.isEnabled &&
        !werte.resourceActivation.divine.isEnabled) {
      return const SizedBox.shrink();
    }
    final alle = katalog == null
        ? const <GefechtsZaubereintrag>[]
        : gefechtsZauberliste(werte, katalog, zuletzt: widget.zuletzt);
    final zauber = katalog == null || _suche.trim().isEmpty
        ? alle
        : gefechtsZauberliste(
            werte,
            katalog,
            zuletzt: widget.zuletzt,
            suche: _suche,
          );
    return KartoAbschnitt(
      titel: 'Magie und Karma',
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (alle.length > 6)
              TextField(
                key: const ValueKey('gefecht-zauber-suche'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Zauber suchen',
                ),
                onChanged: (v) => setState(() => _suche = v),
              ),
            for (final eintrag in zauber)
              ListTile(
                key: ValueKey('gefecht-zauber-${eintrag.zauber.id}'),
                contentPadding: EdgeInsets.zero,
                enabled: !gesperrt,
                leading: eintrag.zuletzt ? const Icon(Icons.history) : null,
                title: Text(eintrag.zauber.name),
                subtitle: Text(eintrag.detail),
                onTap: () => _zauber(eintrag.zauber),
              ),
            if (werte.resourceActivation.divine.isEnabled) ...[
              for (final talent in katalog?.talents ?? <TalentDef>[])
                if (talent.name.toLowerCase().contains('liturgiekenntnis') &&
                    gefechtsLiturgieprobe(werte, talent) != null)
                  TextButton(
                    onPressed: gesperrt
                        ? null
                        : () => onKarma != null
                              ? onKarma(talent)
                              : onAuftrag(
                                  talent.name,
                                  gefechtsLiturgieprobe(werte, talent),
                                  'Tatsächliche Liturgiekenntnis; Liturgie, Grad, '
                                  'Modifikatoren, Zeitpunkt, Dauer und KaP-Kosten '
                                  'ausdrücklich bestätigen.',
                                ),
                    child: Text('${talent.name} · Liturgie wirken'),
                  ),
              for (final sf
                  in katalog == null
                      ? <SpecialAbilityDef>[]
                      : gefechtKarmaleFertigkeiten(werte, katalog))
                TextButton(
                  onPressed: gesperrt
                      ? null
                      : () => onAuftrag(
                          sf.name,
                          null,
                          '${sf.beschreibung}\n${sf.voraussetzungen}',
                        ),
                  child: Text('${sf.name} · manuell'),
                ),
              TextButton(
                onPressed: gesperrt
                    ? null
                    : () => onAuftrag(
                        'Mirakel / Liturgie',
                        null,
                        'Erlernte Liturgie, Grad, LkW, Probe, Zeitpunkt, Dauer und KaP-Kosten '
                            'anhand des tatsächlichen Helden und Regeltexts prüfen. Keine automatische Bonusformel.',
                      ),
                child: const Text('Karmale Handlung manuell führen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
