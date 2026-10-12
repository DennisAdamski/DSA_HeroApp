import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
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
