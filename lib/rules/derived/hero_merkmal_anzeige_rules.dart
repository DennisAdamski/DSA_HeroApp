/// Anzeigeaufbereitung strukturierter Vor- und Nachteile (ARCH-02).
///
/// Liefert fuer die Merkmalskarten des Neubaus Art, aktuellen Katalognamen,
/// Detail (Stufe/Auswahl), Wirkungstexte und Herkunft. Gerechnet wird hier
/// nichts Eigenes: Die Betraege kommen aus denselben Hilfsfunktionen wie die
/// Regelauswertung in `hero_merkmal_wirkung_rules.dart`.
library;

import 'package:dsa_heldenverwaltung/catalog/hero_trait_def.dart';
import 'package:dsa_heldenverwaltung/catalog/hero_trait_effect.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';

/// Herkunft eines Eintrags aus Sicht der Anzeige.
enum MerkmalHerkunft {
  /// Einem Katalogeintrag zugeordnet.
  katalog,

  /// Freier Eintrag, wirkt ueber den Textparser.
  frei,

  /// Mehrdeutiger Alttext; eine Zuordnung steht aus.
  pruefen,

  /// Die Katalog-ID gibt es im aktuellen Katalog nicht (mehr).
  unbekannt,
}

/// Aufbereitete Angaben einer Merkmalskarte.
class MerkmalAnzeige {
  /// Buendelt die Anzeigeangaben eines Eintrags.
  const MerkmalAnzeige({
    required this.art,
    required this.name,
    required this.detail,
    required this.wirkungen,
    required this.herkunft,
    required this.kurz,
    this.def,
  });

  /// `Vorteil` oder `Nachteil`.
  final String art;

  /// Aktueller Katalogname, bei freien Eintraegen der gespeicherte Text.
  final String name;

  /// Stufe und Auswahl, z. B. `Stufe 6 · Auswahl: KK`; leer ohne beides.
  final String detail;

  /// Kurze Wirkungstexte, z. B. `LeP +3`; leer bei rein beschreibenden.
  final List<String> wirkungen;

  /// Herkunft des Eintrags.
  final MerkmalHerkunft herkunft;

  /// Kurzform fuer Uebersichten, z. B. `Jähzorn 6`: mit aktuellem
  /// Katalognamen gebildet, bei freien Eintraegen der gespeicherte Text.
  final String kurz;

  /// Zugehoeriger Katalogeintrag, sofern vorhanden.
  final HeroTraitDef? def;

  /// Beschriftung der Herkunft fuer die Karte.
  String get herkunftText => switch (herkunft) {
    MerkmalHerkunft.katalog => 'Aus dem Katalog',
    MerkmalHerkunft.frei => 'Freier Eintrag',
    MerkmalHerkunft.pruefen => 'Zuordnung prüfen',
    MerkmalHerkunft.unbekannt => 'Nicht im Katalog',
  };
}

/// Bereitet [eintrag] fuer die Anzeige auf.
MerkmalAnzeige beschreibeMerkmal(
  HeroMerkmal eintrag,
  MerkmalKatalog katalog, {
  required bool vorteil,
}) {
  final art = vorteil ? 'Vorteil' : 'Nachteil';
  final def = eintrag.istKatalogisiert
      ? katalog.eintrag(eintrag.katalogId, vorteil: vorteil)
      : null;
  if (def == null) {
    return MerkmalAnzeige(
      art: art,
      name: eintrag.text,
      detail: '',
      wirkungen: const <String>[],
      kurz: eintrag.text,
      herkunft: eintrag.istKatalogisiert
          ? MerkmalHerkunft.unbekannt
          : eintrag.brauchtPruefung
          ? MerkmalHerkunft.pruefen
          : MerkmalHerkunft.frei,
    );
  }
  final teile = <String>[
    if (eintrag.wert != null) 'Stufe ${eintrag.wert}',
    if (eintrag.auswahl.trim().isNotEmpty) 'Auswahl: ${eintrag.auswahl.trim()}',
  ];
  return MerkmalAnzeige(
    art: art,
    name: def.name,
    detail: teile.join(' · '),
    wirkungen: List<String>.unmodifiable(
      def.wirkungen
          .map((wirkung) => _wirkungstext(wirkung, eintrag))
          .whereType<String>(),
    ),
    herkunft: MerkmalHerkunft.katalog,
    kurz: merkmalTextFuer(def, auswahl: eintrag.auswahl, wert: eintrag.wert),
    def: def,
  );
}

// Kurzer Text zu einer Wirkung; `null`, wenn sie fuer [eintrag] nicht greift.
String? _wirkungstext(HeroTraitEffect wirkung, HeroMerkmal eintrag) {
  switch (wirkung.art) {
    case HeroTraitEffectArt.basiswert:
      final betrag = merkmalBasiswertBetrag(wirkung, eintrag);
      if (betrag == null || betrag == 0) return null;
      return '${_basiswertName(wirkung.ziel)} ${_vorzeichen(betrag)}';
    case HeroTraitEffectArt.eigenschaft:
      final code = parseAttributeCode(eintrag.auswahl);
      if (code == null) return null;
      final betrag = merkmalEigenschaftBetrag(wirkung, eintrag);
      final text = '${attributeCodeKey(code)} ${_vorzeichen(betrag)}';
      return wirkung.startwert ? '$text (auch Startwert)' : text;
    case HeroTraitEffectArt.schalter:
      return switch (wirkung.ziel) {
        'flink' => 'GS +1, Ausweichen +1',
        'behaebig' => 'GS −1, Ausweichen −1',
        _ => null,
      };
    case HeroTraitEffectArt.wundschwelle:
      return 'Wundschwellen ${_vorzeichen(wirkung.betrag)}';
    case HeroTraitEffectArt.rast:
      final stufe = merkmalRastStufe(wirkung, eintrag);
      return switch (wirkung.ziel) {
        'lepStufe' => 'LeP-Regeneration +$stufe',
        'aspStufe' => 'AsP-Regeneration +$stufe',
        'schlechteRegeneration' => 'LeP-Regeneration −1',
        'astralerBlock' => 'AsP-Regeneration −1',
        _ => null,
      };
    case HeroTraitEffectArt.lernspalte:
      return _lernspaltenText(wirkung, eintrag.auswahl.trim());
    case HeroTraitEffectArt.unbekannt:
      return null;
  }
}

// Ziel und Richtung einer Begabung/Unfaehigkeit, z. B.
// `Abrichten eine Spalte günstiger`.
String? _lernspaltenText(HeroTraitEffect wirkung, String auswahl) {
  if (wirkung.betrag == 0) {
    return null;
  }
  final schritte = wirkung.betrag.abs();
  final spalten = schritte == 1 ? 'eine Spalte' : '$schritte Spalten';
  final richtung = wirkung.betrag > 0 ? 'günstiger' : 'teurer';
  final ziel = switch (wirkung.ziel) {
    'nahkampf' => 'Nahkampftalente',
    'fernkampf' => 'Fernkampftalente',
    'sprachen' => 'Sprachen',
    'merkmal' when auswahl.isNotEmpty => 'Zauber je Merkmal $auswahl',
    'ritual' when auswahl.isNotEmpty => 'Ritualkenntnis zu $auswahl',
    'talent' ||
    'talentgruppe' ||
    'sprachgruppe' ||
    'zauber' when auswahl.isNotEmpty => auswahl,
    _ => null,
  };
  return ziel == null ? null : '$ziel $spalten $richtung';
}

String _basiswertName(String ziel) => switch (ziel) {
  'lep' => 'LeP',
  'au' => 'AuP',
  'asp' => 'AsP',
  'kap' => 'KaP',
  'mr' => 'MR',
  'ini' => 'INI-Basis',
  'gs' => 'GS',
  'ausweichen' => 'Ausweichen',
  _ => ziel,
};

// Vorzeichen mit typografischem Minus.
String _vorzeichen(int betrag) => betrag < 0 ? '−${-betrag}' : '+$betrag';
