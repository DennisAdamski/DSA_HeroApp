import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/basiswert_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_requirement_context.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_profile_rules.dart';

// Empfangene Kampf-Mali durch Zauber (MAG-EFF-03).
//
// Blattartig wie `spell_effect_instance_rules.dart`: liest nur Instanzen und
// Profile und liefert Beiträge, die die Basiswert- und INI-Herleitung als
// benannte Quellen aufnehmen. Gerechnet wird nur, was ein Profil belegt und
// die Instanz an Eingaben (ZfP*, ZfW) trägt; fehlt etwas, entsteht ein
// Hinweis statt einer geratenen Zahl.
//
// Belege: Liber Cantiones S. 49 (Blitz dich find), S. 211 (Plumbumbarum).

/// Zauber-ID des Blitz dich find.
const String kBlitzZauberId = 'spell_blitz_dich_find';

/// Zauber-ID des Plumbumbarum.
const String kPlumbumbarumZauberId = 'spell_plumbumbarum_schwerer_arm';

/// Kampf-Zauber, die dieses Modul rechnet.
const Set<String> kKampfMaliZauberIds = <String>{
  kBlitzZauberId,
  kPlumbumbarumZauberId,
};

/// Ergebnis der Kampf-Mali aller laufenden Zaubereffekte.
class SpellEffectKampfBeitraege {
  /// Erstellt das Ergebnis.
  const SpellEffectKampfBeitraege({
    this.statQuellen = const <StatModifikatorQuelle>[],
    this.heldenIniMalus = 0,
    this.heldenIniQuelle,
    this.orientierenGesperrt = false,
    this.hinweise = const <String>[],
  });

  /// Beiträge zu den Basiswerten (AT-, PA-, INI-Basis), je Zauber eine Quelle.
  final List<StatModifikatorQuelle> statQuellen;

  /// Abzug auf die fertige Helden-INI (≤ 0), nicht auf die INI-Basis.
  final int heldenIniMalus;

  /// Name des Zaubers hinter [heldenIniMalus] für die Herleitung.
  final String? heldenIniQuelle;

  /// Blitz: Die Aktion „Orientieren“ ist während der Wirkung nicht möglich.
  final bool orientierenGesperrt;

  /// Fehlende Eingaben und bewusst nicht gerechnete Sonderfälle.
  final List<String> hinweise;

  /// `true`, wenn nichts beiträgt und nichts zu melden ist.
  bool get istLeer =>
      statQuellen.isEmpty &&
      heldenIniMalus == 0 &&
      !orientierenGesperrt &&
      hinweise.isEmpty;
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

/// Rechnet die empfangenen Kampf-Mali der laufenden Zaubereffekte.
///
/// - **Blitz** (LC S. 49): ZfP* gleichmäßig von AT- und PA-Basis abziehen, bei
///   ungeradem ZfP* zuerst von der Attacke; Helden-INI −ZfW; Orientieren
///   gesperrt. Mit der SF Blindkampf halbieren sich die Abzüge — die Rundung
///   steht nicht im Regelwerk, deshalb rechnet die App dann **nicht**
///   automatisch, sondern meldet einen Hinweis ([blindkampf]).
/// - **Plumbumbarum** (LC S. 211): AT-Basis und INI-**Basis** je −ZfP*; keine
///   PA. Die Demotivationsvariante ist nicht umgesetzt.
///
/// Tischregel (15.10.2026, gilt für Zauber mit Einfluss): wirken mehrere
/// Quellen desselben Zaubers, zählt nur die stärkste (größtes ZfP*, bei
/// Gleichstand die erste); verschiedene Zauber addieren sich. Unterdrückte
/// Instanzen zählen nicht. Ohne Katalog oder ohne automatisierbares Profil
/// entsteht kein Beitrag.
SpellEffectKampfBeitraege berechneSpellEffectKampfBeitraege({
  required HeroState zustand,
  required RulesCatalog? katalog,
  bool blindkampf = false,
}) {
  if (katalog == null) {
    return const SpellEffectKampfBeitraege();
  }
  final quellen = <StatModifikatorQuelle>[];
  final hinweise = <String>[];
  var iniMalus = 0;
  String? iniQuelle;
  var orientieren = false;

  for (final zauberId in kKampfMaliZauberIds) {
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
            'Regelwerk nicht belegt – Abzüge auf AT, PA und INI bitte '
            'manuell eintragen.',
          );
          break;
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
    }
  }
  return SpellEffectKampfBeitraege(
    statQuellen: List<StatModifikatorQuelle>.unmodifiable(quellen),
    heldenIniMalus: iniMalus,
    heldenIniQuelle: iniQuelle,
    orientierenGesperrt: orientieren,
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
  });

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
/// hinzufügen kann: automatisierbare Profile mit Kampf-Mali.
List<SpellEffectKatalogEintrag> spellEffectAuswahl(RulesCatalog katalog) {
  final eintraege = <SpellEffectKatalogEintrag>[];
  for (final profil in katalog.spellEffects) {
    if (!istKampfMaliProfil(profil)) {
      continue;
    }
    eintraege.add(
      SpellEffectKatalogEintrag(
        zauberId: profil.spellId,
        name: _zauberName(katalog, profil.spellId),
        benoetigtZfw: profil.eingaben.contains('zfw'),
        hinweis: profil.hinweis,
      ),
    );
  }
  return List<SpellEffectKatalogEintrag>.unmodifiable(eintraege);
}

/// Profile, deren Instanzen dieses Modul in Kampfwerte umsetzt.
bool istKampfMaliProfil(SpellEffectProfile profil) =>
    kKampfMaliZauberIds.contains(profil.spellId) && istAutomatisiert(profil);
