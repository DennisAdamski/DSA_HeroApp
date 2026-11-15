import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ortsfakten.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';

// Kurzfakten und Bauwerke zu einem Ort für die Ortsansicht (Standort-Kachel,
// Infotafel der Karte). Quelle ist die Wiki Aventurica; verknüpft wird über
// den Wiki-Seitennamen des Ortsverzeichnisses.

/// Fakten und Bauwerke eines Orts.
class OrtsAuskunft {
  /// Erstellt die Auskunft.
  const OrtsAuskunft({
    this.fakten,
    this.tempel = const <OrtsBauwerk>[],
    this.wichtigeOrte = const <OrtsBauwerk>[],
  });

  /// Kurzfakten, oder `null`.
  final SiedlungsFakten? fakten;

  /// Tempel, Schreine, Heiligtümer, Kapellen und Klöster, nach Name.
  final List<OrtsBauwerk> tempel;

  /// Übrige Bauwerke, bedeutende zuerst ([bauwerkRang]), dann nach Name.
  final List<OrtsBauwerk> wichtigeOrte;

  /// Ob es nichts zu zeigen gibt.
  bool get istLeer =>
      (fakten == null || fakten!.istLeer) &&
      tempel.isEmpty &&
      wichtigeOrte.isEmpty;
}

/// Wiki-Seitenname eines Eintrags des Ortsverzeichnisses.
String ortsSeite(OrtEintrag eintrag) =>
    eintrag.seite.isNotEmpty ? eintrag.seite : eintrag.name;

/// Der Eintrag des Ortsverzeichnisses [verzeichnis] zum Avesmaps-Ort [ort]:
/// zuerst über die Kennung, sonst über den Namen (nur Siedlungen).
OrtEintrag? ortsEintragZu(AvesmapsOrt ort, List<OrtEintrag> verzeichnis) {
  for (final eintrag in verzeichnis) {
    if (eintrag.ortId == ort.id && eintrag.art == OrtArt.siedlung) {
      return eintrag;
    }
  }
  final eintrag = findeOrt(ort.name, verzeichnis);
  return eintrag?.art == OrtArt.siedlung ? eintrag : null;
}

/// Fakten und Bauwerke zum Eintrag [eintrag] aus [katalog]; leer, wenn der
/// Eintrag keine Siedlung ist oder das Wiki nichts weiß.
OrtsAuskunft ortsAuskunft(OrtEintrag? eintrag, OrtsfaktenKatalog katalog) {
  if (eintrag == null || eintrag.art != OrtArt.siedlung) {
    return const OrtsAuskunft();
  }
  final seite = ortsSeite(eintrag);
  final bauwerke = katalog.bauwerke[seite] ?? const <OrtsBauwerk>[];
  int nachName(OrtsBauwerk a, OrtsBauwerk b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  final tempel = <OrtsBauwerk>[
    for (final b in bauwerke)
      if (istTempel(b)) b,
  ]..sort(nachName);
  final uebrige = reiheNachVielfalt(<OrtsBauwerk>[
    for (final b in bauwerke)
      if (!istTempel(b)) b,
  ]);
  return OrtsAuskunft(
    fakten: katalog.siedlungen[seite],
    tempel: List<OrtsBauwerk>.unmodifiable(tempel),
    wichtigeOrte: List<OrtsBauwerk>.unmodifiable(uebrige),
  );
}

/// Ob ein Bauwerk der Götterverehrung dient (Tempel, Schrein, Heiligtum,
/// Kapelle, Kloster); ein „Unheiligtum“ zählt nicht.
bool istTempel(OrtsBauwerk bauwerk) {
  final art = bauwerk.art.toLowerCase();
  if (art.contains('unheilig')) return false;
  return art.contains('tempel') ||
      art.contains('schrein') ||
      art.contains('heiligtum') ||
      art.contains('kapelle') ||
      art.contains('kloster');
}

// Arten, die für Reisende zählen, in dieser Reihenfolge: Macht, Schutz,
// Wissen, Glaube der Orden, Handel und Verkehr, Unterkunft, Vergnügen.
const List<String> _bedeutend = <String>[
  'palast',
  'schloss',
  'burg',
  'wasserburg',
  'burj',
  'festung',
  'zitadelle',
  'rathaus',
  'magierakademie',
  'akademie',
  'universität',
  'magierturm',
  'bibliothek',
  'archiv',
  'ordenshaus',
  'hafen',
  'markt',
  'marktplatz',
  'markthalle',
  'kontor',
  'bank',
  'gildenhaus',
  'karawanserei',
  'herberge',
  'gasthaus',
  'taverne',
  'arena',
  'amphitheater',
  'theater',
  'museum',
  'therme',
  'garnison',
  'kaserne',
  'gerichtsgebäude',
  'leuchtturm',
  'werft',
  'boronanger',
  'grabanlage',
  'unheiligtum',
  'botschaft',
];

// Arten, die eine Stadt nur ausschmücken; sie stehen zuletzt.
const Set<String> _nebensaechlich = <String>{
  '',
  '?',
  'wohnhaus',
  'villa',
  'herrenhaus',
  'handwerksbetrieb',
  'zunfthaus',
  'manufaktur',
  'platz',
  'statue',
  'obelisk',
  'brunnen',
  'stadttor',
  'tor',
  'tor (bauwerk)',
  'torbogen',
  'triumphbogen',
  'wassertor',
  'stadtmauer',
  'brücke',
  'damm',
  'straße',
  'treppe',
  'park',
  'garten',
  'gartenanlage',
  'kanalisation',
  'druckerei',
  'redaktionshaus',
  'gestüt',
  'poststation',
  'lager',
  'lagerhaus',
  'kerker',
  'schuldturm',
  'rennbahn',
};

/// Rang eines Bauwerks außer Tempeln: 0 bedeutend (Palast, Burg, Akademie,
/// Hafen, Markt, Herberge …), 1 sonstig, 2 nebensächlich (Wohnhaus, Platz,
/// Tor, Statue …).
int bauwerkRang(OrtsBauwerk bauwerk) {
  final art = bauwerk.art.toLowerCase().trim();
  if (_bedeutend.contains(art)) return 0;
  if (_nebensaechlich.contains(art)) return 2;
  return 1;
}

/// Bauwerke außer Tempeln in Anzeigereihenfolge: nach [bauwerkRang], und
/// innerhalb eines Rangs reihum je Art, damit oben nicht fünf Botschaften
/// stehen. Bedeutende Arten folgen ihrer festen Reihenfolge (Palast vor Burg
/// vor Akademie …), die übrigen dem Alphabet; je Art nach Name.
List<OrtsBauwerk> reiheNachVielfalt(List<OrtsBauwerk> bauwerke) {
  final ergebnis = <OrtsBauwerk>[];
  for (var rang = 0; rang <= 2; rang++) {
    final nachArt = <String, List<OrtsBauwerk>>{};
    for (final b in bauwerke) {
      if (bauwerkRang(b) != rang) continue;
      (nachArt[b.art.toLowerCase().trim()] ??= <OrtsBauwerk>[]).add(b);
    }
    final arten = nachArt.keys.toList()
      ..sort((a, b) {
        if (rang == 0) {
          return _bedeutend.indexOf(a).compareTo(_bedeutend.indexOf(b));
        }
        return a.compareTo(b);
      });
    for (final liste in nachArt.values) {
      liste.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    if (rang == 2) {
      // Nebensächliches schlicht nach Name.
      ergebnis.addAll(
        nachArt.values.expand((l) => l).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        ),
      );
      continue;
    }
    for (var i = 0; ; i++) {
      var weiter = false;
      for (final art in arten) {
        final liste = nachArt[art]!;
        if (i < liste.length) {
          ergebnis.add(liste[i]);
          weiter = true;
        }
      }
      if (!weiter) break;
    }
  }
  return List<OrtsBauwerk>.unmodifiable(ergebnis);
}

/// Zahl mit Tausenderpunkten, etwa „170.000“.
String mitTausenderpunkten(int zahl) =>
    '$zahl'.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// Einwohnerangabe für die Anzeige, etwa „170.000 (sowie 1000 Zwerge …;
/// 1040 BF)“; leer ohne Angabe.
///
/// Steht die Hauptzahl am Anfang des Wiki-Texts, bekommt sie Tausenderpunkte.
String einwohnerAnzeige(SiedlungsFakten fakten) {
  final zahl = fakten.einwohner;
  final text = fakten.einwohnerText;
  if (zahl == null) return text;
  if (text.isEmpty) return mitTausenderpunkten(zahl);
  final roh = '$zahl';
  return text.startsWith(roh)
      ? mitTausenderpunkten(zahl) + text.substring(roh.length)
      : text;
}

/// Zeile eines Bauwerks für die Anzeige: Art und Zugehörigkeit, etwa
/// „Tempel · Boron-Kirche: Puniner Ritus“; leer ohne Angaben.
String bauwerkZeile(OrtsBauwerk bauwerk) => <String>[
  if (bauwerk.art.isNotEmpty) bauwerk.art,
  if (bauwerk.zugehoerigkeit.isNotEmpty) bauwerk.zugehoerigkeit,
].join(' · ');

/// Link auf die Wiki-Seite des Bauwerks.
Uri bauwerkLink(OrtsBauwerk bauwerk) => Uri.https(
  kWikiAventuricaHost,
  '/wiki/${bauwerk.wikiSeite.replaceAll(' ', '_')}',
);

/// Gottheit bzw. Glaube eines Tempels aus seiner Zugehörigkeit, etwa „Boron“
/// aus „Boron-Kirche: Puniner Ritus“; ohne Angabe „Weitere“.
String gottheitVon(OrtsBauwerk tempel) {
  var text = tempel.zugehoerigkeit.split(RegExp('[:,]')).first.trim();
  text = text.replaceAll(RegExp(r'\s*\(.*\)$'), '').trim();
  if (text.isEmpty || text.toLowerCase() == 'unbekannt') return 'Weitere';
  final kirche = RegExp(r'^(.+?)-(Kirche|Glauben|Glaube|Kult)$')
      .firstMatch(text);
  return kirche?.group(1) ?? text;
}

/// Tempel nach Gottheit gruppiert: die meisten zuerst, dann nach Name;
/// „Weitere“ steht zuletzt.
List<(String, List<OrtsBauwerk>)> tempelNachGottheit(List<OrtsBauwerk> tempel) {
  final gruppen = <String, List<OrtsBauwerk>>{};
  for (final t in tempel) {
    (gruppen[gottheitVon(t)] ??= <OrtsBauwerk>[]).add(t);
  }
  final liste = gruppen.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) {
      if (a.$1 == 'Weitere') return 1;
      if (b.$1 == 'Weitere') return -1;
      final anzahl = b.$2.length.compareTo(a.$2.length);
      return anzahl != 0 ? anzahl : a.$1.compareTo(b.$1);
    });
  return List<(String, List<OrtsBauwerk>)>.unmodifiable(liste);
}

/// Einwohner in zwei Teilen: die Zahl mit Tausenderpunkten (oder `null`)
/// und der Zusatz ohne äußere Klammern, etwa `('27.500', 'davon 2500
/// Tulamiden, 1040 BF')`. Ohne Zahl steht der ganze Wiki-Text im Zusatz.
(String?, String) einwohnerTeile(SiedlungsFakten fakten) {
  final zahl = fakten.einwohner;
  var text = fakten.einwohnerText.trim();
  if (zahl == null) return (null, text);
  if (text.startsWith('$zahl')) text = text.substring('$zahl'.length).trim();
  // „(a) (b)“ wird zu „a; b“, eine einzelne Klammer fällt weg.
  final klammern = RegExp(r'^\((.*)\)$').firstMatch(text);
  if (klammern != null && !klammern.group(1)!.contains(')')) {
    text = klammern.group(1)!.trim();
  } else {
    text = text.replaceAll(') (', '; ').replaceAll(RegExp(r'^\(|\)$'), '');
  }
  return (mitTausenderpunkten(zahl), text.trim());
}
