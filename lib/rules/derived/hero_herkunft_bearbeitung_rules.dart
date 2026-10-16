import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/rules/derived/direkter_modifikator_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_migration_rules.dart';

/// Ersetzt die Einträge einer Herkunftsgruppe gezielt.
///
/// [basis] ist der Stand, aus dem der Nutzer seine Änderung aufgebaut hat,
/// [aktuell] der frisch geladene gespeicherte Stand. Ergebnis ist [aktuell]
/// mit den neuen [eintraege] und der zugehörigen Textprojektion **nur** dieser
/// Gruppe; alle anderen Gruppen und Felder bleiben, wie [aktuell] sie trägt.
///
/// Wirft [StateError], wenn
/// - die Gruppe in [aktuell] gesperrt ist (unbekannte Version, nicht
///   verstandene Teilstücke, doppelte IDs),
/// - ihr Text von der Liste abweicht (offene Abweichung zu einer älteren App),
/// - oder die Gruppe seit [basis] anderweitig geändert wurde.
HeroBackground ersetzeHerkunftsEintraege({
  required HeroBackground basis,
  required HeroBackground aktuell,
  required HeroHerkunft herkunft,
  required List<HeroHerkunftsModifikator> eintraege,
}) {
  final container = wirksameHerkunftsModifikatoren(aktuell);
  if (!container.istGruppeBearbeitbar(herkunft)) {
    throw StateError(
      'Die Herkunftsgruppe ${herkunft.name} lässt sich nicht bearbeiten.',
    );
  }
  if (gleicheHerkunftAb(aktuell).abweichungen.containsKey(herkunft)) {
    throw StateError(
      'Der Herkunftstext von ${herkunft.name} weicht von der Liste ab. '
      'Bitte zuerst die Abweichung auflösen.',
    );
  }
  final vorher = wirksameHerkunftsModifikatoren(basis).eintraegeFuer(herkunft);
  final jetzt = container.eintraegeFuer(herkunft);
  if (!_gleicheEintraege(vorher, jetzt) ||
      herkunftsTextVon(basis, herkunft) !=
          herkunftsTextVon(aktuell, herkunft)) {
    throw StateError(
      'Die Herkunftsgruppe ${herkunft.name} wurde inzwischen geändert.',
    );
  }
  final liste = List<HeroHerkunftsModifikator>.unmodifiable(eintraege);
  final text = projiziereHerkunftsText(liste);
  final neuerContainer = switch (herkunft) {
    HeroHerkunft.rasse => container.copyWith(rasse: liste),
    HeroHerkunft.kultur => container.copyWith(kultur: liste),
    HeroHerkunft.profession => container.copyWith(profession: liste),
  };
  final mitContainer = aktuell.copyWith(herkunftsModifikatoren: neuerContainer);
  return switch (herkunft) {
    HeroHerkunft.rasse => mitContainer.copyWith(rasseModText: text),
    HeroHerkunft.kultur => mitContainer.copyWith(kulturModText: text),
    HeroHerkunft.profession => mitContainer.copyWith(professionModText: text),
  };
}

bool _gleicheEintraege(
  List<HeroHerkunftsModifikator> a,
  List<HeroHerkunftsModifikator> b,
) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// Eigenschaftscodes, die ein direkter Herkunftsmodifikator anspricht.
const List<String> herkunftEigenschaftsZiele = <String>[
  'MU',
  'KL',
  'IN',
  'CH',
  'FF',
  'GE',
  'KO',
  'KK',
];

/// Basiswertcodes, die ein direkter Herkunftsmodifikator anspricht.
const List<String> herkunftBasiswertZiele = <String>[
  'LEP',
  'AU',
  'ASP',
  'KAP',
  'MR',
  'INI',
  'GS',
  'AUSWEICHEN',
];

/// Baut einen direkten Eintrag aus Ziel und Betrag.
///
/// Ziel und Betrag werden gemeinsam über den Regelvertrag
/// ([erkenneDirektenModifikator]) geprüft und der Text daraus normalisiert
/// (`MU+1`, `LEP-2`). Gibt `null` zurück, wenn das Ziel unbekannt ist. Mit
/// [bisher] bleiben ID und unbekannte Felder eines bearbeiteten Eintrags
/// erhalten; sonst vergibt der Aufrufer die [id].
HeroHerkunftsModifikator? baueDirektenHerkunftsEintrag({
  required String ziel,
  required int betrag,
  String? id,
  HeroHerkunftsModifikator? bisher,
}) {
  final text =
      '${ziel.trim().toUpperCase()}${betrag < 0 ? '-' : '+'}'
      '${betrag.abs()}';
  return baueFreienHerkunftsEintrag(text: text, id: id, bisher: bisher);
}

/// Baut einen Eintrag aus einem einzelnen Textfragment.
///
/// Ein Fragment der Form `CODE±N` wird dabei strukturiert (so wirkt es wie
/// ein direkter Eintrag), alles andere bleibt ein freier Eintrag. Gibt `null`
/// zurück, wenn [text] leer ist oder mehrere Fragmente enthält (Trenner `,`,
/// `;`, Zeilenumbruch). Mit [bisher] bleiben ID und unbekannte Felder
/// erhalten.
HeroHerkunftsModifikator? baueFreienHerkunftsEintrag({
  required String text,
  String? id,
  HeroHerkunftsModifikator? bisher,
}) {
  final fragmente = zerlegeHerkunftsText(text);
  if (fragmente.length != 1) {
    return null;
  }
  final fragment = fragmente.single;
  final direkt = erkenneDirektenModifikator(fragment);
  final eintragsId = bisher?.id ?? id;
  if (eintragsId == null || eintragsId.isEmpty) {
    return null;
  }
  if (bisher != null) {
    return bisher.copyWith(
      art: direkt?.art ?? HeroHerkunftsModifikatorArt.frei,
      ziel: direkt?.ziel ?? '',
      betrag: direkt?.betrag,
      text: fragment,
    );
  }
  return direkt == null
      ? HeroHerkunftsModifikator(id: eintragsId, text: fragment)
      : HeroHerkunftsModifikator(
          id: eintragsId,
          art: direkt.art,
          ziel: direkt.ziel,
          betrag: direkt.betrag,
          text: fragment,
        );
}
