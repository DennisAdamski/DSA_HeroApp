/// Zuordnung von Vor-/Nachteil-Texten zu Katalogeintraegen (ARCH-02).
///
/// Helden speichern Vor- und Nachteile strukturiert in
/// `HeroSheet.vorteilEintraege`/`nachteilEintraege`; die Textfelder
/// `vorteileText`/`nachteileText` sind nur noch deren Projektion fuer
/// aeltere App-Versionen. Dieses Modul
///
/// - ordnet Alttexte eindeutig, mehrdeutig oder gar nicht dem Katalog zu
///   ([ordneMerkmalZu], [migriereMerkmale]),
/// - erzeugt die Projektion ([projiziereMerkmalText]) und
/// - erkennt, ob eine aeltere Version den Text geaendert hat
///   ([gleicheMerkmaleAb]). Die Liste fuehrt; eine Abweichung wird nur
///   gemeldet und nie still uebernommen oder verworfen.
///
/// Zugeordnet wird nur, was eindeutig ist. Mehrdeutige Texte bleiben freie
/// Eintraege mit ihren Kandidaten, unbekannte Texte freie Eintraege; beide
/// wirken weiter ueber den Modifikator-Parser, so dass Bestandshelden ihre
/// Werte behalten.
library;

import 'package:dsa_heldenverwaltung/catalog/hero_trait_text.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Vor- und Nachteile eines Katalogs, nach ID nachschlagbar.
///
/// Wird je [RulesCatalog] einmal aufgebaut und gemerkt ([MerkmalKatalog.von]),
/// weil Regeln ihn bei jeder Berechnung brauchen.
class MerkmalKatalog {
  /// Baut die Nachschlagetabellen aus den beiden Listen.
  MerkmalKatalog({
    required List<HeroTraitDef> vorteile,
    required List<HeroTraitDef> nachteile,
  }) : vorteile = List<HeroTraitDef>.unmodifiable(vorteile),
       nachteile = List<HeroTraitDef>.unmodifiable(nachteile),
       _vorteilNachId = <String, HeroTraitDef>{
         for (final def in vorteile) def.id: def,
       },
       _nachteilNachId = <String, HeroTraitDef>{
         for (final def in nachteile) def.id: def,
       };

  /// Gemerkter Merkmalskatalog zu [catalog].
  static MerkmalKatalog von(RulesCatalog catalog) {
    return _cache[catalog] ??= MerkmalKatalog(
      vorteile: catalog.advantages,
      nachteile: catalog.disadvantages,
    );
  }

  static final Expando<MerkmalKatalog> _cache = Expando<MerkmalKatalog>();

  /// Alle Vorteile in Katalogreihenfolge.
  final List<HeroTraitDef> vorteile;

  /// Alle Nachteile in Katalogreihenfolge.
  final List<HeroTraitDef> nachteile;

  final Map<String, HeroTraitDef> _vorteilNachId;
  final Map<String, HeroTraitDef> _nachteilNachId;

  /// Katalogeintrag zu [id] in der passenden Liste, sonst `null`.
  HeroTraitDef? eintrag(String id, {required bool vorteil}) {
    return vorteil ? _vorteilNachId[id] : _nachteilNachId[id];
  }

  /// Liste der passenden Merkmalsart.
  List<HeroTraitDef> liste({required bool vorteil}) {
    return vorteil ? vorteile : nachteile;
  }
}

/// Ordnet ein einzelnes Textfragment dem Katalog zu.
///
/// Ergebnis ist ein [HeroMerkmal] mit `zuordnung: migration`:
/// eindeutig → mit `katalogId`, Wert und Auswahl; mehrdeutig → frei mit
/// `kandidatenIds`; kein Treffer → frei (`zuordnung: frei`). [text] bleibt
/// unveraendert, damit die Projektion dem bisherigen Text entspricht.
HeroMerkmal ordneMerkmalZu(String text, List<HeroTraitDef> defs) {
  final fragment = text.trim();
  final treffer = _treffer(fragment, defs);
  if (treffer.length == 1) {
    final einziger = treffer.single;
    return HeroMerkmal(
      katalogId: einziger.def.id,
      text: fragment,
      wert: einziger.wert,
      auswahl: einziger.auswahl,
      zuordnung: HeroMerkmalZuordnung.migration,
    );
  }
  if (treffer.length > 1) {
    return HeroMerkmal(
      text: fragment,
      kandidatenIds: List<String>.unmodifiable(
        treffer.map((eintrag) => eintrag.def.id),
      ),
      zuordnung: HeroMerkmalZuordnung.migration,
    );
  }
  return HeroMerkmal(text: fragment, zuordnung: HeroMerkmalZuordnung.frei);
}

/// Migriert einen Alttext in strukturierte Eintraege.
///
/// Zerlegt wie [splitHeroTraitText], fuegt aber durch Komma getrennte Teile
/// wieder zusammen, wenn sie gemeinsam ein Katalog-Template mit Komma
/// treffen (`Adlig, Adliges Erbe`). Deterministisch: derselbe Text ergibt
/// dieselbe Liste, und die Projektion des Ergebnisses zerlegt sich wieder in
/// dieselben Fragmente wie der Alttext.
List<HeroMerkmal> migriereMerkmale(String text, List<HeroTraitDef> defs) {
  return List<HeroMerkmal>.unmodifiable(
    zerlegeMerkmalText(text, defs).map((teil) => ordneMerkmalZu(teil, defs)),
  );
}

/// Zerlegt einen Merkmalstext in Fragmente; Komma-Templates bleiben ganz.
List<String> zerlegeMerkmalText(String text, List<HeroTraitDef> defs) {
  final mitKomma = defs
      .where((def) => def.active && _template(def).contains(','))
      .toList(growable: false);
  final gesehen = <String>{};
  final ergebnis = <String>[];
  void uebernimm(String teil) {
    final fragment = teil.trim();
    if (fragment.isEmpty || !gesehen.add(fragment)) {
      return;
    }
    ergebnis.add(fragment);
  }

  for (final abschnitt in text.split(RegExp(r'[\n;]+'))) {
    final teile = abschnitt.split(',');
    var index = 0;
    while (index < teile.length) {
      var verbraucht = 1;
      if (mitKomma.isNotEmpty) {
        // Laengste Verbindung zuerst, damit drei Teile vor zweien greifen.
        for (var anzahl = 3; anzahl >= 2; anzahl--) {
          if (index + anzahl > teile.length) {
            continue;
          }
          final verbunden = teile
              .sublist(index, index + anzahl)
              .map((teil) => teil.trim())
              .join(', ');
          if (_treffer(verbunden, mitKomma).isNotEmpty) {
            verbraucht = anzahl;
            break;
          }
        }
      }
      uebernimm(
        teile
            .sublist(index, index + verbraucht)
            .map((teil) => teil.trim())
            .join(', '),
      );
      index += verbraucht;
    }
  }
  return List<String>.unmodifiable(ergebnis);
}

/// Text fuer aeltere App-Versionen: die Fragmente der Eintraege, `; `-getrennt.
String projiziereMerkmalText(List<HeroMerkmal> eintraege) {
  return serializeHeroTraitFragments(eintraege.map((eintrag) => eintrag.text));
}

/// Text eines Katalogeintrags mit Wert und Auswahl, wie ihn der Dialog baut.
String merkmalTextFuer(HeroTraitDef def, {String auswahl = '', int? wert}) {
  return buildHeroTraitSelectionText(trait: def, choice: auswahl, value: wert);
}

/// Aenderung am Text durch eine aeltere App-Version.
class MerkmalAbweichung {
  /// Erstellt eine Abweichung aus den Fragmentmengen.
  const MerkmalAbweichung({required this.hinzugefuegt, required this.entfernt});

  /// Fragmente, die im Text stehen, aber keinem Eintrag entsprechen.
  final List<String> hinzugefuegt;

  /// Fragmente von Eintraegen, die im Text fehlen.
  final List<String> entfernt;
}

/// Wirksame Vor- und Nachteile eines Helden samt offener Pruefungen.
class MerkmalAbgleich {
  /// Buendelt das Ergebnis von [gleicheMerkmaleAb].
  const MerkmalAbgleich({
    required this.vorteile,
    required this.nachteile,
    required this.ausAlttext,
    this.vorteilAbweichung,
    this.nachteilAbweichung,
  });

  /// Wirksame Vorteile (gespeicherte Liste oder Laufzeitmigration).
  final List<HeroMerkmal> vorteile;

  /// Wirksame Nachteile.
  final List<HeroMerkmal> nachteile;

  /// Ob die Eintraege erst zur Laufzeit aus dem Alttext stammen, weil der
  /// Held noch nicht mit dieser Version gespeichert wurde.
  final bool ausAlttext;

  /// Abweichung des Vorteiltexts von der Liste, sonst `null`.
  final MerkmalAbweichung? vorteilAbweichung;

  /// Abweichung des Nachteiltexts von der Liste, sonst `null`.
  final MerkmalAbweichung? nachteilAbweichung;

  /// Ob eine aeltere Version einen der Texte geaendert hat.
  bool get hatAbweichung =>
      vorteilAbweichung != null || nachteilAbweichung != null;

  /// Mehrdeutig zugeordnete Eintraege, die geprueft werden sollten.
  List<HeroMerkmal> get offenePruefungen => <HeroMerkmal>[
    ...vorteile.where((eintrag) => eintrag.brauchtPruefung),
    ...nachteile.where((eintrag) => eintrag.brauchtPruefung),
  ];
}

/// Ermittelt die wirksamen Vor- und Nachteile von [hero].
///
/// - Liste belegt: Die Liste gilt. Weicht der Text von ihrer Projektion ab,
///   hat eine aeltere Version ihn geaendert; das steht in der Abweichung.
/// - Liste leer: Der Alttext wird mit [katalog] zur Laufzeit migriert (nicht
///   gespeichert — das geschieht erst beim naechsten Speichern). Ohne Katalog
///   werden alle Fragmente freie Eintraege.
MerkmalAbgleich gleicheMerkmaleAb(HeroSheet hero, {MerkmalKatalog? katalog}) {
  final vorteile = _wirksam(
    hero.vorteilEintraege,
    hero.vorteileText,
    katalog?.vorteile,
  );
  final nachteile = _wirksam(
    hero.nachteilEintraege,
    hero.nachteileText,
    katalog?.nachteile,
  );
  return MerkmalAbgleich(
    vorteile: vorteile,
    nachteile: nachteile,
    ausAlttext:
        (hero.vorteilEintraege.isEmpty &&
            hero.vorteileText.trim().isNotEmpty) ||
        (hero.nachteilEintraege.isEmpty &&
            hero.nachteileText.trim().isNotEmpty),
    vorteilAbweichung: hero.vorteilEintraege.isEmpty
        ? null
        : vergleicheMerkmalText(hero.vorteileText, hero.vorteilEintraege),
    nachteilAbweichung: hero.nachteilEintraege.isEmpty
        ? null
        : vergleicheMerkmalText(hero.nachteileText, hero.nachteilEintraege),
  );
}

/// Vergleicht [text] mit der Projektion von [eintraege].
///
/// Verglichen werden die Fragmentmengen nach [splitHeroTraitText], damit
/// Trennzeichen (`,` statt `; `) und Reihenfolge keine Abweichung ergeben.
/// Liefert `null`, wenn beide dieselben Fragmente enthalten.
MerkmalAbweichung? vergleicheMerkmalText(
  String text,
  List<HeroMerkmal> eintraege,
) {
  final imText = splitHeroTraitText(text).toSet();
  final projiziert = splitHeroTraitText(projiziereMerkmalText(eintraege))
      .toSet();
  final hinzugefuegt = imText.difference(projiziert);
  final entfernt = projiziert.difference(imText);
  if (hinzugefuegt.isEmpty && entfernt.isEmpty) {
    return null;
  }
  return MerkmalAbweichung(
    hinzugefuegt: List<String>.unmodifiable(
      splitHeroTraitText(text).where(hinzugefuegt.contains),
    ),
    entfernt: List<String>.unmodifiable(
      splitHeroTraitText(projiziereMerkmalText(eintraege))
          .where(entfernt.contains),
    ),
  );
}

/// Text, mit dem der Parser ohne Katalog rechnet: die Projektion der Liste,
/// solange sie belegt ist (die Liste fuehrt), sonst der Alttext.
String wirksamerMerkmalText(String text, List<HeroMerkmal> eintraege) {
  return eintraege.isEmpty ? text : projiziereMerkmalText(eintraege);
}

// Liste, Laufzeitmigration oder freie Fragmente — siehe [gleicheMerkmaleAb].
List<HeroMerkmal> _wirksam(
  List<HeroMerkmal> gespeichert,
  String text,
  List<HeroTraitDef>? defs,
) {
  if (gespeichert.isNotEmpty) {
    return gespeichert;
  }
  if (defs != null) {
    return migriereMerkmale(text, defs);
  }
  return List<HeroMerkmal>.unmodifiable(
    splitHeroTraitText(text).map(
      (fragment) =>
          HeroMerkmal(text: fragment, zuordnung: HeroMerkmalZuordnung.frei),
    ),
  );
}

/// Ein passender Katalogeintrag samt den aus dem Text gelesenen Teilen.
class _Treffer {
  const _Treffer(this.def, {required this.wert, required this.auswahl});

  final HeroTraitDef def;
  final int? wert;
  final String auswahl;
}

// Alle aktiven Katalogeintraege, deren Template [fragment] trifft.
//
// Ein Template ohne Platzhalter, das exakt passt, schlaegt Templates mit
// Platzhaltern (`Astraler Block` gegen `Astraler Block {…}`). Feste
// Auswahllisten ohne freie Eingabe schliessen Eintraege aus, deren Liste die
// Auswahl nicht enthaelt.
List<_Treffer> _treffer(String fragment, List<HeroTraitDef> defs) {
  final normalisiert = _normalisiere(fragment);
  if (normalisiert.isEmpty) {
    return const <_Treffer>[];
  }
  final treffer = <_Treffer>[];
  for (final def in defs) {
    if (!def.active) {
      continue;
    }
    final passend = _passe(normalisiert, def);
    if (passend != null) {
      treffer.add(passend);
    }
  }
  final exakt = treffer
      .where((eintrag) => !_template(eintrag.def).contains('{'))
      .toList(growable: false);
  if (exakt.isNotEmpty) {
    return exakt;
  }
  return treffer;
}

// Prueft ein Fragment gegen das Template eines Eintrags.
_Treffer? _passe(String normalisiert, HeroTraitDef def) {
  final muster = _muster[def] ??= _Muster.aus(def);
  final treffer = muster.regex?.firstMatch(normalisiert);
  if (treffer == null) {
    return null;
  }
  final auswahl = muster.auswahlGruppe == 0
      ? ''
      : (treffer.group(muster.auswahlGruppe) ?? '').trim();
  if (auswahl.isNotEmpty && !_auswahlErlaubt(def, auswahl)) {
    return null;
  }
  return _Treffer(
    def,
    wert: muster.wertGruppe == 0
        ? null
        : _leseWert(treffer.group(muster.wertGruppe)),
    auswahl: auswahl,
  );
}

// Uebersetzte Templates, je Katalogeintrag einmal gebaut.
final Expando<_Muster> _muster = Expando<_Muster>();

/// Regulaerer Ausdruck zu einem Template samt Gruppennummern.
class _Muster {
  const _Muster(this.regex, {this.wertGruppe = 0, this.auswahlGruppe = 0});

  // Gross-/Kleinschreibung und Mehrfachleerzeichen spielen keine Rolle. Ein
  // abschliessendes `{value}` darf fehlen (`Hohe Lebenskraft` ohne Zahl) und
  // eine roemische Stufe sein (`Schnelle Heilung II`); eine Klammer, die nur
  // `{choice}` enthaelt, ist optional (wie in [parseTraitFragmentParts]).
  factory _Muster.aus(HeroTraitDef def) {
    final template = _normalisiere(_template(def));
    if (template.isEmpty) {
      return const _Muster(null);
    }
    final tokenMuster = RegExp(
      r'\s*\{value\}$|\{value\}|\s*\(\{choice\}\)|\{choice\}',
    );
    final puffer = StringBuffer('^');
    var letztesEnde = 0;
    var gruppen = 0;
    var wertGruppe = 0;
    var auswahlGruppe = 0;
    for (final token in tokenMuster.allMatches(template)) {
      puffer.write(RegExp.escape(template.substring(letztesEnde, token.start)));
      final roh = token.group(0)!;
      gruppen++;
      if (roh.trim() == '{value}' && token.end == template.length) {
        wertGruppe = gruppen;
        puffer.write(r'(?:\s+(-?\d+|[ivx]+))?');
      } else if (roh == '{value}') {
        wertGruppe = gruppen;
        puffer.write(r'(-?\d+)');
      } else if (roh == '{choice}') {
        auswahlGruppe = gruppen;
        puffer.write('(.+?)');
      } else {
        auswahlGruppe = gruppen;
        puffer.write(r'(?:\s*\((.*?)\))?');
      }
      letztesEnde = token.end;
    }
    puffer.write(RegExp.escape(template.substring(letztesEnde)));
    puffer.write(r'$');
    return _Muster(
      RegExp(puffer.toString(), caseSensitive: false),
      wertGruppe: wertGruppe,
      auswahlGruppe: auswahlGruppe,
    );
  }

  final RegExp? regex;
  final int wertGruppe;
  final int auswahlGruppe;
}

// Feste Auswahllisten ohne freie Eingabe begrenzen die Zuordnung.
bool _auswahlErlaubt(HeroTraitDef def, String auswahl) {
  if (def.choiceFreeText || def.choices.isEmpty) {
    return true;
  }
  final gesucht = auswahl.toLowerCase();
  return def.choices.any((choice) => choice.toLowerCase() == gesucht);
}

// Liest eine arabische oder roemische Zahl (I bis X).
int? _leseWert(String? roh) {
  if (roh == null || roh.isEmpty) {
    return null;
  }
  final arabisch = int.tryParse(roh);
  if (arabisch != null) {
    return arabisch;
  }
  const roemisch = <String, int>{
    'i': 1,
    'ii': 2,
    'iii': 3,
    'iv': 4,
    'v': 5,
    'vi': 6,
    'vii': 7,
    'viii': 8,
    'ix': 9,
    'x': 10,
  };
  return roemisch[roh.toLowerCase()];
}

String _template(HeroTraitDef def) {
  final template = def.selectionTemplate.trim();
  return template.isEmpty ? def.name.trim() : template;
}

String _normalisiere(String text) {
  return text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Bereitet die Vor- und Nachteile von [hero] zum Speichern vor.
///
/// - Liste leer, Text belegt, [katalog] vorhanden: Der Alttext wird migriert
///   und gespeichert (einmalig; der Text wird zur Projektion der Liste).
/// - Liste belegt und ohne Abweichung: Der Text wird zur Projektion.
/// - Offene Abweichung (eine aeltere Version hat den Text geaendert): Liste
///   und Text bleiben unveraendert, bis der Nutzer entscheidet
///   ([uebernimmMerkmalText] bzw. [behalteMerkmalListe]).
///
/// Ohne Katalog wird nichts migriert. Die Funktion ist ein Fixpunkt: ein
/// zweiter Aufruf aendert nichts mehr.
HeroSheet merkmaleZumSpeichern(HeroSheet hero, {MerkmalKatalog? katalog}) {
  final vorteile = _zumSpeichern(
    hero.vorteilEintraege,
    hero.vorteileText,
    katalog?.vorteile,
  );
  final nachteile = _zumSpeichern(
    hero.nachteilEintraege,
    hero.nachteileText,
    katalog?.nachteile,
  );
  return hero.copyWith(
    vorteilEintraege: vorteile.eintraege,
    vorteileText: vorteile.text,
    nachteilEintraege: nachteile.eintraege,
    nachteileText: nachteile.text,
  );
}

/// Loest eine Abweichung zugunsten des Texts auf: Die Liste wird aus dem
/// geaenderten Text neu migriert. Bereits zugeordnete Eintraege, deren
/// Fragment unveraendert im Text steht, behalten ihre Zuordnung.
List<HeroMerkmal> uebernimmMerkmalText(
  String text,
  List<HeroMerkmal> eintraege,
  List<HeroTraitDef> defs,
) {
  final bisher = <String, HeroMerkmal>{
    for (final eintrag in eintraege) eintrag.text.trim(): eintrag,
  };
  return List<HeroMerkmal>.unmodifiable(
    zerlegeMerkmalText(
      text,
      defs,
    ).map((fragment) => bisher[fragment] ?? ordneMerkmalZu(fragment, defs)),
  );
}

/// Loest eine Abweichung zugunsten der Liste auf: Der Text wird wieder ihre
/// Projektion.
String behalteMerkmalListe(List<HeroMerkmal> eintraege) {
  return projiziereMerkmalText(eintraege);
}

// Eine Merkmalsart zum Speichern — siehe [merkmaleZumSpeichern].
({List<HeroMerkmal> eintraege, String text}) _zumSpeichern(
  List<HeroMerkmal> eintraege,
  String text,
  List<HeroTraitDef>? defs,
) {
  if (eintraege.isEmpty) {
    if (defs == null || text.trim().isEmpty) {
      return (eintraege: eintraege, text: text);
    }
    final migriert = migriereMerkmale(text, defs);
    return (eintraege: migriert, text: projiziereMerkmalText(migriert));
  }
  if (vergleicheMerkmalText(text, eintraege) != null) {
    return (eintraege: eintraege, text: text);
  }
  return (eintraege: eintraege, text: projiziereMerkmalText(eintraege));
}

/// Fuegt [neu] zu [eintraege] hinzu.
///
/// Gleicher Katalogeintrag mit gleicher Auswahl wird bei Templates mit
/// `{choice}` **und** `{value}` zu einem Eintrag mit summiertem Wert
/// zusammengefasst (wie [mergeHeroTraitFragment]); ein Eintrag mit
/// identischem Text wird nicht doppelt aufgenommen, weil die Projektion ihn
/// ohnehin nur einmal schriebe.
List<HeroMerkmal> fuegeMerkmalHinzu(
  List<HeroMerkmal> eintraege,
  HeroMerkmal neu, {
  HeroTraitDef? def,
}) {
  final ergebnis = List<HeroMerkmal>.of(eintraege);
  final template = def == null ? '' : _template(def);
  final summierbar =
      def != null &&
      neu.wert != null &&
      template.contains('{choice}') &&
      template.contains('{value}');
  if (summierbar) {
    final gesucht = neu.auswahl.trim().toLowerCase();
    for (var index = 0; index < ergebnis.length; index++) {
      final bisher = ergebnis[index];
      if (bisher.katalogId != neu.katalogId ||
          bisher.wert == null ||
          bisher.auswahl.trim().toLowerCase() != gesucht) {
        continue;
      }
      final summe = bisher.wert! + neu.wert!;
      ergebnis[index] = bisher.copyWith(
        wert: summe,
        text: merkmalTextFuer(def, auswahl: bisher.auswahl, wert: summe),
      );
      return List<HeroMerkmal>.unmodifiable(ergebnis);
    }
  }
  if (ergebnis.any((bisher) => bisher.text.trim() == neu.text.trim())) {
    return List<HeroMerkmal>.unmodifiable(ergebnis);
  }
  ergebnis.add(neu);
  return List<HeroMerkmal>.unmodifiable(ergebnis);
}

/// Aendert die Vor- (bei [vorteil]) oder Nachteile von [held] gezielt.
///
/// Ausgangspunkt ist die wirksame Liste: bei einem Bestandshelden ohne Liste
/// die Laufzeitmigration, damit schon die erste Aenderung alles strukturiert
/// speichert. Geschrieben werden Liste **und** Projektion. Eine offene
/// Abweichung (eine aeltere App hat den Text geaendert) loest dieser Weg
/// nicht nebenbei auf, sondern wirft einen [StateError]; aufgeloest wird sie
/// nur ueber [loeseMerkmalAbweichung].
HeroSheet aendereMerkmale(
  HeroSheet held, {
  required bool vorteil,
  required MerkmalKatalog katalog,
  required List<HeroMerkmal> Function(List<HeroMerkmal> eintraege) aenderung,
}) {
  final abgleich = gleicheMerkmaleAb(held, katalog: katalog);
  final abweichung = vorteil
      ? abgleich.vorteilAbweichung
      : abgleich.nachteilAbweichung;
  if (abweichung != null) {
    throw StateError(
      'Eine ältere App-Version hat diese Einträge geändert. Bitte zuerst '
      'entscheiden, welcher Stand gilt.',
    );
  }
  final neu = List<HeroMerkmal>.unmodifiable(
    aenderung(vorteil ? abgleich.vorteile : abgleich.nachteile),
  );
  return _mitMerkmalen(held, vorteil: vorteil, eintraege: neu);
}

/// Loest eine Abweichung der Vor- (bei [vorteil]) oder Nachteile auf.
///
/// Mit [textUebernehmen] wird der geaenderte Text neu zugeordnet
/// ([uebernimmMerkmalText]); sonst bleibt die Liste und der Text wird wieder
/// ihre Projektion. Ohne Abweichung aendert sich nichts.
HeroSheet loeseMerkmalAbweichung(
  HeroSheet held, {
  required bool vorteil,
  required MerkmalKatalog katalog,
  required bool textUebernehmen,
}) {
  final liste = vorteil ? held.vorteilEintraege : held.nachteilEintraege;
  final text = vorteil ? held.vorteileText : held.nachteileText;
  if (liste.isEmpty || vergleicheMerkmalText(text, liste) == null) {
    return held;
  }
  final neu = textUebernehmen
      ? uebernimmMerkmalText(text, liste, katalog.liste(vorteil: vorteil))
      : liste;
  return _mitMerkmalen(held, vorteil: vorteil, eintraege: neu);
}

// Setzt Liste und Projektion einer Merkmalsart.
HeroSheet _mitMerkmalen(
  HeroSheet held, {
  required bool vorteil,
  required List<HeroMerkmal> eintraege,
}) {
  final text = projiziereMerkmalText(eintraege);
  return vorteil
      ? held.copyWith(vorteilEintraege: eintraege, vorteileText: text)
      : held.copyWith(nachteilEintraege: eintraege, nachteileText: text);
}
