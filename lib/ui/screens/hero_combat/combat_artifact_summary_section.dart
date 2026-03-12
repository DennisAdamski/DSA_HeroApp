part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Kompakte, aufklappbare Zusammenfassung aller aktuell relevanten Artefakte.
extension _CombatArtifactSummarySection on _HeroCombatTabState {
  Widget? _buildCombatArtifactSummaryCard({
    required MainWeaponSlot? offhandWeapon,
    required OffhandEquipmentEntry? offhandEquipment,
  }) {
    final mainhandEntries = <_ArtifactSummaryEntry>[];
    final offhandEntries = <_ArtifactSummaryEntry>[];
    final armorEntries = <_ArtifactSummaryEntry>[];

    final mainhandWeapon = _draftCombatConfig.selectedWeaponOrNull;
    final mainhandArtifact = _artifactEntryForWeapon(
      weapon: mainhandWeapon,
      sectionLabel: 'Haupthand',
      entryType: null,
      fallbackLabel: 'Waffe',
    );
    if (mainhandArtifact != null) {
      mainhandEntries.add(mainhandArtifact);
    }

    final offhandWeaponArtifact = _artifactEntryForWeapon(
      weapon: offhandWeapon,
      sectionLabel: 'Nebenhand',
      entryType: 'Waffe',
      fallbackLabel: 'Waffe',
    );
    if (offhandWeaponArtifact != null) {
      offhandEntries.add(offhandWeaponArtifact);
    }

    final offhandEquipmentArtifact = _artifactEntryForEquipment(
      equipment: offhandEquipment,
    );
    if (offhandEquipmentArtifact != null) {
      offhandEntries.add(offhandEquipmentArtifact);
    }

    for (final piece in _draftCombatConfig.armor.pieces) {
      final armorArtifact = _artifactEntryForArmor(piece);
      if (armorArtifact != null) {
        armorEntries.add(armorArtifact);
      }
    }

    final hasEntries =
        mainhandEntries.isNotEmpty ||
        offhandEntries.isNotEmpty ||
        armorEntries.isNotEmpty;
    if (!hasEntries) {
      return null;
    }

    final totalEntries =
        mainhandEntries.length + offhandEntries.length + armorEntries.length;
    final subtitle = totalEntries == 1
        ? '1 aktiver Artefakteintrag'
        : '$totalEntries aktive Artefakteinträge';

    return Card(
      key: const ValueKey<String>('combat-artifact-summary-card'),
      child: ExpansionTile(
        key: const ValueKey<String>('combat-artifact-summary-tile'),
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          'Artefakte',
          key: const ValueKey<String>('combat-artifact-summary-title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          subtitle,
          key: const ValueKey<String>('combat-artifact-summary-subtitle'),
        ),
        children: [
          if (mainhandEntries.isNotEmpty)
            _buildArtifactSummaryGroup(
              keyName: 'combat-artifact-summary-group-mainhand',
              title: 'Haupthand',
              entries: mainhandEntries,
            ),
          if (offhandEntries.isNotEmpty)
            _buildArtifactSummaryGroup(
              keyName: 'combat-artifact-summary-group-offhand',
              title: 'Nebenhand',
              entries: offhandEntries,
            ),
          if (armorEntries.isNotEmpty)
            _buildArtifactSummaryGroup(
              keyName: 'combat-artifact-summary-group-armor',
              title: 'Rüstung',
              entries: armorEntries,
            ),
        ],
      ),
    );
  }

  /// Baut einen kompakten Abschnitt für eine Artefaktgruppe.
  Widget _buildArtifactSummaryGroup({
    required String keyName,
    required String title,
    required List<_ArtifactSummaryEntry> entries,
  }) {
    return Padding(
      key: ValueKey<String>(keyName),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...entries.map(_buildArtifactSummaryEntry),
        ],
      ),
    );
  }

  /// Rendert einen einzelnen Artefakt-Eintrag kompakt mit Typ und Beschreibung.
  Widget _buildArtifactSummaryEntry(_ArtifactSummaryEntry entry) {
    final metaParts = <String>[
      if (entry.entryType != null) entry.entryType!,
    ];
    final metaText = metaParts.join(' • ');

    return Padding(
      key: ValueKey<String>(entry.keyName),
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (metaText.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(metaText, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 4),
              Text(entry.description),
            ],
          ),
        ),
      ),
    );
  }

  /// Erzeugt einen Artefakt-Eintrag für eine Waffe, falls er angezeigt werden soll.
  _ArtifactSummaryEntry? _artifactEntryForWeapon({
    required MainWeaponSlot? weapon,
    required String sectionLabel,
    required String? entryType,
    required String fallbackLabel,
  }) {
    if (weapon == null || !weapon.isArtifact) {
      return null;
    }
    final description = weapon.artifactDescription.trim();
    if (description.isEmpty) {
      return null;
    }
    final label = weapon.name.trim().isEmpty ? fallbackLabel : weapon.name.trim();
    return _ArtifactSummaryEntry(
      keyName:
          'combat-artifact-summary-entry-${sectionLabel.toLowerCase()}-${_normalizeArtifactKey(label)}',
      label: label,
      entryType: entryType,
      description: description,
    );
  }

  /// Erzeugt einen Artefakt-Eintrag für Schild oder Parierwaffe.
  _ArtifactSummaryEntry? _artifactEntryForEquipment({
    required OffhandEquipmentEntry? equipment,
  }) {
    if (equipment == null || !equipment.isArtifact) {
      return null;
    }
    final description = equipment.artifactDescription.trim();
    if (description.isEmpty) {
      return null;
    }
    final label = equipment.name.trim().isEmpty
        ? (equipment.isShield ? 'Schild' : 'Parierwaffe')
        : equipment.name.trim();
    return _ArtifactSummaryEntry(
      keyName:
          'combat-artifact-summary-entry-offhand-${_normalizeArtifactKey(label)}',
      label: label,
      entryType: equipment.isShield ? 'Schild' : 'Parierwaffe',
      description: description,
    );
  }

  /// Erzeugt einen Artefakt-Eintrag für ein aktives Rüstungsteil.
  _ArtifactSummaryEntry? _artifactEntryForArmor(ArmorPiece piece) {
    if (!piece.isActive || !piece.isArtifact) {
      return null;
    }
    final description = piece.artifactDescription.trim();
    if (description.isEmpty) {
      return null;
    }
    final label = piece.name.trim().isEmpty ? 'Rüstungsteil' : piece.name.trim();
    return _ArtifactSummaryEntry(
      keyName:
          'combat-artifact-summary-entry-armor-${_normalizeArtifactKey(label)}',
      label: label,
      entryType: 'Rüstung',
      description: description,
    );
  }

  /// Normalisiert Schlüsselteile für stabile Widget-Keys.
  String _normalizeArtifactKey(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }
}

/// Beschreibt einen einzelnen, in der Vorschau angezeigten Artefakt-Eintrag.
class _ArtifactSummaryEntry {
  const _ArtifactSummaryEntry({
    required this.keyName,
    required this.label,
    required this.entryType,
    required this.description,
  });

  final String keyName;
  final String label;
  final String? entryType;
  final String description;
}
