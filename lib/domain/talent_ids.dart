/// Zentrale IDs haeufig referenzierter Talente (Katalog-Schluessel aus
/// `assets/catalogs/house_rules_v1/talente.json`).
///
/// Benannt sind nur Talente, die in Regel- oder UI-Logik direkt referenziert
/// werden. Die uebrigen Default-Talente stehen als Literale in
/// [kDefaultTalentIds].
abstract final class TalentIds {
  static const String armbrust = 'tal_armbrust';
  static const String dolche = 'tal_dolche';
  static const String fechtwaffen = 'tal_fechtwaffen';
  static const String pflanzenkunde = 'tal_pflanzenkunde';
  static const String saebel = 'tal_saebel';
  static const String selbstbeherrschung = 'tal_selbstbeherrschung';
  static const String sinnesschaerfe = 'tal_sinnesschaerfe';
  static const String wildnisleben = 'tal_wildnisleben';
}

/// Talente, die jeder neu angelegte Held standardmaessig aktiviert erhaelt.
const Set<String> kDefaultTalentIds = <String>{
  TalentIds.dolche,
  'tal_hiebwaffen',
  'tal_raufen',
  'tal_ringen',
  TalentIds.saebel,
  'tal_wurfmesser',
  'tal_athletik',
  'tal_klettern',
  'tal_koerperbeherrschung',
  'tal_schleichen',
  'tal_schwimmen',
  TalentIds.selbstbeherrschung,
  'tal_sich_verstecken',
  'tal_singen',
  TalentIds.sinnesschaerfe,
  'tal_tanzen',
  'tal_zechen',
  'tal_menschenkenntnis',
  'tal_ueberreden',
  'tal_faehrtensuchen',
  'tal_orientierung',
  TalentIds.wildnisleben,
  'tal_goetter_kulte',
  'tal_rechnen',
  'tal_sagen_legenden',
  'tal_heilkunde_wunden',
  'tal_holzbearbeitung',
  'tal_kochen',
  'tal_lederarbeiten',
  'tal_malen_zeichnen',
  'tal_schneidern',
  TalentIds.pflanzenkunde,
};
