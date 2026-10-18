import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/basiswert_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_requirement_context.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_profile_rules.dart';

// Empfangene Zauberwirkungen auf Kampfwerte, Proben und MR (MAG-EFF-03).
//
// Blattartig wie `spell_effect_instance_rules.dart`: liest nur Instanzen und
// Profile und liefert Beiträge, die die Basiswert- und INI-Herleitung als
// benannte Quellen aufnehmen. Gerechnet wird nur, was ein Profil belegt und
// die Instanz an Eingaben (ZfP*, ZfW) trägt; fehlt etwas, entsteht ein
// Hinweis statt einer geratenen Zahl.
//
// Belege: Liber Cantiones S. 15 (Adlerauge), S. 49 (Blitz dich find),
// S. 211 (Plumbumbarum), S. 214 (Psychostabilis).

/// Zauber-ID des Blitz dich find.
const String kBlitzZauberId = 'spell_blitz_dich_find';

/// Zauber-ID des Plumbumbarum.
const String kPlumbumbarumZauberId = 'spell_plumbumbarum_schwerer_arm';

/// Zauber-ID des Adlerauge.
const String kAdlerAugeZauberId = 'spell_adlerauge_luchsenohr';

/// Zauber-ID des Psychostabilis.
const String kPsychostabilisZauberId = 'spell_psychostabilis';

/// Zauber-ID des Karnifilo Raserei.
const String kKarnifiloZauberId = 'spell_karnifilo_raserei';

/// Zauber-ID der Seidenzunge Elfenwort.
const String kSeidenzungeZauberId = 'spell_seidenzunge_elfenwort';

/// Name des Talents, das die Seidenzunge erleichtert.
const String kUeberredenTalentName = 'Überreden';

/// Name des Talents, das das Adlerauge erleichtert. Das Regelwerk schreibt
/// „Sinnenschärfe“; der Katalog führt es als „Sinnesschärfe“ (maßgeblich, ein
/// Test sichert den Namen gegen den echten Katalog).
const String kSinnenschaerfeTalentName = 'Sinnesschärfe';

/// Einmalige, zielgebundene Zauber, die `spell_effect_event_rules.dart`
/// auswertet; hier nur für die Auswahlliste des Dialogs gespiegelt (ein Test
/// hält beide Listen gleich).
const Set<String> kEinmaligeAuswahlZauberIds = <String>{
  'spell_falkenauge_meisterschuss',
  'spell_aengste_lindern',
};

/// Schutzzauber mit Vorrat, die `spell_effect_protection_rules.dart`
/// auswertet; hier nur für die Auswahlliste gespiegelt (ein Test hält beide
/// Listen gleich).
const Set<String> kSchutzAuswahlZauberIds = <String>{
  'spell_gardianum_zauberschild',
};

/// Zauber, die dieses Modul rechnet.
const Set<String> kRechenbareZauberIds = <String>{
  kBlitzZauberId,
  kPlumbumbarumZauberId,
  kAdlerAugeZauberId,
  kPsychostabilisZauberId,
  kKarnifiloZauberId,
  kSeidenzungeZauberId,
};

/// Ein Beitrag zu Proben, der von einer laufenden Zauberwirkung stammt.
class SpellEffectProbenBeitrag {
  /// Erstellt den Beitrag; [wert] > 0 erleichtert, < 0 erschwert.
  const SpellEffectProbenBeitrag({
    required this.bezeichnung,
    required this.wert,
    this.talentName,
    this.talent = true,
    this.zauber = false,
  });

  /// Zaubername für die Anzeige.
  final String bezeichnung;

  /// Änderung der Probe (positiv = erleichtert, negativ = erschwert).
  final int wert;

  /// Nur Talentproben auf dieses Talent; `null` = unabhängig vom Talent.
  final String? talentName;

  /// Gilt für Talentproben.
  final bool talent;

  /// Gilt für Zauberproben.
  final bool zauber;
}

/// Eine Eigenschaftsänderung eines Zaubers, die **nicht** über
/// `effektiveTempAttributeMods` läuft.
///
/// Karnifilo (LC S. 136) legt AT- und PA-Basis fest; seine Eigenschaften
/// dürfen sie deshalb nicht neu berechnen. Die Änderung wirkt nur dort, wo
/// sie ausdrücklich eingerechnet wird: in den Probenwerten
/// (`wendeZauberEigenschaftenAn`), im TP/KK-Zuschlag sowie in INI- und
/// FK-Basis (Tischentscheid 18.10.2026), jeweils als eigener Schritt.
class SpellEffectEigenschaftsQuelle {
  /// Erstellt die Quelle.
  const SpellEffectEigenschaftsQuelle({
    required this.bezeichnung,
    required this.mods,
    this.quelle,
  });

  /// Zaubername für die Herleitung.
  final String bezeichnung;

  /// Änderung je Eigenschaft.
  final AttributeModifiers mods;

  /// Übergeordnete Herkunft für die Anzeige.
  final String? quelle;
}

/// Ergebnis der Kampf-Mali aller laufenden Zaubereffekte.
class SpellEffectBeitraege {
  /// Erstellt das Ergebnis.
  const SpellEffectBeitraege({
    this.statQuellen = const <StatModifikatorQuelle>[],
    this.heldenIniMalus = 0,
    this.heldenIniQuelle,
    this.fernkampfMalus = 0,
    this.fernkampfQuelle,
    this.eigenschaftsQuellen = const <SpellEffectEigenschaftsQuelle>[],
    this.athletikVerdopplungQuelle,
    this.orientierenGesperrt = false,
    this.probenBeitraege = const <SpellEffectProbenBeitrag>[],
    this.hinweise = const <String>[],
  });

  /// Erschwernis der Fernkampfproben (≤ 0), Blitz (LC S. 49). Sie wirkt auf
  /// den fertigen FK-Wert der Waffe, nicht auf die FK-Basis.
  final int fernkampfMalus;

  /// Name des Zaubers hinter [fernkampfMalus] für die Herleitung.
  final String? fernkampfQuelle;

  /// Eigenschaftsänderungen außerhalb von `effektiveTempAttributeMods`
  /// (Karnifilo), siehe [SpellEffectEigenschaftsQuelle].
  final List<SpellEffectEigenschaftsQuelle> eigenschaftsQuellen;

  /// Axxeleratus (LC S. 36): Name der Quelle, wenn der Athletik-TaW für
  /// Sprints und Sprünge verdoppelt ist; sonst `null`.
  final String? athletikVerdopplungQuelle;

  /// Summe aller [eigenschaftsQuellen].
  AttributeModifiers get eigenschaftsMods {
    var summe = const AttributeModifiers();
    for (final quelle in eigenschaftsQuellen) {
      summe = summe + quelle.mods;
    }
    return summe;
  }

  /// Beiträge zu den Basiswerten (AT-, PA-, INI-Basis), je Zauber eine Quelle.
  final List<StatModifikatorQuelle> statQuellen;

  /// Abzug auf die fertige Helden-INI (≤ 0), nicht auf die INI-Basis.
  final int heldenIniMalus;

  /// Name des Zaubers hinter [heldenIniMalus] für die Herleitung.
  final String? heldenIniQuelle;

  /// Blitz: Die Aktion „Orientieren“ ist während der Wirkung nicht möglich.
  final bool orientierenGesperrt;

  /// Beiträge zu Talent- und Zauberproben (Adlerauge, Blitz).
  final List<SpellEffectProbenBeitrag> probenBeitraege;

  /// Fehlende Eingaben, bewusst nicht gerechnete Sonderfälle und Hinweise zu
  /// Wirkungen, die die App nicht in Zahlen fasst.
  final List<String> hinweise;

  /// `true`, wenn nichts beiträgt und nichts zu melden ist.
  bool get istLeer =>
      statQuellen.isEmpty &&
      heldenIniMalus == 0 &&
      fernkampfMalus == 0 &&
      eigenschaftsQuellen.isEmpty &&
      athletikVerdopplungQuelle == null &&
      !orientierenGesperrt &&
      probenBeitraege.isEmpty &&
      hinweise.isEmpty;
}

/// Namen der Zauber hinter [SpellEffectBeitraege.eigenschaftsQuellen] für
/// eine zusammengefasste Herleitungszeile; `null` ohne Quelle.
String? zauberEigenschaftsName(SpellEffectBeitraege beitraege) {
  if (beitraege.eigenschaftsQuellen.isEmpty) {
    return null;
  }
  return beitraege.eigenschaftsQuellen.map((q) => q.bezeichnung).join(', ');
}

/// Die Eigenschaften [basis] mit den Zauber-Eigenschaftsquellen aus
/// [beitraege] (Karnifilo).
///
/// Nur für Probenwerte, TP/KK sowie INI- und FK-Basis; AT-/PA-Basis,
/// MR, GS und Ressourcen rechnen nie damit.
Attributes wendeZauberEigenschaftenAn(
  Attributes basis,
  SpellEffectBeitraege beitraege,
) {
  if (beitraege.eigenschaftsQuellen.isEmpty) {
    return basis;
  }
  return applyAttributeModifiers(basis, beitraege.eigenschaftsMods);
}

/// Ob der Held die Sonderfertigkeit Blindkampf beherrscht.
///
/// Kampf-SF stehen nur als Katalog-ID am Helden und werden deshalb über den
/// Katalog aufgelöst; ohne Katalog gilt `false`.
bool heldKenntBlindkampf(HeroSheet held, RulesCatalog? katalog) {
  return heroSpecialAbilityNames(
    held,
    catalog: katalog,
  ).any((name) => name.trim().toLowerCase() == 'blindkampf');
}

/// Ob der Held die Sonderfertigkeit Konzentrationsstärke beherrscht.
bool heldKenntKonzentrationsstaerke(HeroSheet held, RulesCatalog? katalog) {
  return heroSpecialAbilityNames(
    held,
    catalog: katalog,
  ).any((name) => name.trim().toLowerCase().startsWith('konzentrationsstärke'));
}

/// Wie [berechneSpellEffectBeitraege], liest die Sonderfertigkeiten des
/// Helden (Blindkampf, Konzentrationsstärke) und den laufenden Axxeleratus
/// (auch den alten Schalter der Kampfeinstellungen) selbst. Der übliche
/// Einstieg.
SpellEffectBeitraege berechneSpellEffectBeitraegeFuerHeld({
  required HeroSheet held,
  required HeroState zustand,
  required RulesCatalog? katalog,
}) {
  return berechneSpellEffectBeitraege(
    zustand: zustand,
    katalog: katalog,
    blindkampf: heldKenntBlindkampf(held, katalog),
    konzentrationsstaerke: heldKenntKonzentrationsstaerke(held, katalog),
    axxeleratus: isAxxeleratusEffectActive(sheet: held, state: zustand),
  );
}

/// Quellname der Athletik-Verdopplung durch Axxeleratus.
const String kAxxeleratusAthletikQuelle = 'Axxeleratus';

/// Rechnet die empfangenen Wirkungen der laufenden Zaubereffekte.
///
/// - **Blitz** (LC S. 49): ZfP* gleichmäßig von AT- und PA-Basis abziehen, bei
///   ungeradem ZfP* zuerst von der Attacke; Helden-INI −ZfW; Orientieren
///   gesperrt. Mit der SF Blindkampf halbieren sich die Abzüge — die Rundung
///   steht nicht im Regelwerk, deshalb rechnet die App dann **nicht**
///   automatisch, sondern meldet einen Hinweis ([blindkampf]).
///   Außerdem sind Talent-, Zauber- und Fernkampfproben um ZfP* erschwert:
///   Talent- und Zauberproben über [probenBeitraege], den Fernkampf über
///   [SpellEffectBeitraege.fernkampfMalus] im FK-Wert der Waffe.
///   Konzentrationsstärke halbiert die Abzüge auf **Zauberproben** (Rundung
///   nicht belegt → Hinweis statt Zahl).
/// - **Karnifilo** (LC S. 136): AT-Basis +5, PA-Basis −5 fest; MU/KK +5 und
///   KL/CH −5 als [SpellEffectEigenschaftsQuelle] (nicht über
///   `effektiveTempAttributeMods`, damit AT/PA nicht neu gerechnet werden).
/// - **Axxeleratus** ([axxeleratus], LC S. 36): Athletik-TaW für Sprints und
///   Sprünge verdoppelt; als bedingter Probenschritt, nie pauschal.
/// - **Plumbumbarum** (LC S. 211): AT-Basis und INI-**Basis** je −ZfP*; keine
///   PA. Die Demotivationsvariante ist nicht umgesetzt.
/// - **Adlerauge** (LC S. 15): Proben auf Sinnenschärfe um ZfP* erleichtert;
///   keine Nachtsicht. Die Einzelsinn-Variante ist nicht umgesetzt.
/// - **Psychostabilis** (LC S. 214): MR +ZfP*; gegen geistig wirkende Zauber
///   mit den Merkmalen Einfluss, Hellsicht, Herrschaft und Verständigung
///   zusätzlich +2 (als Hinweis, nicht in der MR).
///
/// Tischregel (15.10.2026, gilt für Zauber mit Einfluss): wirken mehrere
/// Quellen desselben Zaubers, zählt nur die stärkste (größtes ZfP*, bei
/// Gleichstand die erste); verschiedene Zauber addieren sich. Unterdrückte
/// Instanzen zählen nicht. Ohne Katalog oder ohne automatisierbares Profil
/// entsteht kein Beitrag.
SpellEffectBeitraege berechneSpellEffectBeitraege({
  required HeroState zustand,
  required RulesCatalog? katalog,
  bool blindkampf = false,
  bool konzentrationsstaerke = false,
  bool axxeleratus = false,
}) {
  final athletikQuelle = axxeleratus ? kAxxeleratusAthletikQuelle : null;
  if (katalog == null) {
    return SpellEffectBeitraege(athletikVerdopplungQuelle: athletikQuelle);
  }
  final quellen = <StatModifikatorQuelle>[];
  final eigenschaften = <SpellEffectEigenschaftsQuelle>[];
  final hinweise = <String>[];
  final proben = <SpellEffectProbenBeitrag>[];
  var iniMalus = 0;
  String? iniQuelle;
  var fkMalus = 0;
  String? fkQuelle;
  var orientieren = false;

  for (final zauberId in kRechenbareZauberIds) {
    final stark = _staerksteInstanz(zustand, zauberId);
    if (stark == null || !_istAutomatisiert(katalog, zauberId)) {
      continue;
    }
    final name = _zauberName(katalog, zauberId);
    final zfp = stark.zfpStern;
    if (zfp == null) {
      hinweise.add('$name: ZfP* fehlt – keine Wirkung gerechnet.');
      continue;
    }
    final staerke = zfp < 0 ? 0 : zfp;
    switch (zauberId) {
      case kBlitzZauberId:
        orientieren = true;
        if (blindkampf) {
          hinweise.add(
            '$name: Blindkampf halbiert die Abzüge; die Rundung ist im '
            'Regelwerk nicht belegt – Abzüge auf AT, PA, INI, Fernkampf und '
            'Proben bitte manuell eintragen.',
          );
          break;
        }
        if (staerke > 0) {
          proben.add(
            SpellEffectProbenBeitrag(bezeichnung: name, wert: -staerke),
          );
          if (konzentrationsstaerke) {
            hinweise.add(
              '$name: Konzentrationsstärke halbiert die Abzüge auf '
              'Zauberproben; die Rundung ist nicht belegt – Zauberproben '
              'bitte manuell anpassen.',
            );
          } else {
            proben.add(
              SpellEffectProbenBeitrag(
                bezeichnung: name,
                wert: -staerke,
                talent: false,
                zauber: true,
              ),
            );
          }
          // „Fernkampf um … ZfP* Punkte erschwert“: im FK-Wert der Waffe.
          fkMalus -= staerke;
          fkQuelle = name;
        }
        final zfw = stark.zfw;
        // Ungerades ZfP*: der Rest geht zuerst an die Attacke.
        final atAnteil = (staerke + 1) ~/ 2;
        final paAnteil = staerke ~/ 2;
        quellen.add(
          StatModifikatorQuelle(
            bezeichnung: name,
            mods: StatModifiers(at: -atAnteil, pa: -paAnteil),
            quelle: 'Zaubereffekt (ZfP* $staerke gleichmäßig auf AT/PA)',
          ),
        );
        if (zfw == null) {
          hinweise.add('$name: ZfW fehlt – INI-Abzug nicht gerechnet.');
        } else {
          iniMalus -= zfw < 0 ? 0 : zfw;
          iniQuelle = name;
        }
      case kPlumbumbarumZauberId:
        quellen.add(
          StatModifikatorQuelle(
            bezeichnung: name,
            mods: StatModifiers(at: -staerke, iniBase: -staerke),
            quelle: 'Zaubereffekt (ZfP* $staerke)',
          ),
        );
      case kAdlerAugeZauberId:
        if (staerke > 0) {
          proben.add(
            SpellEffectProbenBeitrag(
              bezeichnung: name,
              wert: staerke,
              talentName: kSinnenschaerfeTalentName,
            ),
          );
        }
      case kKarnifiloZauberId:
        // Feste Zahlen (LC S. 136): AT-Basis +5, PA-Basis −5. Sie ersetzen die
        // Neuberechnung aus den veränderten Eigenschaften.
        quellen.add(
          StatModifikatorQuelle(
            bezeichnung: name,
            mods: const StatModifiers(at: 5, pa: -5),
            quelle: 'Zaubereffekt (Kampfrausch, fest laut Regelwerk)',
          ),
        );
        // MU/KK +5, KL/CH −5 nur für Proben, TP/KK, INI- und FK-Basis
        // (Tischentscheid 18.10.2026); AT/PA bleiben bei den festen Zahlen.
        eigenschaften.add(
          SpellEffectEigenschaftsQuelle(
            bezeichnung: name,
            mods: const AttributeModifiers(mu: 5, kk: 5, kl: -5, ch: -5),
            quelle: 'Zaubereffekt (Kampfrausch)',
          ),
        );
        hinweise
          ..add(
            '$name: MU +5, KK +5, KL −5 und CH −5 gelten für Proben, den '
            'TP/KK-Zuschlag sowie INI- und FK-Basis. AT und PA werden daraus '
            'nicht neu berechnet; MR, GS, LeP/AuP und Wundschwelle bleiben '
            'unverändert.',
          )
          ..add(
            '$name: erlaubt sind nur gewöhnliche AT/PA sowie Ausweichen, '
            'Befreiungsschlag, Hammerschlag, Niederwerfen, Schildparade, '
            'Sturmangriff und Wuchtschlag. Wunden und LeP-/AuP-Verlust '
            'behindern den Rasenden nicht (keine AT/PA-Einbußen durch '
            'Wunden). Danach AuP 0 und ZfP*/2 Erschöpfung; sind alle Gegner '
            'besiegt, greift er Gefährten an.',
          );
      case kSeidenzungeZauberId:
        // Der Meister darf Überreden-Proben um ZfP* erleichtern (LC S. 237);
        // der Wert ist ein Startwert im Probendialog.
        if (staerke > 0) {
          proben.add(
            SpellEffectProbenBeitrag(
              bezeichnung: name,
              wert: staerke,
              talentName: kUeberredenTalentName,
            ),
          );
        }
        hinweise.add(
          '$name: Erleichterung von Überreden um ZfP* nach Meisterentscheid; '
          'bei zu dick aufgetragenen Lügen kann sie entfallen.',
        );
      case kPsychostabilisZauberId:
        quellen.add(
          StatModifikatorQuelle(
            bezeichnung: name,
            mods: StatModifiers(mr: staerke),
            quelle: 'Zaubereffekt (ZfP* $staerke)',
          ),
        );
        hinweise.add(
          '$name: gegen Zauber mit den Merkmalen Einfluss, Hellsicht, '
          'Herrschaft und Verständigung zusätzlich MR +2 (nicht in der MR '
          'enthalten).',
        );
    }
  }
  return SpellEffectBeitraege(
    statQuellen: List<StatModifikatorQuelle>.unmodifiable(quellen),
    heldenIniMalus: iniMalus,
    heldenIniQuelle: iniQuelle,
    fernkampfMalus: fkMalus,
    fernkampfQuelle: fkQuelle,
    eigenschaftsQuellen: List<SpellEffectEigenschaftsQuelle>.unmodifiable(
      eigenschaften,
    ),
    athletikVerdopplungQuelle: athletikQuelle,
    orientierenGesperrt: orientieren,
    probenBeitraege: List<SpellEffectProbenBeitrag>.unmodifiable(proben),
    hinweise: List<String>.unmodifiable(hinweise),
  );
}

/// Die stärkste nicht unterdrückte Instanz des Zaubers [zauberId].
SpellEffectInstance? _staerksteInstanz(HeroState zustand, String zauberId) {
  SpellEffectInstance? beste;
  for (final instanz in zustand.activeSpellEffects.instanzen) {
    if (instanz.effectId != zauberId || instanz.unterdrueckt) {
      continue;
    }
    if (beste == null || (instanz.zfpStern ?? -1) > (beste.zfpStern ?? -1)) {
      beste = instanz;
    }
  }
  return beste;
}

bool _istAutomatisiert(RulesCatalog katalog, String zauberId) {
  return profileFuerZauber(katalog, zauberId).any(istAutomatisiert);
}

String _zauberName(RulesCatalog katalog, String zauberId) {
  for (final zauber in katalog.spells) {
    if (zauber.id == zauberId) {
      return zauber.name;
    }
  }
  return zauberId;
}

/// Ein Zauber, für den der Nutzer eine Wirkungsquelle anlegen darf.
class SpellEffectKatalogEintrag {
  /// Erstellt den Eintrag.
  const SpellEffectKatalogEintrag({
    required this.zauberId,
    required this.name,
    required this.benoetigtZfw,
    required this.hinweis,
    this.benoetigtZiel = false,
    this.benoetigtSchutzvorrat = false,
    this.benoetigtDauerAsp = false,
  });

  /// Ob die Dauer „nach AsP“ vorausbezahlt wird (Psychostabilis, LC S. 214).
  final bool benoetigtDauerAsp;

  /// Ob das Profil ein festgelegtes Ziel verlangt (Falkenauge).
  final bool benoetigtZiel;

  /// Ob die Wirkung einen Schutzvorrat aus AsP und ZfP* bildet (Gardianum).
  final bool benoetigtSchutzvorrat;

  /// Katalog-ID des Zaubers.
  final String zauberId;

  /// Anzeigename.
  final String name;

  /// Ob das Profil das ZfW des Zaubernden verlangt.
  final bool benoetigtZfw;

  /// Kurzer Hinweis aus dem Profil.
  final String hinweis;
}

/// Zauber, deren Wirkung die App rechnet und die der Nutzer als Quelle
/// hinzufügen kann: automatisierbare Profile aus [kRechenbareZauberIds].
List<SpellEffectKatalogEintrag> spellEffectAuswahl(RulesCatalog katalog) {
  final eintraege = <SpellEffectKatalogEintrag>[];
  for (final profil in katalog.spellEffects) {
    if (!istRechenbaresProfil(profil)) {
      continue;
    }
    eintraege.add(
      SpellEffectKatalogEintrag(
        zauberId: profil.spellId,
        name: _zauberName(katalog, profil.spellId),
        benoetigtZfw: profil.eingaben.contains('zfw'),
        benoetigtZiel: profil.eingaben.contains('ziel'),
        benoetigtSchutzvorrat: kSchutzAuswahlZauberIds.contains(profil.spellId),
        benoetigtDauerAsp: profil.eingaben.contains('asp'),
        hinweis: profil.hinweis,
      ),
    );
  }
  return List<SpellEffectKatalogEintrag>.unmodifiable(eintraege);
}

/// Profile, deren Instanzen dieses Modul in Zahlen umsetzt.
bool istRechenbaresProfil(SpellEffectProfile profil) =>
    (kRechenbareZauberIds.contains(profil.spellId) ||
        kEinmaligeAuswahlZauberIds.contains(profil.spellId) ||
        kSchutzAuswahlZauberIds.contains(profil.spellId)) &&
    istAutomatisiert(profil);
