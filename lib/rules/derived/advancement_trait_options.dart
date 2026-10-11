/// Steigerungsoptionen für nachträgliche Vorteile und den Abbau von Nachteilen.
///
/// Regeln und Kosten stehen in `trait_advancement_rules.dart`; dieses Modul
/// übersetzt sie in [AdvancementOption]s und wendet geplante Einträge auf den
/// Vorschauhelden an. Geschrieben wird ausschließlich über
/// [aendereMerkmale], damit Liste und Projektion für ältere App-Versionen
/// gemeinsam entstehen und eine offene Abweichung nie still aufgelöst wird.
library;

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

import 'advancement_options.dart';
import 'hero_merkmal_zuordnung_rules.dart';
import 'requirement_evaluation_rules.dart';
import 'trait_ap_cost_rules.dart';
import 'trait_advancement_rules.dart';

/// Optionsschlüssel: gewählte Auswahl (`{choice}`) eines Vorteils.
const String kMerkmalOptionAuswahl = 'auswahl';

/// Optionsschlüssel: Zielwert eines Vorteils.
const String kMerkmalOptionWert = 'wert';

/// Optionsschlüssel: Text des bestehenden Nachteils, der abgebaut wird.
const String kMerkmalOptionEintrag = 'eintrag';

/// Optionsschlüssel: Zielwert eines Nachteils; `0` heißt vollständig abgebaut.
const String kMerkmalOptionZiel = 'ziel';

/// Optionsschlüssel: Lernweg einer Schlechten Eigenschaft.
const String kMerkmalOptionLernweg = 'lernweg';

/// Obergrenze für Werte ohne Katalogmaximum (z. B. Verbindungen in GP).
const int _kOhneMaximum = 99;

SpecialAbilityRequirement _hinweis(String text) =>
    SpecialAbilityRequirement(art: RequirementArt.hinweis, text: text);

RequirementCheckResult _hinweisBefund(String text) => RequirementCheckResult(
  requirement: _hinweis(text),
  status: RequirementStatus.hinweis,
  sollText: text,
);

bool _gleicheAuswahl(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

/// Alle Optionen für Vorteile und Nachteile im gewünschten Umfang.
///
/// Vorteile: genau die nachträglich erwerbbaren Katalogeinträge. Nachteile:
/// jeder katalogisierte Nachteil des Helden, je Eintrag eine Option.
List<AdvancementOption> buildTraitAdvancementOptions(
  AdvancementContext context,
  AdvancementScope scope,
) {
  final katalog = MerkmalKatalog.von(context.catalog);
  final result = <AdvancementOption>[];
  for (final def in katalog.vorteile) {
    if (!kNachtraeglichErwerbbareVorteile.contains(def.id)) continue;
    final owned = context.merkmalAbgleich.vorteile.any(
      (eintrag) => eintrag.katalogId == def.id,
    );
    if (scope == AdvancementScope.inactive && owned) continue;
    if (scope == AdvancementScope.active && !owned) continue;
    final option = resolveAdvantageAdvancement(context, def.id, const {});
    if (option != null) result.add(option);
  }
  if (scope != AdvancementScope.inactive) {
    for (final eintrag in context.merkmalAbgleich.nachteile) {
      if (!eintrag.istKatalogisiert) continue;
      final option = resolveDisadvantageAdvancement(
        context,
        eintrag.katalogId,
        {kMerkmalOptionEintrag: eintrag.text},
      );
      if (option != null) result.add(option);
    }
  }
  return result;
}

/// Löst den nachträglichen Erwerb oder Ausbau eines Vorteils auf.
///
/// Ohne [options] beschreibt die Option den nächsten möglichen Schritt; mit
/// `auswahl`/`wert` genau den geplanten Zielstand.
AdvancementOption? resolveAdvantageAdvancement(
  AdvancementContext context,
  String id,
  Map<String, String> options,
) {
  final def = MerkmalKatalog.von(context.catalog).eintrag(id, vorteil: true);
  if (def == null) return null;
  final hero = context.hero;
  final braucheAuswahl = def.selectionTemplate.contains('{choice}');
  final traegtWert = merkmalTraegtWert(def);
  final auswahl = options[kMerkmalOptionAuswahl]?.trim() ?? '';
  final bestehende = context.merkmalAbgleich.vorteile
      .where((eintrag) => eintrag.katalogId == id)
      .toList(growable: false);
  final HeroMerkmal? bisher = braucheAuswahl
      ? (auswahl.isEmpty
            ? null
            : bestehende
                  .where((eintrag) => _gleicheAuswahl(eintrag.auswahl, auswahl))
                  .firstOrNull)
      : bestehende.firstOrNull;
  final maximum = def.maxValue ?? _kOhneMaximum;
  final aktuell = bisher == null ? -1 : (bisher.wert ?? 0);
  final vorgabe = !traegtWert
      ? null
      : (bisher == null ? merkmalMindestwert(def) : (bisher.wert ?? 0) + 1);
  final ziel = traegtWert
      ? int.tryParse(options[kMerkmalOptionWert] ?? '') ?? vorgabe
      : null;

  String? grund;
  if (!kNachtraeglichErwerbbareVorteile.contains(id)) {
    grund = 'Nicht nachträglich erwerbbar ($kMerkmalSteigerungQuelle)';
  } else if (hero.isEpisch) {
    grund =
        'Epischer Status: Vorteile sind nicht mehr nachträglich erlernbar '
        '(Epische Stufen S. 5)';
  } else if (context.merkmalAbgleich.vorteilAbweichung != null) {
    grund =
        'Eine ältere App-Version hat die Vorteile geändert; bitte zuerst im '
        'Merkmalsblatt entscheiden, welcher Stand gilt.';
  } else if (def.markers.any((marker) => marker.startsWith('M')) &&
      !context.resourceActivation.magic.isEnabled) {
    grund = 'Nur für Zauberkundige';
  } else if (bisher != null && !traegtWert) {
    grund = 'Bereits vorhanden';
  } else if (ziel != null && ziel > maximum) {
    grund = 'Höchstwert erreicht';
  } else if (ziel != null && bisher?.wert != null && ziel <= bisher!.wert!) {
    grund = 'Der Zielwert muss über dem aktuellen Wert liegen.';
  } else if (options.containsKey(kMerkmalOptionAuswahl) &&
      braucheAuswahl &&
      auswahl.isEmpty) {
    grund = 'Bitte eine Auswahl angeben.';
  }

  final tarif = merkmalGpTarif(def);
  final gpNeu = tarif?.gp(wert: ziel, auswahl: auswahl);
  final gpAlt = bisher == null
      ? 0.0
      : tarif?.gp(wert: bisher.wert, auswahl: bisher.auswahl) ?? 0.0;
  final kosten = gpNeu == null
      ? null
      : merkmalApKosten(
          gpDifferenz: gpNeu - gpAlt,
          faktor: kVorteilErwerbFaktor,
        );
  final geplant =
      options.containsKey(kMerkmalOptionWert) ||
      options.containsKey(kMerkmalOptionAuswahl);
  return AdvancementOption(
    kind: AdvancementKind.advantage,
    targetId: id,
    label: geplant
        ? merkmalTextFuer(def, auswahl: auswahl, wert: ziel)
        : def.name,
    currentValue: aktuell,
    maxValue: traegtWert ? maximum : 0,
    options: {
      ...options,
      if (geplant && ziel != null) kMerkmalOptionWert: '$ziel',
    },
    isOwned: bestehende.isNotEmpty,
    ownedCount: bestehende.length,
    apCost: kosten,
    unavailableReason: grund,
    complexityHint:
        '50 × GP-Wert ($kMerkmalSteigerungQuelle)'
        '${def.costText.trim().isEmpty ? '' : ' · ${def.costText.trim()}'}',
    requirements: [
      _hinweisBefund(
        'Nachträglicher Erwerb nur in Absprache mit dem Meister, '
        'gekoppelt an passende Eigenschaften und Zeitaufwand '
        '($kMerkmalSteigerungQuelle)',
      ),
    ],
  );
}

/// Löst den Abbau eines bestehenden Nachteils auf.
///
/// `eintrag` benennt den Nachteil über seinen Text (eindeutig, weil die
/// Projektion jeden Text nur einmal führt). `ziel` ist der neue Wert; `0`
/// oder ein Wert unter dem Katalogminimum baut den Nachteil vollständig ab.
AdvancementOption? resolveDisadvantageAdvancement(
  AdvancementContext context,
  String id,
  Map<String, String> options,
) {
  final def = MerkmalKatalog.von(context.catalog).eintrag(id, vorteil: false);
  if (def == null) return null;
  final hero = context.hero;
  final eintragText = options[kMerkmalOptionEintrag]?.trim();
  final eintrag = context.merkmalAbgleich.nachteile
      .where(
        (item) =>
            item.katalogId == id &&
            (eintragText == null || item.text.trim() == eintragText),
      )
      .firstOrNull;
  final tarif = merkmalGpTarif(def);
  final lernweg = SchlechteEigenschaftLernweg.lies(
    options[kMerkmalOptionLernweg],
  );
  final schlechteEigenschaft = istSchlechteEigenschaft(def);
  final hinweisAbbau = schlechteEigenschaft
      ? 'Je Punkt 50 × GP als Spezielle Erfahrung, 75 × GP im Selbststudium '
            '($kMerkmalSteigerungQuelle)'
      : '100 × GP-Wert ($kMerkmalSteigerungQuelle)';
  if (eintrag == null) {
    return AdvancementOption(
      kind: AdvancementKind.disadvantage,
      targetId: id,
      label: def.name,
      options: options,
      unavailableReason: 'Dieser Nachteil ist nicht (mehr) vorhanden.',
      complexityHint: hinweisAbbau,
    );
  }
  final aktuell = eintrag.wert;
  final stufenweise = tarif?.wertAbhaengig == true && aktuell != null;
  final mindest = merkmalMindestwert(def);
  var ziel =
      int.tryParse(options[kMerkmalOptionZiel] ?? '') ??
      (stufenweise ? aktuell - 1 : 0);
  if (ziel < mindest) ziel = 0;
  final gpAlt = tarif?.gp(wert: aktuell, auswahl: eintrag.auswahl);

  String? grund;
  if (kGesellschaftlicheNachteile.contains(id)) {
    grund =
        'Gesellschaftliche Nachteile werden im Spiel abgebaut, nicht mit AP '
        '($kMerkmalSteigerungQuelle)';
  } else if (gpAlt == null) {
    grund = 'Ohne GP-Wert im Katalog lassen sich keine Abbaukosten bestimmen.';
  } else if (context.merkmalAbgleich.nachteilAbweichung != null) {
    grund =
        'Eine ältere App-Version hat die Nachteile geändert; bitte zuerst im '
        'Merkmalsblatt entscheiden, welcher Stand gilt.';
  } else if (stufenweise && ziel >= aktuell) {
    grund = 'Der Zielwert muss unter dem aktuellen Wert liegen.';
  } else if (!stufenweise && ziel != 0) {
    grund = 'Dieser Nachteil kann nur vollständig abgebaut werden.';
  } else if (hero.isEpisch &&
      schlechteEigenschaft &&
      lernweg == SchlechteEigenschaftLernweg.selbststudium) {
    grund =
        'Epischer Status: Nachteile nur noch über Spezielle Erfahrungen '
        '(Epische Stufen S. 5)';
  }

  final gpNeu = ziel == 0
      ? 0.0
      : tarif?.gp(wert: ziel, auswahl: eintrag.auswahl);
  final kosten = gpAlt == null || gpNeu == null
      ? null
      : merkmalApKosten(
          gpDifferenz: gpAlt - gpNeu,
          faktor: nachteilAbbauFaktor(def, lernweg: lernweg),
        );
  final geplant = options.containsKey(kMerkmalOptionZiel);
  final zielText = ziel == 0
      ? 'abbauen'
      : '→ ${merkmalTextFuer(def, auswahl: eintrag.auswahl, wert: ziel)}';
  return AdvancementOption(
    kind: AdvancementKind.disadvantage,
    targetId: id,
    label: geplant ? '${eintrag.text} $zielText' : eintrag.text,
    currentValue: aktuell ?? 0,
    maxValue: aktuell ?? 0,
    options: {
      ...options,
      kMerkmalOptionEintrag: eintrag.text,
      if (geplant) kMerkmalOptionZiel: '$ziel',
      if (geplant && schlechteEigenschaft) kMerkmalOptionLernweg: lernweg.name,
    },
    isOwned: true,
    apCost: kosten,
    unavailableReason: grund,
    complexityHint: hinweisAbbau,
    requirements: [
      _hinweisBefund(
        'Ob ein Nachteil abgebaut werden kann, entscheidet der Meister '
        '($kMerkmalSteigerungQuelle)',
      ),
      if (hero.isEpisch)
        RequirementCheckResult(
          requirement: _hinweis('Spezielle Erfahrung'),
          status: RequirementStatus.nichtErfuellt,
          sollText: 'Episch: Abbau nur über eine Spezielle Erfahrung',
          istText: 'vom Meister zu bestätigen (Epische Stufen S. 5)',
        ),
    ],
  );
}

/// Ob eine Merkmalsoption stufenweise geplant wird (Wert statt Ganzes).
bool merkmalOptionStufenweise(RulesCatalog catalog, AdvancementOption option) {
  final def = MerkmalKatalog.von(
    catalog,
  ).eintrag(option.targetId, vorteil: option.kind == AdvancementKind.advantage);
  if (def == null) return false;
  if (option.kind == AdvancementKind.advantage) return merkmalTraegtWert(def);
  return merkmalGpTarif(def)?.wertAbhaengig == true && option.currentValue > 0;
}

/// Prüft einen geplanten Merkmalsschritt über die Optionsprüfung hinaus.
void validateTraitEntry(HeroAdvancementEntry entry, AdvancementOption option) {
  if (entry.seSpent != 0 || entry.fromValue != null || entry.toValue != null) {
    throw StateError(
      'Vor- und Nachteile verwenden keine numerischen Steigerungsschritte.',
    );
  }
  if (option.kind == AdvancementKind.disadvantage &&
      !entry.options.containsKey(kMerkmalOptionZiel)) {
    throw StateError('Bitte den Zielwert des Abbaus angeben.');
  }
  if (!alleVoraussetzungenErfuellt(option.requirements) &&
      entry.options['meisterentscheid'] != 'true') {
    throw StateError(
      'Voraussetzungen fehlen; ein ausdrücklicher Meisterentscheid ist '
      'erforderlich.',
    );
  }
}

/// Wendet einen geprüften Merkmalsschritt auf den Vorschauhelden an.
HeroSheet applyTraitEntry(
  HeroSheet hero,
  HeroAdvancementEntry entry,
  RulesCatalog catalog,
) {
  final katalog = MerkmalKatalog.von(catalog);
  final vorteil = entry.kind == AdvancementKind.advantage;
  final def = katalog.eintrag(entry.targetId, vorteil: vorteil)!;
  if (vorteil) {
    final auswahl = entry.options[kMerkmalOptionAuswahl]?.trim() ?? '';
    final wert = int.tryParse(entry.options[kMerkmalOptionWert] ?? '');
    final neu = HeroMerkmal(
      katalogId: def.id,
      text: merkmalTextFuer(def, auswahl: auswahl, wert: wert),
      wert: wert,
      auswahl: auswahl,
    );
    final braucheAuswahl = def.selectionTemplate.contains('{choice}');
    return aendereMerkmale(
      hero,
      vorteil: true,
      katalog: katalog,
      aenderung: (liste) {
        final index = liste.indexWhere(
          (eintrag) =>
              eintrag.katalogId == def.id &&
              (!braucheAuswahl || _gleicheAuswahl(eintrag.auswahl, auswahl)),
        );
        if (index < 0) return fuegeMerkmalHinzu(liste, neu, def: def);
        return [
          for (var i = 0; i < liste.length; i++)
            i == index
                ? liste[i].copyWith(wert: wert, text: neu.text)
                : liste[i],
        ];
      },
    );
  }
  final text = entry.options[kMerkmalOptionEintrag]!.trim();
  final ziel = int.parse(entry.options[kMerkmalOptionZiel]!);
  return aendereMerkmale(
    hero,
    vorteil: false,
    katalog: katalog,
    aenderung: (liste) {
      final index = liste.indexWhere((eintrag) => eintrag.text.trim() == text);
      if (index < 0) {
        throw StateError('Dieser Nachteil ist nicht (mehr) vorhanden.');
      }
      final bisher = liste[index];
      return [
        for (var i = 0; i < liste.length; i++)
          if (i != index)
            liste[i]
          else if (ziel > 0)
            bisher.copyWith(
              wert: ziel,
              text: merkmalTextFuer(def, auswahl: bisher.auswahl, wert: ziel),
            ),
      ];
    },
  );
}
