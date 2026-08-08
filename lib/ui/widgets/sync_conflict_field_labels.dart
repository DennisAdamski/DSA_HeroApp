/// Deutsche Anzeigenamen fuer die JSON-Feldnamen der Sync-Konflikt-Ansicht.
///
/// Ausgelagert aus der Konflikt-UI, damit die reine Datentabelle klein bleibt
/// und die Labels auch anderswo (z.B. in Tests) genutzt werden koennen.
library;

/// Uebersetzt einen Diff-Pfad in ein lesbares deutsches Label.
///
/// Unbekannte Segmente (z.B. Talent- oder Listen-ids) bleiben unveraendert,
/// die Segmente werden mit ` › ` verkettet.
String labelForSyncDiffPath(List<String> path) {
  return path.map((segment) => syncFieldLabels[segment] ?? segment).join(' › ');
}

/// Deutsche Labels fuer bekannte JSON-Feldnamen aus `HeroSheet.toJson()`
/// (inklusive der flach eingemischten Aussehen-/Hintergrund-Felder) und
/// `HeroState.toJson()`.
const Map<String, String> syncFieldLabels = <String, String>{
  // HeroSheet: Stammdaten.
  'name': 'Name',
  'level': 'Stufe',
  'attributes': 'Eigenschaften',
  'rawStartAttributes': 'Start-Eigenschaften (roh)',
  'startAttributes': 'Start-Eigenschaften',
  'persistentMods': 'Dauerhafte Modifikatoren',
  'bought': 'Gekaufte Werte',
  'combatConfig': 'Kampf-Konfiguration',
  'talents': 'Talente',
  'metaTalents': 'Meta-Talente',
  'hiddenTalentIds': 'Ausgeblendete Talente',
  'talentSpecialAbilities': 'Sonderfertigkeiten (Talente)',
  'spells': 'Zauber',
  'ritualCategories': 'Ritualkategorien',
  'representationen': 'Repräsentationen',
  'merkmalskenntnisse': 'Merkmalskenntnisse',
  'magicSpecialAbilities': 'Magische Sonderfertigkeiten',
  'magicLeadAttribute': 'Leiteigenschaft',
  'sprachen': 'Sprachen',
  'schriften': 'Schriften',
  'muttersprache': 'Muttersprache',
  'vorteileText': 'Vorteile',
  'nachteileText': 'Nachteile',
  'apTotal': 'AP gesamt',
  'apSpent': 'AP ausgegeben',
  'apAvailable': 'AP frei',
  'dukaten': 'Dukaten',
  'resourceActivationConfig': 'Ressourcen-Aktivierung',
  'inventoryEntries': 'Inventar',
  'notes': 'Notizen',
  'connections': 'Verbindungen',
  'adventures': 'Abenteuer',
  'attributeSePool': 'SE-Pool (Eigenschaften)',
  'statSePool': 'SE-Pool (Werte)',
  'companions': 'Gefährten',
  'gruppen': 'Gruppen',
  'reisebericht': 'Reisebericht',
  'statModifiers': 'Wert-Modifikatoren',
  'attributeModifiers': 'Eigenschafts-Modifikatoren',
  'unknownModifierFragments': 'Unbekannte Modifikatoren',
  'isEpisch': 'Episch',
  'epicStartAp': 'Epik: Start-AP',
  'epicAttributeMaxBonus': 'Epik: Eigenschaftsmaximum-Bonus',
  'epicMainAttributes': 'Epik: Haupteigenschaften',
  'epicActivationPolicy': 'Epik: Aktivierungsregel',
  'epicLockedWaffenmeisterCategories': 'Epik: Gesperrte Waffenmeister',
  'epicUnactivatedTalentIds': 'Epik: Nicht aktivierte Talente',
  // HeroSheet: flach eingemischte Aussehen-Felder.
  'geschlecht': 'Geschlecht',
  'alter': 'Alter',
  'groesse': 'Größe',
  'gewicht': 'Gewicht',
  'haarfarbe': 'Haarfarbe',
  'augenfarbe': 'Augenfarbe',
  'aussehen': 'Aussehen',
  'avatarFileName': 'Avatar-Datei',
  'avatarGallery': 'Avatar-Galerie',
  'primaerbildId': 'Primärbild',
  'aktivesBildId': 'Aktives Bild',
  'avatarSnapshot': 'Avatar-Snapshot',
  // HeroSheet: flach eingemischte Hintergrund-Felder.
  'rasse': 'Rasse',
  'rasseModText': 'Rasse-Modifikatoren',
  'kultur': 'Kultur',
  'kulturModText': 'Kultur-Modifikatoren',
  'profession': 'Profession',
  'professionModText': 'Professions-Modifikatoren',
  'familieHerkunftHintergrund': 'Familie & Herkunft',
  'stand': 'Stand',
  'titel': 'Titel',
  'sozialstatus': 'Sozialstatus',
  // Eigenschafts-Kuerzel (Attributes.toJson).
  'mu': 'MU',
  'kl': 'KL',
  'inn': 'IN',
  'ch': 'CH',
  'ff': 'FF',
  'ge': 'GE',
  'ko': 'KO',
  'kk': 'KK',
  // HeroState: Laufzeitwerte.
  'currentLep': 'LeP',
  'currentAsp': 'AsP',
  'currentKap': 'KaP',
  'currentAu': 'AU',
  'erschoepfung': 'Erschöpfung',
  'ueberanstrengung': 'Überanstrengung',
  'tempMods': 'Temporäre Modifikatoren',
  'tempAttributeMods': 'Temporäre Eigenschafts-Modifikatoren',
  'activeSpellEffects': 'Aktive Zaubereffekte',
  'wpiZustand': 'Wunden & Schmerz',
  'diceLog': 'Würfel-Log',
};
