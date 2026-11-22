import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_client.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_routen_repository.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_routen_speicher.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Lokaler Zwischenspeicher der Reisewege; `null`, solange der Abruf aus ist.
final avesmapsRoutenSpeicherProvider = FutureProvider<AvesmapsRoutenSpeicher?>((
  ref,
) async {
  if (!ref.watch(avesmapsAktivProvider)) return null;
  final speicherort = await ref.watch(heroStorageLocationProvider.future);
  final speicher = HiveAvesmapsRoutenSpeicher(
    speicherPfad: speicherort.effectivePath,
  );
  ref.onDispose(speicher.close);
  return speicher;
});

/// Hält Reisewege lokal vor; `null`, solange der Abruf aus ist.
final avesmapsRoutenRepositoryProvider =
    FutureProvider<AvesmapsRoutenRepository?>((ref) async {
      final client = ref.watch(avesmapsClientProvider);
      if (client == null) return null;
      final speicher = await ref.watch(avesmapsRoutenSpeicherProvider.future);
      if (speicher == null) return null;
      return AvesmapsRoutenRepository(client: client, speicher: speicher);
    });

/// Ergebnis eines Abrufs mehrerer Reisewege.
class ReisewegeAbruf {
  /// Erstellt das Ergebnis.
  const ReisewegeAbruf({this.geholt = 0, this.offen = 0, this.fehler});

  /// Wie viele Wege neu geholt wurden.
  final int geholt;

  /// Wie viele Wege wegen eines Fehlers noch fehlen.
  final int offen;

  /// Meldung, warum das Holen aufgehört hat, oder `null`.
  final String? fehler;
}

/// Die gemerkten Reisewege, Schlüssel ist
/// [AvesmapsRoutenAnfrage.schluessel].
///
/// Beim Bauen liest es nur den lokalen Speicher. Nachgefragt wird erst mit
/// [hole], also auf eine Nutzeraktion hin, und nacheinander: Nach einer
/// Drossel hört es auf und nennt die Wartezeit.
class AvesmapsReisewege extends AsyncNotifier<Map<String, AvesmapsRoute>> {
  @override
  Future<Map<String, AvesmapsRoute>> build() async {
    final repository = await ref.watch(avesmapsRoutenRepositoryProvider.future);
    return await repository?.gemerkt() ?? const <String, AvesmapsRoute>{};
  }

  /// Der gemerkte Weg der [anfrage], oder `null`.
  AvesmapsRoute? gemerkt(AvesmapsRoutenAnfrage anfrage) =>
      state.asData?.value[anfrage.schluessel];

  /// Holt die noch fehlenden Wege der [anfragen] nacheinander.
  Future<ReisewegeAbruf> hole(Iterable<AvesmapsRoutenAnfrage> anfragen) async {
    final repository = await ref.read(avesmapsRoutenRepositoryProvider.future);
    final bekannt = await future;
    final fehlend = <AvesmapsRoutenAnfrage>{
      for (final anfrage in anfragen)
        if (!bekannt.containsKey(anfrage.schluessel)) anfrage,
    }.toList();
    if (fehlend.isEmpty) return const ReisewegeAbruf();
    if (repository == null || !repository.kannHolen) {
      return ReisewegeAbruf(
        offen: fehlend.length,
        fehler: 'Reisewege lassen sich hier nicht abrufen.',
      );
    }
    var geholt = 0;
    for (var i = 0; i < fehlend.length; i++) {
      final anfrage = fehlend[i];
      try {
        final route = await repository.hole(anfrage);
        geholt++;
        if (!ref.mounted) return ReisewegeAbruf(geholt: geholt);
        state = AsyncData(<String, AvesmapsRoute>{
          ...?state.asData?.value,
          anfrage.schluessel: route,
        });
      } on AvesmapsFehler catch (fehler) {
        return ReisewegeAbruf(
          geholt: geholt,
          offen: fehlend.length - i,
          fehler: reisewegFehlerText(fehler),
        );
      }
    }
    return ReisewegeAbruf(geholt: geholt);
  }
}

/// Meldung zu einem gescheiterten Abruf, mit Wartezeit, wenn bekannt.
String reisewegFehlerText(AvesmapsFehler fehler) {
  final warte = fehler.wartezeit;
  if (warte == null) return fehler.meldung;
  final sekunden = warte.inSeconds;
  final dauer = sekunden < 90
      ? '${sekunden < 1 ? 1 : sekunden} Sekunden'
      : '${(sekunden / 60).ceil()} Minuten';
  return '${fehler.meldung} Bitte in etwa $dauer erneut versuchen.';
}

/// Die gemerkten Reisewege von Avesmaps (siehe [AvesmapsReisewege]).
final avesmapsReisewegeProvider =
    AsyncNotifierProvider<AvesmapsReisewege, Map<String, AvesmapsRoute>>(
      AvesmapsReisewege.new,
    );
