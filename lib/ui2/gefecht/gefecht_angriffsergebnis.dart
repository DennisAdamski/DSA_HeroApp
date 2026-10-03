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
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Erfolgreicher Angriff · ${ergebnis.waffenname}'),
      Text(
        'Gegnerische Abwehr: +${ergebnis.abwehrmalus} · TP-Bonus: +${ergebnis.tpBonus}',
      ),
      Text(ergebnis.hinweis),
      TextButton(
        key: const ValueKey('gefecht-angriffsschaden'),
        onPressed: gesperrt
            ? null
            : () => onAktion(() async {
                await bestand.gefechtsProbe(
                  context: context,
                  ref: ref,
                  heroId: heroId,
                  request: gefechtsSchadenFuerAngriff(ergebnis),
                  onResolved: (_) {
                    final s = ref.read(gefechtProvider(heroId));
                    if (s == null) {
                      return;
                    }
                    ref
                        .read(gefechtProvider(heroId).notifier)
                        .setzen(
                          entferneGefechtsAngriffsergebnis(
                            s,
                            ergebnis.auftragId,
                          ),
                        );
                  },
                );
              }),
        child: Text('Schaden dieses Angriffs · ${ergebnis.schaden.label}'),
      ),
    ],
  );
}
