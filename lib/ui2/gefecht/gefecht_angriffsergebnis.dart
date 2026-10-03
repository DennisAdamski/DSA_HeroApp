import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_angriff_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

/// Zeigt Erfolgsfolgen und würfelt nur das eingefrorene Profil dieses Angriffs.
class GefechtAngriffsergebnisAnzeige extends ConsumerWidget {
  /// Allgemeine Schadensproben verwenden dieses Ergebnis nicht.
  const GefechtAngriffsergebnisAnzeige({
    super.key,
    required this.ergebnis,
    required this.heroId,
    required this.bestand,
    required this.gesperrt,
    required this.onAktion,
  });
  final Gefechtsangriffsergebnis ergebnis;
  final String heroId;
  final KartoGefechtsAdapter bestand;
  final bool gesperrt;
  final Future<void> Function(Future<void> Function()) onAktion;

  /// Die Ergebnis-ID hält selbst doppelte Rückmeldungen beim richtigen Angriff.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = gefechtsSchadenFuerAngriff(ergebnis);
    // Würfelabschluss und manuelle Abwicklung entfernen dieselbe konkrete ID.
    void abschliessen() {
      final s = ref.read(gefechtProvider(heroId));
      if (s == null) return;
      ref
          .read(gefechtProvider(heroId).notifier)
          .setzen(entferneGefechtsAngriffsergebnis(s, ergebnis.auftragId));
    }

    final titel = ergebnis.manoevername.isEmpty
        ? 'Erfolgreicher Angriff'
        : '${ergebnis.manoevername} gelungen';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$titel · ${ergebnis.waffenname}'),
        Text('Gegnerische Abwehr: +${ergebnis.abwehrmalus}'),
        if (request != null)
          Text('TP-Bonus: +${ergebnis.tpBonus}')
        else if (ergebnis.tpBonus != 0)
          Text('TP-Ansage: +${ergebnis.tpBonus} · Folgen manuell festlegen'),
        Text(ergebnis.hinweis),
        if (request != null)
          TextButton(
            key: const ValueKey('gefecht-angriffsschaden'),
            onPressed: gesperrt
                ? null
                : () => onAktion(() async {
                    await bestand.gefechtsProbe(
                      context: context,
                      ref: ref,
                      heroId: heroId,
                      request: request,
                      onResolved: (_) => abschliessen(),
                    );
                  }),
            child: Text('Schaden dieses Angriffs · ${request.diceSpec.label}'),
          )
        else
          TextButton(
            key: const ValueKey('gefecht-angriffsfolgen-abschliessen'),
            onPressed: gesperrt ? null : abschliessen,
            child: Text(
              ergebnis.schadensfolge == GefechtsSchadensfolge.keinSchaden
                  ? 'Folgen am Tisch abgewickelt'
                  : 'Manuelle Folgen erledigt',
            ),
          ),
      ],
    );
  }
}
