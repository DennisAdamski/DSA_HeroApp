// Bindung eines Vertrauten an seine Hexe (WdZ S. 123 f.).
//
// Die Generierung legt Startwerte aus der Tierart fest und rechnet die
// Bindungskosten, die die Hexe als ausgegebene AP zahlt. Bestandsvertraute
// lassen sich ohne Buchung als gebunden erfassen; ihre Werte bleiben dann
// unverändert. Beides schreibt in einer Änderung auf den frisch geladenen
// Helden (ARCH-05).

import 'package:dsa_heldenverwaltung/catalog/vertrauten_katalog.dart';
import 'package:dsa_heldenverwaltung/catalog/vertrautenmagie_preset.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart' show ArmorPiece;
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ap_level_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_aenderung_rules.dart';

/// Eingaben der Vertrauten-Generierung (WdZ S. 123).
class VertrautenGenerierung {
  /// Erstellt die Eingaben.
  const VertrautenGenerierung({
    required this.artId,
    this.machtvoll = false,
    this.punkte = const <String, int>{},
    this.zusatzAsp = 0,
    this.zusatzLep = 0,
    this.zusatzAup = 0,
  });

  /// Vertrautenart (`vart_…`).
  final String artId;

  /// Machtvoller Vertrauter: Bindung 120 AP, freie Werte.
  final bool machtvoll;

  /// Verteilte Punkte je Eigenschaft (`mu` … `kk`) über dem Startwert.
  final Map<String, int> punkte;

  /// Zusätzliche AsP über dem Tabellenwert.
  final int zusatzAsp;

  /// Zusätzliche LeP über dem Tabellenwert.
  final int zusatzLep;

  /// Zusätzliche AuP über dem Tabellenwert.
  final int zusatzAup;

  /// Summe der verteilten Eigenschaftspunkte.
  int get punkteSumme =>
      punkte.values.fold(0, (summe, wert) => summe + (wert > 0 ? wert : 0));
}

/// Einzelposten der Bindungskosten, in Anzeigereihenfolge.
class VertrautenBindungskosten {
  /// Erstellt die Aufstellung.
  const VertrautenBindungskosten({
    required this.grundkosten,
    required this.punkte,
    required this.ueberMaximum,
    required this.zusatzpunkte,
  });

  /// Grundkosten der Art bzw. 120 AP für Machtvolle.
  final int grundkosten;

  /// 2 AP je verteiltem Eigenschaftspunkt.
  final int punkte;

  /// 5 AP je Punkt über dem Tabellenmaximum (nur Machtvolle).
  final int ueberMaximum;

  /// Zusätzliche AsP, LeP (je 5 AP) und AuP (je 2 AP).
  final int zusatzpunkte;

  /// Gesamtkosten der Bindung.
  int get summe => grundkosten + punkte + ueberMaximum + zusatzpunkte;
}

/// Rechnet die Bindungskosten für [g] (WdZ S. 123 f.).
///
/// Unbekannte Arten kosten als Machtvoller 120 AP, sonst 80 AP.
VertrautenBindungskosten vertrautenBindungskosten(VertrautenGenerierung g) {
  final art = vertrautenArt(g.artId);
  var ueberMaximum = 0;
  if (g.machtvoll && art != null) {
    for (final eintrag in g.punkte.entries) {
      final spanne = art.eigenschaften[eintrag.key];
      if (spanne == null) continue;
      final wert = spanne.start + eintrag.value;
      if (wert > spanne.max) ueberMaximum += wert - spanne.max;
    }
  }
  return VertrautenBindungskosten(
    grundkosten: g.machtvoll
        ? kVertrautenBindungskostenMachtvoll
        : art?.bindungskosten ?? 80,
    punkte: g.punkteSumme * kVertrautenApJeGenerierungspunkt,
    ueberMaximum: ueberMaximum * kVertrautenApJePunktUeberMaximum,
    zusatzpunkte:
        (g.zusatzAsp + g.zusatzLep) * kVertrautenApJeZusatzAspLep +
        g.zusatzAup * kVertrautenApJeZusatzAup,
  );
}

/// Verstöße der Generierung [g] gegen WdZ S. 123; leer, wenn sie passt.
///
/// Machtvolle Vertraute haben freie Werte (Nutzerentscheidung): geprüft wird
/// nur, dass keine Angabe negativ ist.
List<String> vertrautenGenerierungsFehler(VertrautenGenerierung g) {
  final fehler = <String>[];
  final art = vertrautenArt(g.artId);
  if (art == null) {
    fehler.add('Unbekannte Vertrautenart.');
    return fehler;
  }
  final negativ =
      g.punkte.values.any((p) => p < 0) ||
      g.zusatzAsp < 0 ||
      g.zusatzLep < 0 ||
      g.zusatzAup < 0;
  if (negativ) fehler.add('Punkte dürfen nicht negativ sein.');
  if (g.machtvoll) return fehler;
  if (g.punkteSumme > kVertrautenGenerierungspunkte) {
    fehler.add(
      'Höchstens $kVertrautenGenerierungspunkte Punkte verteilen '
      '(verteilt: ${g.punkteSumme}).',
    );
  }
  for (final eintrag in g.punkte.entries) {
    final spanne = art.eigenschaften[eintrag.key];
    if (spanne != null && spanne.start + eintrag.value > spanne.max) {
      fehler.add(
        '${eintrag.key.toUpperCase()} höchstens ${spanne.max} '
        '(Tabellenmaximum).',
      );
    }
  }
  for (final (label, wert) in <(String, int)>[
    ('AsP', g.zusatzAsp),
    ('LeP', g.zusatzLep),
    ('AuP', g.zusatzAup),
  ]) {
    if (wert > kVertrautenZusatzpunkteMax) {
      fehler.add('Höchstens +$kVertrautenZusatzpunkteMax $label.');
    }
  }
  return fehler;
}

/// Liefert [c] mit den Startwerten aus der Generierung [g].
///
/// Setzt Eigenschaften, INI, MR, LeP/AsP/AuP samt Startwerten, Loyalität 15,
/// Angriffe (DK H), Geschwindigkeiten, natürlichen Rüstungsschutz und die
/// Vertrautenmagie mit RK 3 und den Zaubern, die mit der Bindung kommen.
/// Gekaufte Steigerungen bleiben stehen.
HeroCompanion vertrautenMitStartwerten(
  HeroCompanion c,
  VertrautenGenerierung g, {
  required int? bindungskosten,
}) {
  final art = vertrautenArt(g.artId);
  if (art == null) {
    throw StateError('Unbekannte Vertrautenart.');
  }
  int wert(String key) => art.eigenschaften[key]!.start + (g.punkte[key] ?? 0);
  final lep = art.lep + g.zusatzLep;
  final asp = art.asp + g.zusatzAsp;
  final aup = art.aup + g.zusatzAup;
  return c.copyWith(
    gattung: c.gattung.trim().isEmpty ? art.name : c.gattung,
    mu: wert('mu'),
    kl: wert('kl'),
    inn: wert('inn'),
    ch: wert('ch'),
    ff: wert('ff'),
    ge: wert('ge'),
    ko: wert('ko'),
    kk: wert('kk'),
    ini: art.iniBasis,
    magieresistenz: art.mr,
    startMr: art.mr,
    loyalitaet: kVertrautenStartLoyalitaet,
    maxLep: lep,
    startLep: lep,
    maxAsp: asp,
    startAsp: asp,
    maxAup: aup,
    startAup: aup,
    angriffe: <HeroCompanionAttack>[
      for (var i = 0; i < art.angriffe.length; i++)
        HeroCompanionAttack(
          id: '${c.id}-${art.id}-angriff-$i',
          name: art.angriffe[i].name,
          dk: 'H',
          at: art.angriffe[i].at,
          pa: art.angriffe[i].pa,
          tp: art.angriffe[i].tp,
        ),
    ],
    geschwindigkeiten: <HeroCompanionSpeed>[
      for (final tempo in art.geschwindigkeiten)
        HeroCompanionSpeed(art: tempo.art, wert: tempo.wert),
    ],
    ruestungsTeile: c.ruestungsTeile.isEmpty && art.rs > 0
        ? <ArmorPiece>[
            ArmorPiece(
              id: '${c.id}-natuerlicher-schutz',
              name: 'Natürlicher Schutz',
              isActive: true,
              rs: art.rs,
            ),
          ]
        : null,
    ritualCategories: <HeroRitualCategory>[
      ...c.ritualCategories.where((k) => k.id != kVertrautenmagieKategorieId),
      _vertrautenmagieMitBindung(c, art.id),
    ],
    vertrautenBindung: (c.vertrautenBindung ?? const VertrautenBindung())
        .copyWith(
          artId: art.id,
          machtvoll: g.machtvoll,
          bindungskosten: bindungskosten,
          ohneBindungskosten: bindungskosten == null,
        ),
  );
}

// Vertrautenmagie mit RK 3 und den Zaubern, die mit der Bindung kommen; eine
// vorhandene Kategorie behält ihre Rituale und ergänzt nur die fehlenden.
HeroRitualCategory _vertrautenmagieMitBindung(HeroCompanion c, String artId) {
  final vorhanden = c.ritualCategories
      .where((k) => k.id == kVertrautenmagieKategorieId)
      .firstOrNull;
  final basis =
      vorhanden ??
      kVertrautenmagiePresetCategory.copyWith(rituals: <HeroRitualEntry>[]);
  final namen = basis.rituals.map((r) => r.name).toSet();
  final neu = <HeroRitualEntry>[
    for (final ritual in kVertrautenmagiePresetCategory.rituals)
      if (!namen.contains(ritual.name) &&
          _kommtMitBindung(vertrautenZauber(ritual.name), artId))
        ritual,
  ];
  return basis.copyWith(rituals: <HeroRitualEntry>[...basis.rituals, ...neu]);
}

bool _kommtMitBindung(VertrautenZauberDef? zauber, String artId) =>
    zauber != null &&
    zauber.mitBindung &&
    (zauber.tierartIds.isEmpty || zauber.tierartIds.contains(artId));

/// Freie AP des Helden (gesamt minus ausgegeben).
int heldFreieAp(HeroSheet held) => held.apTotal - held.apSpent;

/// Bindet den Vertrauten [begleiterId] nach [g] und bucht die Kosten als
/// ausgegebene AP der Hexe.
///
/// Wirft einen [StateError], wenn der Begleiter kein Vertrauter oder schon
/// gebunden ist, die Generierung nicht passt oder die Hexe zu wenig freie AP
/// hat.
HeroSheet bucheVertrautenBindung(
  HeroSheet held, {
  required String begleiterId,
  required VertrautenGenerierung generierung,
}) {
  final fehler = vertrautenGenerierungsFehler(generierung);
  if (fehler.isNotEmpty) throw StateError(fehler.first);
  final kosten = vertrautenBindungskosten(generierung).summe;
  if (heldFreieAp(held) < kosten) {
    throw StateError(
      'Die Bindung kostet $kosten AP, frei sind ${heldFreieAp(held)} AP.',
    );
  }
  final migriert = mitVertrautenmagieAmBegleiter(held);
  final gebunden = ersetzeBegleiter(migriert, begleiterId, (gespeichert) {
    _pruefeUngebundenenVertrauten(gespeichert);
    return vertrautenMitStartwerten(
      gespeichert,
      generierung,
      bindungskosten: kosten,
    );
  });
  return mitApSchritt(gebunden, ApKonto.ausgegeben, kosten);
}

/// Erfasst eine bestehende Bindung ohne AP-Buchung (Bestandsvertraute).
///
/// Ändert keinen Wert des Begleiters; nur Art und Machtvoll werden
/// festgehalten.
HeroSheet erfasseVertrautenBindung(
  HeroSheet held, {
  required String begleiterId,
  required String artId,
  required bool machtvoll,
}) {
  return ersetzeBegleiter(held, begleiterId, (gespeichert) {
    _pruefeUngebundenenVertrauten(gespeichert);
    return gespeichert.copyWith(
      vertrautenBindung: VertrautenBindung(artId: artId, machtvoll: machtvoll),
    );
  });
}

void _pruefeUngebundenenVertrauten(HeroCompanion c) {
  if (c.typ != BegleiterTyp.vertrauter) {
    throw StateError('Nur Vertraute lassen sich binden.');
  }
  if (c.vertrautenBindung != null) {
    throw StateError('Der Vertraute ist inzwischen schon gebunden.');
  }
}
