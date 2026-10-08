// Vertrautenzauber lernen und Tierausbildung buchen (WdZ S. 124–128,
// ZBA S. 19–21).
//
// Beides zahlt der Vertraute aus seinen eigenen AP. Die Ausbildung wirkt nur
// abgeleitet über [vertrautenAusbildungsModifikationen]; Grundwerte bleiben
// unverändert, damit die Steigerungsgrenzen am Startwert hängen bleiben.

import 'package:dsa_heldenverwaltung/catalog/vertrauten_katalog.dart';
import 'package:dsa_heldenverwaltung/catalog/vertrautenmagie_preset.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/companion_steigerung_rules.dart';

/// Ob der Vertraute den Zauber [zauber] lernen darf, mit Grund.
class VertrautenZauberZugang {
  /// Erstellt das Ergebnis.
  const VertrautenZauberZugang({
    required this.zauber,
    required this.lernkosten,
    this.sperrgrund,
    this.bekannt = false,
  });

  /// Zugangsdaten des Zaubers.
  final VertrautenZauberDef zauber;

  /// Lernkosten für diesen Vertrauten (halbiert für Machtvolle, wo erlaubt).
  final int lernkosten;

  /// Warum der Zauber nicht regulär lernbar ist; `null`, wenn er es ist.
  final String? sperrgrund;

  /// Der Vertraute beherrscht den Zauber schon.
  final bool bekannt;

  /// Regulär lernbar.
  bool get lernbar => sperrgrund == null && !bekannt;
}

/// Zugang aller Vertrautenzauber für [c], in Katalogreihenfolge.
///
/// Ohne Bindung (Bestandsvertraute) ist die Art unbekannt; artgebundene
/// Zauber tragen dann einen Sperrgrund, der sich per Meisterentscheid
/// übergehen lässt.
List<VertrautenZauberZugang> vertrautenZauberZugaenge(HeroCompanion c) {
  final bindung = c.vertrautenBindung;
  final machtvoll = bindung?.machtvoll ?? false;
  final artId = bindung?.artId ?? '';
  final bekannt = <String>{
    for (final kategorie in c.ritualCategories)
      if (kategorie.id == kVertrautenmagieKategorieId)
        for (final ritual in kategorie.rituals) ritual.name,
  };
  return <VertrautenZauberZugang>[
    for (final zauber in kVertrautenZauber)
      VertrautenZauberZugang(
        zauber: zauber,
        lernkosten: machtvoll && zauber.halbFuerMachtvoll
            ? zauber.lernkosten ~/ 2
            : zauber.lernkosten,
        bekannt: bekannt.contains(zauber.name),
        sperrgrund: _zauberSperrgrund(zauber, artId, machtvoll),
      ),
  ];
}

String? _zauberSperrgrund(VertrautenZauberDef z, String artId, bool mv) {
  if (z.nurMachtvoll && !mv) return 'Nur für Machtvolle Vertraute.';
  if (z.tierartIds.isNotEmpty && !z.tierartIds.contains(artId)) {
    final arten = z.tierartIds
        .map((id) => vertrautenArt(id)?.name ?? id)
        .join(', ');
    return 'Nur für $arten.';
  }
  return null;
}

/// Lernt den Vertrautenzauber [ritualName] für [apKosten] AP des Vertrauten.
///
/// Das Ritual kommt aus dem Preset in die Vertrautenmagie des Begleiters.
/// Wirft einen [StateError], wenn der Zauber schon bekannt ist, die
/// Vertrautenmagie fehlt oder der Vertraute zu wenig freie AP hat.
HeroSheet lerneVertrautenZauber(
  HeroSheet held, {
  required String begleiterId,
  required String ritualName,
  required int apKosten,
}) {
  final ritual = kVertrautenmagiePresetCategory.rituals
      .where((r) => r.name == ritualName)
      .firstOrNull;
  if (ritual == null) throw StateError('Unbekannter Vertrautenzauber.');
  final migriert = mitVertrautenmagieAmBegleiter(held);
  return ersetzeBegleiter(migriert, begleiterId, (gespeichert) {
    final index = gespeichert.ritualCategories.indexWhere(
      (k) => k.id == kVertrautenmagieKategorieId,
    );
    if (index < 0) {
      throw StateError('Der Vertraute hat noch keine Vertrautenmagie.');
    }
    final kategorie = gespeichert.ritualCategories[index];
    if (kategorie.rituals.any((r) => r.name == ritualName)) {
      throw StateError('Der Vertraute beherrscht $ritualName inzwischen.');
    }
    _pruefeApDesVertrauten(gespeichert, apKosten);
    final kategorien = List<HeroRitualCategory>.of(gespeichert.ritualCategories)
      ..[index] = kategorie.copyWith(
        rituals: <HeroRitualEntry>[...kategorie.rituals, ritual],
      );
    return gespeichert.copyWith(
      ritualCategories: kategorien,
      apAusgegeben: (gespeichert.apAusgegeben ?? 0) + apKosten,
    );
  });
}

/// Warum die Ausbildung [katalogId] für [c] nicht regulär buchbar ist;
/// `null`, wenn sie es ist.
///
/// Gesperrt sind das Kampftier (WdZ S. 124), eine zweite Ausbildungsstufe
/// außer beim Hund (ZBA S. 20), bereits gelernte Fertigkeiten, fehlende
/// Voraussetzungen und mehr Tricks als KL.
String? vertrautenAusbildungSperrgrund(HeroCompanion c, String katalogId) {
  final bindung = c.vertrautenBindung;
  if (bindung == null) return 'Der Vertraute ist noch nicht gebunden.';
  final gebucht = bindung.ausbildungen.map((a) => a.katalogId).toList();
  final stufe = vertrautenAusbildung(katalogId);
  if (stufe != null) {
    if (!stufe.fuerVertraute) {
      return '${stufe.name}: für Vertraute nicht wählbar (WdZ S. 124).';
    }
    if (gebucht.contains(katalogId)) return '${stufe.name} ist schon gebucht.';
    final stufen = gebucht.where((id) => vertrautenAusbildung(id) != null);
    final maxStufen = bindung.artId == 'vart_hund' ? 2 : 1;
    if (stufen.length >= maxStufen) {
      return 'Nur ${maxStufen == 1 ? 'eine Ausbildungsstufe' : 'zwei Ausbildungsstufen'} '
          '(ZBA S. 20).';
    }
    return null;
  }
  final fertigkeit = vertrautenFertigkeit(katalogId);
  if (fertigkeit == null) return 'Unbekannte Ausbildung.';
  final anzahl = gebucht.where((id) => id == katalogId).length;
  if (!fertigkeit.mehrfach && anzahl > 0) {
    return '${fertigkeit.name} ist schon gelernt.';
  }
  final voraussetzung = fertigkeit.voraussetzungId;
  if (voraussetzung.isNotEmpty && !gebucht.contains(voraussetzung)) {
    return 'Setzt ${vertrautenFertigkeit(voraussetzung)?.name ?? voraussetzung} '
        'voraus.';
  }
  if (fertigkeit.mehrfach) {
    final kl = companionEffektivwert(c, 'kl') ?? 0;
    if (anzahl >= kl) return 'Höchstens KL ($kl) Tricks (ZBA S. 21).';
  }
  return null;
}

/// Bucht die Ausbildung [katalogId] für [apKosten] AP des Vertrauten.
///
/// [erwarteteAnzahl] ist die Zahl der gebuchten Ausbildungen, die der Dialog
/// gesehen hat. Gesperrte Ausbildungen gehen nur mit [meisterentscheid];
/// das Kampftier nie.
HeroSheet bucheVertrautenAusbildung(
  HeroSheet held, {
  required String begleiterId,
  required String katalogId,
  required int apKosten,
  required int erwarteteAnzahl,
  String bezeichnung = '',
  bool meisterentscheid = false,
}) {
  return ersetzeBegleiter(held, begleiterId, (gespeichert) {
    final bindung = gespeichert.vertrautenBindung;
    if (gespeichert.typ != BegleiterTyp.vertrauter || bindung == null) {
      throw StateError('Der Vertraute ist noch nicht gebunden.');
    }
    if (bindung.ausbildungen.length != erwarteteAnzahl) {
      throw StateError(
        'Die Ausbildung wurde inzwischen geändert. Bitte erneut öffnen.',
      );
    }
    final stufe = vertrautenAusbildung(katalogId);
    if (stufe != null && !stufe.fuerVertraute) {
      throw StateError('${stufe.name}: für Vertraute nicht wählbar.');
    }
    final sperrgrund = vertrautenAusbildungSperrgrund(gespeichert, katalogId);
    if (sperrgrund != null && !meisterentscheid) throw StateError(sperrgrund);
    _pruefeApDesVertrauten(gespeichert, apKosten);
    return gespeichert.copyWith(
      apAusgegeben: (gespeichert.apAusgegeben ?? 0) + apKosten,
      vertrautenBindung: bindung.copyWith(
        ausbildungen: <VertrautenAusbildungsbuchung>[
          ...bindung.ausbildungen,
          VertrautenAusbildungsbuchung(
            katalogId: katalogId,
            apKosten: apKosten,
            bezeichnung: bezeichnung.trim(),
          ),
        ],
      ),
    );
  });
}

/// Summe der Wertänderungen aller gebuchten Ausbildungsstufen von [c].
///
/// Fertigkeiten ändern keine Werte.
VertrautenModifikationen vertrautenAusbildungsModifikationen(HeroCompanion c) {
  final bindung = c.vertrautenBindung;
  if (c.typ != BegleiterTyp.vertrauter || bindung == null) {
    return const VertrautenModifikationen();
  }
  final summe = <String, int>{};
  for (final buchung in bindung.ausbildungen) {
    final stufe = vertrautenAusbildung(buchung.katalogId);
    if (stufe == null) continue;
    for (final eintrag in stufe.modifikationen.toJson().entries) {
      summe[eintrag.key] = (summe[eintrag.key] ?? 0) + (eintrag.value as int);
    }
  }
  int w(String key) => summe[key] ?? 0;
  return VertrautenModifikationen(
    mu: w('mu'),
    kl: w('kl'),
    inn: w('inn'),
    ch: w('ch'),
    ff: w('ff'),
    ge: w('ge'),
    ko: w('ko'),
    kk: w('kk'),
    at: w('at'),
    pa: w('pa'),
    tp: w('tp'),
    ini: w('ini'),
    gs: w('gs'),
    lep: w('lep'),
    aup: w('aup'),
  );
}

void _pruefeApDesVertrauten(HeroCompanion c, int apKosten) {
  if (apKosten < 0) throw StateError('Die Kosten dürfen nicht negativ sein.');
  final frei = companionApVerfuegbar(c);
  if (frei < apKosten) {
    throw StateError(
      'Der Vertraute hat nur $frei AP frei, nötig sind $apKosten AP.',
    );
  }
}
