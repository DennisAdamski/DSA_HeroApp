// Last und Tragkraft des Helden (SPIEL-02, Block „Dabei“).
//
// Quelle: Wege des Schwerts S. 144 („Last und Tragkraft“). Die Tragkraft (TK)
// in Stein entspricht der Körperkraft; 1 Stein sind 1 kg (Geographia
// Aventurica S. 140). Die Last ist das Gewicht von Ausrüstung, Waffen, Geld,
// Tränken und Artefakten, die der Held trägt, plus die **Hälfte** des Gewichts
// von Kleidung und Rüstung, die am Leib getragen werden.
//
// Pro angefangenen 50 % Last über der TK steigt die BE um einen Punkt (Kampf,
// Talentproben, taktische Bewegung). Über der doppelten TK braucht der Held
// Verschnaufpausen (alle KO Spielrunden eine Spielrunde), ab der vierfachen
// TK muss er die Last in Abständen von 5 × KO Schritt absetzen.
//
// Eingerechnet werden nur **dauerhafte** Quellen: die Körperkraft ohne
// laufende Zauber (`HeroStatInputs.permanent`), die epische KK-Haupteigenschaft
// (Hausregel „Epische Stufen“ Kap. 2.1, KK × 1,5) und die Tragkraftquellen des
// Helden (`HeroSheet.tragkraftBoni`, etwa eine Bärenrune). Kurzzeitzauber
// zählen hier nicht. Die Funktionen liefern Zahlen und Herleitungen; die
// Oberfläche rechnet nichts nach.

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_tragkraft_bonus.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_main_attribute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_summen_rules.dart';

/// Gramm je Stein (1 Stein = 1 kg).
const int kGrammJeStein = 1000;

/// Gewicht eines Dukaten in Gramm: eine Unze Gold (Geographia Aventurica
/// S. 141).
const int kDukatGramm = 25;

/// Gewicht von Silbertaler, Heller und Kreuzer in Gramm: je 5 Skrupel
/// (Geographia Aventurica S. 141).
const int kKleinmuenzeGramm = 5;

/// Tragkraft, die eine Bärenrune je RkP* hinzufügt (Wege der Alchimie S. 161).
const int kBaerenruneSteinJeRkp = 10;

/// Wie stark die Last den Helden beeinträchtigt (WdS S. 144).
enum TragkraftStufe {
  /// Höchstens die Tragkraft: keine Folgen.
  frei,

  /// Über der Tragkraft: BE steigt, im Marsch kommt Erschöpfung dazu.
  belastet,

  /// Über der doppelten Tragkraft: Verschnaufpausen, kein Sprint.
  verschnaufen,

  /// Ab der vierfachen Tragkraft: Last absetzen, weder Sprint noch Dauerlauf.
  absetzen,
}

/// Ergebnis von [berechneTragkraft].
class TragkraftErgebnis {
  /// Erstellt das Ergebnis; [tragkraft] ist die Herleitung in Stein.
  const TragkraftErgebnis({
    required this.lastGramm,
    required this.geldGramm,
    required this.amLeibGramm,
    required this.ohneGewicht,
    required this.tragkraft,
    required this.konstitution,
  });

  /// Gesamtlast in Gramm: Gepäck, Waffen, Geld und die Hälfte der Kleidung
  /// und Rüstung am Leib.
  final int lastGramm;

  /// Davon das Gewicht des Geldes in Gramm (kleinstmögliche Münzzahl).
  final int geldGramm;

  /// Volles Gewicht von Kleidung und Rüstung am Leib in Gramm; angerechnet
  /// wird davon nur die Hälfte.
  final int amLeibGramm;

  /// Anzahl getragener Einträge ohne Gewicht; die Last ist dann ein
  /// Mindestwert.
  final int ohneGewicht;

  /// Herleitung der Tragkraft in Stein.
  final Herleitung tragkraft;

  /// Konstitution des Helden für die Hinweise zu Pausen und Absetzen.
  final int konstitution;

  /// Tragkraft in Stein.
  int get tragkraftStein => tragkraft.wert;

  /// Tragkraft in Gramm.
  int get tragkraftGramm => tragkraftStein * kGrammJeStein;

  /// Last über der Tragkraft in Gramm; 0, solange sie nicht überschritten ist.
  int get ueberschussGramm {
    final ueber = lastGramm - tragkraftGramm;
    return ueber > 0 ? ueber : 0;
  }

  /// Zusätzliche BE: ein Punkt je angefangene 50 % Last über der Tragkraft.
  int get zusatzBe {
    final ueber = ueberschussGramm;
    if (ueber == 0) return 0;
    final halbe = tragkraftGramm <= 0 ? 1 : tragkraftGramm;
    // Aufrunden von ueber / (halbe / 2) ohne Gleitkomma.
    return (ueber * 2 + halbe - 1) ~/ halbe;
  }

  /// Einordnung der Last.
  TragkraftStufe get stufe {
    final tk = tragkraftGramm;
    if (tk > 0 && lastGramm >= tk * 4) return TragkraftStufe.absetzen;
    if (tk > 0 && lastGramm > tk * 2) return TragkraftStufe.verschnaufen;
    if (lastGramm > tk) return TragkraftStufe.belastet;
    return TragkraftStufe.frei;
  }

  /// Kurzer Satz zur Folge der Last; `null`, solange sie nicht überschritten
  /// ist.
  String? get hinweis => switch (stufe) {
    TragkraftStufe.frei => null,
    TragkraftStufe.belastet =>
      'BE +$zusatzBe (Kampf, Talente, taktische Bewegung); im Marsch '
          '1 Punkt Erschöpfung mehr je Stunde.',
    TragkraftStufe.verschnaufen =>
      'BE +$zusatzBe; alle $konstitution Spielrunden eine Spielrunde '
          'rasten, kein Sprint.',
    TragkraftStufe.absetzen =>
      'BE +$zusatzBe; Last alle ${konstitution * 5} Schritt absetzen und '
          'eine Minute verschnaufen, weder Sprint noch Dauerlauf.',
  };
}

/// Ob [e] als Kleidung oder Rüstung am Leib zählt (halbes Gewicht).
///
/// Das sind die angelegten Rüstungsteile des Kampfbereichs und manuell
/// geführte, ausgerüstete Ausrüstungsstücke. Waffen in der Hand, Nebenhand-
/// gegenstände und alles im Gepäck zählen voll („ein auf den Rucksack
/// geschnalltes Kettenhemd zählt mit seinem vollen Gewicht“).
bool istAmLeibGetragen(HeroInventoryEntry e) {
  if (!e.istAusgeruestet) return false;
  return switch (e.source) {
    InventoryItemSource.ruestung => true,
    InventoryItemSource.manuell => e.itemType == InventoryItemType.ausruestung,
    _ => false,
  };
}

/// Gewicht des Geldes [dukaten] in Gramm bei kleinstmöglicher Münzzahl.
///
/// Dukat 25 g, Silbertaler, Heller und Kreuzer je 5 g. 0 bei nicht lesbarem
/// Geldstand.
int geldGewichtGramm(String dukaten) {
  final kreuzer = parseDsaCurrencyToKreuzer(dukaten);
  if (kreuzer == null || kreuzer <= 0) return 0;
  var rest = kreuzer;
  final goldstuecke = rest ~/ dsaKreuzerPerDukat;
  rest -= goldstuecke * dsaKreuzerPerDukat;
  final silber = rest ~/ dsaKreuzerPerSilber;
  rest -= silber * dsaKreuzerPerSilber;
  final heller = rest ~/ dsaKreuzerPerHeller;
  rest -= heller * dsaKreuzerPerHeller;
  return goldstuecke * kDukatGramm +
      (silber + heller + rest) * kKleinmuenzeGramm;
}

/// Herleitung der Tragkraft in Stein.
///
/// [kk] ist die Körperkraft ohne laufende Zauber. Die Quellen mit KK-Anteil
/// ([quellen]) erhöhen die Basis vor der epischen Vervielfachung (KK × 1,5,
/// aufgerundet), die Stein-Anteile kommen danach dazu.
Herleitung herleiteTragkraft({
  required int kk,
  required List<HeroTragkraftBonus> quellen,
  required bool epischeKk,
}) {
  final schritte = <HerleitungsSchritt>[
    HerleitungsSchritt(
      bezeichnung: 'Körperkraft',
      betrag: kk,
      art: HerleitungsArt.grundwert,
      formel: 'TK = KK $kk',
      quelle: 'WdS S. 144',
    ),
  ];
  var basis = kk;
  for (final quelle in quellen) {
    if (quelle.kk == 0) continue;
    basis += quelle.kk;
    schritte.add(
      HerleitungsSchritt(
        bezeichnung: quelle.anzeigeName,
        betrag: quelle.kk,
        art: HerleitungsArt.modifikator,
        quelle: 'KK ${quelle.kk > 0 ? '+' : ''}${quelle.kk} für die Tragkraft',
      ),
    );
  }
  if (epischeKk && basis > 0) {
    // „Die Tragkraftgrenzenbasis ist KK*1,5 statt KK“, aufgerundet.
    final vervielfacht = (basis * 3 + 1) ~/ 2;
    schritte.add(
      HerleitungsSchritt(
        bezeichnung: 'Epische Haupteigenschaft KK',
        betrag: vervielfacht - basis,
        art: HerleitungsArt.sonderfertigkeit,
        formel: 'KK $basis × 1,5 = $vervielfacht',
        quelle: 'Epische Stufen Kap. 2.1',
      ),
    );
  }
  for (final quelle in quellen) {
    if (quelle.stein == 0) continue;
    schritte.add(
      HerleitungsSchritt(
        bezeichnung: quelle.anzeigeName,
        betrag: quelle.stein,
        art: HerleitungsArt.modifikator,
        quelle: '+${quelle.stein} Stein',
      ),
    );
  }
  return Herleitung(
    bezeichnung: 'Tragkraft',
    schritte: mitUntergrenze(
      schritte,
      untergrenze: 0,
      bezeichnung: 'Nicht unter 0',
    ),
  );
}

/// Berechnet Last und Tragkraft des Helden [hero].
///
/// [permanent] sind die Eigenschaften ohne laufende Zauber
/// (`HeroStatInputs.permanent`); [epicAdvantagesActive] ist der Schalter der
/// epischen Vorteile, den auch die übrigen Epikregeln lesen.
TragkraftErgebnis berechneTragkraft({
  required HeroSheet hero,
  required Attributes permanent,
  required bool epicAdvantagesActive,
}) {
  var voll = 0;
  var amLeib = 0;
  var ohneGewicht = 0;
  for (final e in hero.inventoryEntries) {
    // Was ein Begleiter trägt, belastet den Helden nicht.
    if (e.traegerTyp != InventoryTraeger.held) continue;
    if (inventarStueckzahlFuerSummen(e) <= 0) continue;
    final gramm = inventarStapelGewichtGramm(e);
    if (e.gewichtGramm <= 0) ohneGewicht++;
    if (istAmLeibGetragen(e)) {
      amLeib += gramm;
    } else {
      voll += gramm;
    }
  }
  final geld = geldGewichtGramm(hero.dukaten);
  return TragkraftErgebnis(
    lastGramm: voll + amLeib ~/ 2 + geld,
    geldGramm: geld,
    amLeibGramm: amLeib,
    ohneGewicht: ohneGewicht,
    tragkraft: herleiteTragkraft(
      kk: permanent.kk,
      quellen: hero.tragkraftBoni,
      epischeKk:
          epicTragkraftMultiplier(
            ruleActive: epicAdvantagesActive,
            isEpisch: hero.isEpisch,
            mainAttributes: hero.epicMainAttributes,
          ) >
          1,
    ),
    konstitution: permanent.ko,
  );
}

/// Die Bärenrune mit [rkp] RkP*: Tragkraft + RkP* × 10 Stein (Wege der
/// Alchimie S. 161). [hausregelKk] fügt die Hausregel „KK +1“ („Erweiterung
/// und Überarbeitung des Regelwerks“ Kap. 10) für die Tragkraft hinzu.
HeroTragkraftBonus baerenruneBonus({
  required String id,
  required int rkp,
  bool hausregelKk = false,
}) {
  final punkte = rkp < 0 ? 0 : rkp;
  return HeroTragkraftBonus(
    id: id,
    name: 'Bärenrune (RkP* $punkte)',
    stein: punkte * kBaerenruneSteinJeRkp,
    kk: hausregelKk ? 1 : 0,
  );
}

/// Legt [bonus] an oder ersetzt die Quelle mit derselben ID.
///
/// Ändert nur `tragkraftBoni`; alles andere bleibt, wie es gespeichert ist.
HeroSheet mitTragkraftBonus(HeroSheet held, HeroTragkraftBonus bonus) {
  final liste = List<HeroTragkraftBonus>.of(held.tragkraftBoni);
  final index = liste.indexWhere((b) => b.id == bonus.id);
  if (index < 0) {
    liste.add(bonus);
  } else {
    liste[index] = bonus.copyWith(
      unbekannteFelder: liste[index].unbekannteFelder,
    );
  }
  return held.copyWith(
    tragkraftBoni: List<HeroTragkraftBonus>.unmodifiable(liste),
  );
}

/// Entfernt die Quelle [id]. Gibt es sie nicht mehr, kommt der Held selbst
/// zurück, damit nichts gespeichert wird.
HeroSheet ohneTragkraftBonus(HeroSheet held, String id) {
  if (!held.tragkraftBoni.any((b) => b.id == id)) return held;
  return held.copyWith(
    tragkraftBoni: List<HeroTragkraftBonus>.unmodifiable(
      held.tragkraftBoni.where((b) => b.id != id),
    ),
  );
}

/// Die Herleitung der Tragkraft als eine Zeile: `13 (Körperkraft) + 70
/// (Bärenrune (RkP* 7))`. Schritte ohne Beitrag entfallen.
String tragkraftFormel(Herleitung herleitung) {
  final teile = StringBuffer();
  for (final schritt in herleitung.sichtbareSchritte) {
    final betrag = schritt.betrag;
    if (teile.isEmpty) {
      teile.write('$betrag (${schritt.bezeichnung})');
    } else {
      teile.write(
        ' ${betrag < 0 ? '−' : '+'} ${betrag.abs()} (${schritt.bezeichnung})',
      );
    }
  }
  return teile.toString();
}

/// Gewicht in Stein als Anzeigetext mit Dezimalkomma: „23,5“ oder „14“.
String formatiereStein(int gramm) {
  final stein = gramm / kGrammJeStein;
  final ganz = (gramm % kGrammJeStein) == 0;
  return ganz
      ? '${gramm ~/ kGrammJeStein}'
      : stein.toStringAsFixed(1).replaceAll('.', ',');
}
