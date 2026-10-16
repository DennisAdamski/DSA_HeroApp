import 'package:dsa_heldenverwaltung/catalog/alchimikum_def.dart';
import 'package:dsa_heldenverwaltung/domain/alchimikum_bezug.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/vitalwirkung.dart';

// Katalogmittel (Tränke, Salben, Pulver) im Inventar (TRANK).
//
// Der Katalog liefert nur belegte Eckdaten mit Quelle. Daraus entsteht eine
// Vorbelegung für Inventareintrag und Anwendungsdialog; gebucht wird weiter
// nur, was der Nutzer im Dialog bestätigt. Würfelausdrücke bleiben Hinweise,
// geraten oder gewürfelt wird nie.

/// Qualitätsstufen der Regelwerke (`M` = misslungen bleibt Meisterentscheid
/// und ist deshalb nicht wählbar).
const List<String> kAlchimikaStufen = <String>['A', 'B', 'C', 'D', 'E', 'F'];

/// Die Stufe [stufe] von [mittel] oder `null`, wenn es sie nicht gibt.
AlchimikumQualitaet? alchimikumStufe(AlchimikumDef mittel, String? stufe) {
  if (stufe == null) {
    return null;
  }
  for (final kandidat in mittel.qualitaeten) {
    if (kandidat.stufe == stufe) {
      return kandidat;
    }
  }
  return null;
}

/// Name für den Inventareintrag, z. B. `Heiltrank (Qualität C)`.
String alchimikumInventarName(AlchimikumDef mittel, String? stufe) {
  if (alchimikumStufe(mittel, stufe) == null) {
    return mittel.name;
  }
  return '${mittel.name} (Qualität $stufe)';
}

/// Vorbelegung für „Anwenden“ oder `null`, wenn die Stufe keine Wirkung auf
/// Vitalwerte oder Wunden hat.
Vitalwirkung? alchimikumVitalwirkung(AlchimikumDef mittel, String? stufe) {
  final wirkung = alchimikumStufe(mittel, stufe);
  if (wirkung == null || !wirkung.hatVitalwirkung) {
    return null;
  }
  return Vitalwirkung(
    lepWurf: wirkung.lepWurf,
    aspWurf: wirkung.aspWurf,
    aupWurf: wirkung.aupWurf,
    lepProWunde: wirkung.lepProWunde,
  );
}

/// Wie viele Wunden sich bei [lep] zurückgewonnenen LeP schließen, wenn die
/// Vorbelegung eine solche Regel trägt; sonst `null`.
int? wundenAusLep(Vitalwirkung? vorgabe, int lep) {
  if (vorgabe == null || vorgabe.lepProWunde <= 0 || lep <= 0) {
    return null;
  }
  return lep ~/ vorgabe.lepProWunde;
}

/// Beschreibung für den Inventareintrag: Wirkung, Würfelvorschläge, Preis,
/// Haltbarkeit und Quelle in kurzen Zeilen.
String alchimikumBeschreibung(AlchimikumDef mittel, String? stufe) {
  final wirkung = alchimikumStufe(mittel, stufe);
  final zeilen = <String>[
    if (mittel.wirkung.isNotEmpty) mittel.wirkung,
    if (wirkung != null && wirkung.wirkung.isNotEmpty)
      'Qualität ${wirkung.stufe}: ${wirkung.wirkung}',
    if (wirkung != null) ..._wurfZeilen(wirkung),
    if (mittel.haltbarkeit.isNotEmpty) 'Haltbarkeit: ${mittel.haltbarkeit}',
    if (mittel.preisText.isNotEmpty) 'Preis: ${mittel.preisText}',
    if (mittel.beleg.buch.isNotEmpty) 'Quelle: ${mittel.beleg.kurz}',
  ];
  return zeilen.join('\n');
}

List<String> _wurfZeilen(AlchimikumQualitaet wirkung) {
  final teile = <String>[
    if (wirkung.lepWurf.isNotEmpty) 'LeP ${wirkung.lepWurf}',
    if (wirkung.aspWurf.isNotEmpty) 'AsP ${wirkung.aspWurf}',
    if (wirkung.aupWurf.isNotEmpty) 'AuP ${wirkung.aupWurf}',
  ];
  return <String>[
    if (teile.isNotEmpty) 'Wurf: ${teile.join(', ')}',
    if (wirkung.lepProWunde > 0)
      'Je ${wirkung.lepProWunde} zurückgewonnene LeP schließt sich eine Wunde.',
  ];
}

/// Übernimmt [mittel] in einen Inventareintrag.
///
/// Setzt Name, Typ „Verbrauchsgegenstand“, Beschreibung, Richtpreis (nur wenn
/// das Regelwerk einen eindeutigen nennt), die Vitalwirkung und den Verweis
/// auf das Katalogmittel (darüber findet „Anwenden“ später etwa die
/// Eigenschaftsänderungen eines Elixiers). Alle anderen Felder des Eintrags,
/// auch unbekannte Felder der Vorbelegung, bleiben erhalten.
HeroInventoryEntry mitAlchimikum(
  HeroInventoryEntry basis,
  AlchimikumDef mittel,
  String? stufe,
) {
  final neu = alchimikumVitalwirkung(mittel, stufe);
  final bisher = basis.vitalwirkung;
  Vitalwirkung? vitalwirkung;
  if (bisher != null) {
    // Frühere Katalogvorschläge entfallen, Felder einer neueren Version nicht.
    final geleert = bisher.copyWith(
      lep: 0,
      asp: 0,
      aup: 0,
      wunden: 0,
      lepWurf: neu?.lepWurf ?? '',
      aspWurf: neu?.aspWurf ?? '',
      aupWurf: neu?.aupWurf ?? '',
      lepProWunde: neu?.lepProWunde ?? 0,
    );
    vitalwirkung = geleert.istBelegt || geleert.unbekannteFelder.isNotEmpty
        ? geleert
        : null;
  } else {
    vitalwirkung = neu;
  }
  return basis.copyWith(
    gegenstand: alchimikumInventarName(mittel, stufe),
    itemType: InventoryItemType.verbrauchsgegenstand,
    beschreibung: alchimikumBeschreibung(mittel, stufe),
    wertSilber: mittel.preisSilber ?? basis.wertSilber,
    vitalwirkung: vitalwirkung,
    alchimikum: (basis.alchimikum ?? AlchimikumBezug(id: mittel.id)).copyWith(
      id: mittel.id,
      stufe: alchimikumStufe(mittel, stufe) == null ? '' : stufe,
    ),
  );
}
