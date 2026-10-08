// Aurapanzer für Vertraute (WdZ S. 125).
//
// Vertraute können die Sonderfertigkeit Aurapanzer für 125 AP erwerben, wenn
// ihre Astralenergie mindestens 20 beträgt. Das ist ein eigener Preis: der
// Katalogeintrag `magsf_aurapanzer` kostet 500 AP für Helden. Die AP zahlt der
// Vertraute aus seinem eigenen Vorrat; eine unerfüllte Voraussetzung geht nur
// per Meisterentscheid.

import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_wirkwert_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/companion_steigerung_rules.dart';

/// Kosten des Aurapanzers für einen Vertrauten in AP.
const int kVertrautenAurapanzerKosten = 125;

/// Mindest-Astralenergie für den Aurapanzer des Vertrauten.
const int kVertrautenAurapanzerMindestAsp = 20;

/// Katalog-ID des Aurapanzers (Helden-Preis 500 AP, hier 125 AP).
const String kAurapanzerKatalogId = 'magsf_aurapanzer';

/// Name der Sonderfertigkeit am Begleiter.
const String kAurapanzerName = 'Aurapanzer';

/// Hat [c] den Aurapanzer schon?
bool vertrautenHatAurapanzer(HeroCompanion c) => c.sonderfertigkeiten.any(
  (sf) =>
      sf.katalogId == kAurapanzerKatalogId ||
      sf.name.trim().toLowerCase() == kAurapanzerName.toLowerCase(),
);

/// Grund, warum der Aurapanzer für [c] gesperrt ist; `null` wenn er passt.
///
/// Gesperrt ist er nur für Nicht-Vertraute und bei schon erworbenem
/// Aurapanzer. Fehlende AE oder AP sind Voraussetzungen, die der
/// Meisterentscheid übergeht, siehe [vertrautenAurapanzerVoraussetzungen].
String? vertrautenAurapanzerSperrgrund(HeroCompanion c) {
  if (c.typ != BegleiterTyp.vertrauter) {
    return 'Nur für Vertraute (WdZ S. 125).';
  }
  if (vertrautenHatAurapanzer(c)) return 'Aurapanzer bereits erworben.';
  return null;
}

/// Nicht erfüllte Voraussetzungen des Aurapanzers; leer, wenn alles passt.
List<String> vertrautenAurapanzerVoraussetzungen(HeroCompanion c) {
  final asp = begleiterWirksamerPoolwert(c, 'asp') ?? 0;
  final frei = companionApVerfuegbar(c);
  return <String>[
    if (asp < kVertrautenAurapanzerMindestAsp)
      'AE $asp, nötig sind $kVertrautenAurapanzerMindestAsp.',
    if (frei < kVertrautenAurapanzerKosten)
      'Der Vertraute hat nur $frei AP frei, nötig sind '
          '$kVertrautenAurapanzerKosten AP.',
  ];
}

/// Bucht den Aurapanzer für [kVertrautenAurapanzerKosten] AP des Vertrauten.
///
/// [erwarteteApAusgegeben] ist der Stand, den der Dialog gesehen hat; eine
/// inzwischen geänderte Buchung bricht ab. Unerfüllte Voraussetzungen gehen nur
/// mit [meisterentscheid].
HeroSheet bucheVertrautenAurapanzer(
  HeroSheet held, {
  required String begleiterId,
  required int erwarteteApAusgegeben,
  bool meisterentscheid = false,
}) {
  return ersetzeBegleiter(held, begleiterId, (gespeichert) {
    if ((gespeichert.apAusgegeben ?? 0) != erwarteteApAusgegeben) {
      throw StateError(
        'Die AP des Vertrauten wurden inzwischen geändert. '
        'Bitte erneut öffnen.',
      );
    }
    final sperre = vertrautenAurapanzerSperrgrund(gespeichert);
    if (sperre != null) throw StateError(sperre);
    final offen = vertrautenAurapanzerVoraussetzungen(gespeichert);
    if (offen.isNotEmpty && !meisterentscheid) throw StateError(offen.first);
    return gespeichert.copyWith(
      apAusgegeben:
          (gespeichert.apAusgegeben ?? 0) + kVertrautenAurapanzerKosten,
      sonderfertigkeiten: <HeroCompanionSonderfertigkeit>[
        ...gespeichert.sonderfertigkeiten,
        const HeroCompanionSonderfertigkeit(
          name: kAurapanzerName,
          beschreibung: 'Vertrauten-Aurapanzer (WdZ S. 125), 125 AP',
          katalogId: kAurapanzerKatalogId,
        ),
      ],
    );
  });
}
