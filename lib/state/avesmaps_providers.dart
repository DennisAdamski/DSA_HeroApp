import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_client.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_orte_repository.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_orte_speicher.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Ob die App Ortsdaten von Avesmaps abrufen darf.
///
/// Ohne Override aus: Tests und Vorschauen stellen so nie eine Netzanfrage.
/// Die App schaltet den Abruf in `AppStartupGate._buildScope` ein.
final avesmapsAktivProvider = Provider<bool>((ref) => false);

/// Client für die Entwickler-API von Avesmaps, oder `null`, solange der Abruf
/// aus ist.
final avesmapsClientProvider = Provider<AvesmapsClient?>((ref) {
  if (!ref.watch(avesmapsAktivProvider)) return null;
  // Im Web setzt der Browser den User-Agent selbst.
  final client = AvesmapsClient(kennung: kIsWeb ? null : kAvesmapsKennung);
  ref.onDispose(client.close);
  return client;
});

/// Hält das Ortsverzeichnis von Avesmaps lokal vor; `null`, solange der Abruf
/// aus ist.
final avesmapsOrteRepositoryProvider = FutureProvider<AvesmapsOrteRepository?>((
  ref,
) async {
  final client = ref.watch(avesmapsClientProvider);
  if (client == null) return null;
  final speicherort = await ref.watch(heroStorageLocationProvider.future);
  return AvesmapsOrteRepository(
    client: client,
    speicher: HiveAvesmapsOrteSpeicher(speicherPfad: speicherort.effectivePath),
  );
});

/// Merkt, ob in dieser Sitzung ein Ortsfeld oder die Reiseroute geöffnet
/// wurde.
///
/// Erst dann lädt [avesmapsOrteProvider]: Die Anfrage an Avesmaps entsteht
/// durch eine Nutzeraktion, nicht schon beim Öffnen der Spielansicht.
class AvesmapsOrteAnforderung extends Notifier<bool> {
  @override
  bool build() => false;

  /// Fordert das Ortsverzeichnis an; wiederholte Aufrufe ändern nichts.
  void fordereAn() {
    if (!state) state = true;
  }
}

/// Ob das Ortsverzeichnis von Avesmaps in dieser Sitzung angefordert ist.
final avesmapsOrteAnforderungProvider =
    NotifierProvider<AvesmapsOrteAnforderung, bool>(
      AvesmapsOrteAnforderung.new,
    );

/// Das Ortsverzeichnis von Avesmaps; leer, solange es nicht angefordert,
/// nicht vorhanden oder nicht abrufbar ist.
///
/// Wirft nicht: Das Verzeichnis ergänzt die Ortsauswahl nur, der Ort bleibt
/// frei eintragbar.
final avesmapsOrteProvider = FutureProvider<List<AvesmapsOrt>>((ref) async {
  if (!ref.watch(avesmapsOrteAnforderungProvider)) {
    return const <AvesmapsOrt>[];
  }
  try {
    final repository = await ref.watch(avesmapsOrteRepositoryProvider.future);
    return (await repository?.ladeOrte())?.orte ?? const <AvesmapsOrt>[];
  } on Object {
    return const <AvesmapsOrt>[];
  }
});

/// Auswahlliste der Orte: das Ortsverzeichnis der Wiki Aventurica, ergänzt
/// um Orte und Kartenpositionen aus Avesmaps, sobald diese vorliegen.
final ortsverzeichnisProvider = Provider<List<OrtEintrag>>((ref) {
  final wiki =
      ref.watch(ortKatalogProvider).asData?.value.orte ?? const <OrtEintrag>[];
  final avesmaps =
      ref.watch(avesmapsOrteProvider).asData?.value ?? const <AvesmapsOrt>[];
  return verbindeOrtsverzeichnisse(wiki, avesmaps);
});

/// Sucht Orte online bei Avesmaps; liefert bei jedem Fehler eine leere Liste.
typedef AvesmapsOnlineSuche = Future<List<AvesmapsOrt>> Function(
  String anfrage,
);

/// Online-Ortssuche als Ersatz, solange das Ortsverzeichnis von Avesmaps
/// angefordert, aber (noch) nicht vorhanden ist; sonst `null`.
///
/// Liegt die Liste lokal vor, sucht die App ohne Netz darin.
final avesmapsOnlineSucheProvider = Provider<AvesmapsOnlineSuche?>((ref) {
  final client = ref.watch(avesmapsClientProvider);
  if (client == null || !ref.watch(avesmapsOrteAnforderungProvider)) {
    return null;
  }
  final liste = ref.watch(avesmapsOrteProvider).asData?.value;
  if (liste != null && liste.isNotEmpty) return null;
  return (anfrage) async {
    try {
      return (await client.suche(anfrage)).treffer;
    } on AvesmapsFehler {
      return const <AvesmapsOrt>[];
    }
  };
});
