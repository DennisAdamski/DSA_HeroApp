import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';

/// Maximale Anzahl direkt gerenderter Diff-Zeilen pro Konflikt.
const int _maxVisibleRows = 50;

/// Zeigt die Feldunterschiede eines Sync-Konflikts kompakt an.
///
/// Standardmaessig eingeklappt; aufgeklappt erscheinen nur die Felder,
/// die sich zwischen lokaler und Online-Version unterscheiden.
class SyncConflictDiffView extends StatelessWidget {
  /// Erstellt eine Diff-Ansicht fuer [diff].
  const SyncConflictDiffView({super.key, required this.diff});

  /// Berechnetes Feld-Diff des Konflikts.
  final SyncObjectDiff diff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (diff.remoteMissing) {
      return const _MissingSideNote(
        text: 'Die Online-Version wurde gelöscht – kein Feldvergleich '
            'möglich.',
      );
    }
    if (diff.localMissing) {
      return const _MissingSideNote(
        text: 'Keine lokale Version vorhanden – kein Feldvergleich möglich.',
      );
    }
    if (diff.entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleEntries = diff.entries.take(_maxVisibleRows).toList();
    final hiddenCount = diff.entries.length - visibleEntries.length;
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'Unterschiede anzeigen (${diff.entries.length})',
          style: theme.textTheme.bodyMedium,
        ),
        children: [
          for (final entry in visibleEntries) _DiffEntryRow(entry: entry),
          if (hiddenCount > 0 || diff.truncated)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  diff.truncated
                      ? '… weitere Unterschiede nicht erfasst'
                      : '… und $hiddenCount weitere Unterschiede',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MissingSideNote extends StatelessWidget {
  const _MissingSideNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

class _DiffEntryRow extends StatelessWidget {
  const _DiffEntryRow({required this.entry});

  final SyncDiffEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _labelForPath(entry.path);
    final String valueText;
    switch (entry.kind) {
      case SyncDiffKind.changed:
        valueText = '${formatSyncDiffValue(entry.localValue)} '
            '→ ${formatSyncDiffValue(entry.remoteValue)}';
      case SyncDiffKind.onlyLocal:
        valueText = 'nur lokal: ${formatSyncDiffValue(entry.localValue)}';
      case SyncDiffKind.onlyRemote:
        valueText = 'nur online: ${formatSyncDiffValue(entry.remoteValue)}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              valueText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uebersetzt einen Diff-Pfad in ein lesbares deutsches Label.
///
/// Unbekannte Segmente (z.B. Talent- oder Listen-ids) bleiben unveraendert.
String _labelForPath(List<String> path) {
  return path
      .map((segment) => _fieldLabels[segment] ?? segment)
      .join(' › ');
}

/// Deutsche Labels fuer bekannte JSON-Feldnamen aus `HeroSheet.toJson()`
/// (inklusive der flach eingemischten Aussehen-/Hintergrund-Felder) und
/// `HeroState.toJson()`.
const Map<String, String> _fieldLabels = <String, String>{
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
