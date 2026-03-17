import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_magic_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_begleiter_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_notes_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

/// Stabile IDs fuer Workspace-Tabs.
abstract final class WorkspaceTabIds {
  /// ID des Uebersicht-Tabs.
  static const String overview = 'overview';

  /// ID des Talente-Tabs.
  static const String talents = 'talents';

  /// ID des Kampf-Tabs.
  static const String combat = 'combat';

  /// ID des Magie-Tabs.
  static const String magic = 'magic';

  /// ID des Inventar-Tabs.
  static const String inventory = 'inventory';

  /// ID des Notizen-Tabs.
  static const String notes = 'notes';

  /// ID des Begleiter-Tabs.
  static const String begleiter = 'begleiter';
}

/// Callback-Buendel fuer Dirty-/Edit-Integration eines Workspace-Tabs.
class WorkspaceTabCallbacks {
  /// Erstellt die Callbacks, die ein Tab an seinen Host meldet.
  const WorkspaceTabCallbacks({
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  /// Meldet, ob der Tab ungespeicherte Aenderungen besitzt.
  final ValueChanged<bool> onDirtyChanged;

  /// Meldet, ob der Tab sich im Editiermodus befindet.
  final ValueChanged<bool> onEditingChanged;

  /// Registriert die Verwerfen-Aktion des Tabs beim Host.
  final ValueChanged<WorkspaceAsyncAction> onRegisterDiscard;

  /// Registriert die Edit-Aktionen des Tabs beim Host.
  final ValueChanged<WorkspaceTabEditActions> onRegisterEditActions;
}

/// Baut den Inhalt eines einzelnen Workspace-Tabs.
typedef WorkspaceTabContentBuilder =
    Widget Function({
      required String heroId,
      required WorkspaceTabCallbacks callbacks,
    });

/// Baut optionale Header-Aktionen fuer einen Workspace-Tab.
typedef WorkspaceTabHeaderActionsBuilder =
    List<WorkspaceHeaderAction> Function({
      required BuildContext context,
      required WidgetRef ref,
      required String heroId,
      required bool isCompactLayout,
    });

/// Prueft, ob ein Tab fuer den aktuellen Helden sichtbar sein soll.
typedef WorkspaceTabVisibilityPredicate = bool Function(HeroSheet hero);

/// Zentrale Definition eines Workspace-Tabs.
class WorkspaceTabSpec {
  /// Erstellt eine vollstaendige Workspace-Tab-Definition.
  const WorkspaceTabSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.helper,
    required this.buildContent,
    this.isEditable = true,
    this.useCompactIconOnlyEditActions = false,
    this.isVisible = _alwaysVisible,
    this.buildHeaderActions = _buildNoHeaderActions,
  });

  /// Stabiler Schluessel fuer Dirty-, Edit- und Navigationszustand.
  final String id;

  /// Anzeige-Label des Tabs.
  final String label;

  /// Icon des Tabs in Navigationen.
  final IconData icon;

  /// Kurzbeschreibung fuer Navigation und Inspector.
  final String helper;

  /// Gibt an, ob der Tab grundsaetzlich editierbar ist.
  final bool isEditable;

  /// Aktiviert kompakte Icon-Only-Edit-Aktionen fuer kleine Layouts.
  final bool useCompactIconOnlyEditActions;

  /// Definiert, ob der Tab fuer einen Helden angezeigt wird.
  final WorkspaceTabVisibilityPredicate isVisible;

  /// Baut den eigentlichen Tab-Inhalt.
  final WorkspaceTabContentBuilder buildContent;

  /// Baut zusaetzliche Header-Aktionen des Tabs.
  final WorkspaceTabHeaderActionsBuilder buildHeaderActions;
}

/// Erstellt die zentrale Liste aller Workspace-Tabs in ihrer Basisreihenfolge.
List<WorkspaceTabSpec> buildWorkspaceTabs({
  required String heroId,
  required WorkspaceTabCallbacks Function(String tabId) callbacksForTab,
}) {
  return <WorkspaceTabSpec>[
    WorkspaceTabSpec(
      id: WorkspaceTabIds.overview,
      label: 'Übersicht',
      icon: Icons.dashboard_outlined,
      helper: 'Vitalwerte, Statuswerte und aktive Effekte',
      buildContent: ({required heroId, required callbacks}) => HeroOverviewTab(
        heroId: heroId,
        onDirtyChanged: callbacks.onDirtyChanged,
        onEditingChanged: callbacks.onEditingChanged,
        onRegisterDiscard: callbacks.onRegisterDiscard,
        onRegisterEditActions: callbacks.onRegisterEditActions,
      ),
    ),
    WorkspaceTabSpec(
      id: WorkspaceTabIds.talents,
      label: 'Talente',
      icon: Icons.auto_stories_outlined,
      helper: 'Talentwerte und Spezialisierungen',
      useCompactIconOnlyEditActions: true,
      buildContent: ({required heroId, required callbacks}) => HeroTalentsTab(
        heroId: heroId,
        showInlineActions: false,
        onDirtyChanged: callbacks.onDirtyChanged,
        onEditingChanged: callbacks.onEditingChanged,
        onRegisterDiscard: callbacks.onRegisterDiscard,
        onRegisterEditActions: callbacks.onRegisterEditActions,
      ),
      buildHeaderActions: _buildTalentsHeaderActions,
    ),
    WorkspaceTabSpec(
      id: WorkspaceTabIds.combat,
      label: 'Kampf',
      icon: Icons.sports_martial_arts_outlined,
      helper: 'Kampftechniken, Nahkampf, Sonderfertigkeiten, Manoever',
      buildContent: ({required heroId, required callbacks}) => HeroCombatTab(
        heroId: heroId,
        showInlineCombatTalentsActions: false,
        onDirtyChanged: callbacks.onDirtyChanged,
        onEditingChanged: callbacks.onEditingChanged,
        onRegisterDiscard: callbacks.onRegisterDiscard,
        onRegisterEditActions: callbacks.onRegisterEditActions,
      ),
    ),
    WorkspaceTabSpec(
      id: WorkspaceTabIds.magic,
      label: 'Magie',
      icon: Icons.bolt_outlined,
      helper: 'Katalogansicht fuer Zauber',
      buildContent: ({required heroId, required callbacks}) => HeroMagicTab(
        heroId: heroId,
        onDirtyChanged: callbacks.onDirtyChanged,
        onEditingChanged: callbacks.onEditingChanged,
        onRegisterDiscard: callbacks.onRegisterDiscard,
        onRegisterEditActions: callbacks.onRegisterEditActions,
      ),
    ),
    WorkspaceTabSpec(
      id: WorkspaceTabIds.inventory,
      label: 'Inventar',
      icon: Icons.inventory_2_outlined,
      helper: 'Ausruestung und Gegenstaende',
      buildContent: ({required heroId, required callbacks}) => HeroInventoryTab(
        heroId: heroId,
        onDirtyChanged: callbacks.onDirtyChanged,
        onEditingChanged: callbacks.onEditingChanged,
        onRegisterDiscard: callbacks.onRegisterDiscard,
        onRegisterEditActions: callbacks.onRegisterEditActions,
      ),
    ),
    WorkspaceTabSpec(
      id: WorkspaceTabIds.notes,
      label: 'Notizen',
      icon: Icons.sticky_note_2_outlined,
      helper: 'Freier Platzhalterbereich',
      buildContent: ({required heroId, required callbacks}) => HeroNotesTab(
        heroId: heroId,
        onDirtyChanged: callbacks.onDirtyChanged,
        onEditingChanged: callbacks.onEditingChanged,
        onRegisterDiscard: callbacks.onRegisterDiscard,
        onRegisterEditActions: callbacks.onRegisterEditActions,
      ),
    ),
    WorkspaceTabSpec(
      id: WorkspaceTabIds.begleiter,
      label: 'Begleiter',
      icon: Icons.pets_outlined,
      helper: 'Vertraute und Begleiter des Helden',
      buildContent: ({required heroId, required callbacks}) =>
          HeroBegleiterTab(
            heroId: heroId,
            onDirtyChanged: callbacks.onDirtyChanged,
            onEditingChanged: callbacks.onEditingChanged,
            onRegisterDiscard: callbacks.onRegisterDiscard,
            onRegisterEditActions: callbacks.onRegisterEditActions,
          ),
    ),
  ];
}

/// Filtert die Tab-Liste fuer den aktuell sichtbaren Helden.
List<WorkspaceTabSpec> visibleWorkspaceTabsForHero({
  required HeroSheet hero,
  required Iterable<WorkspaceTabSpec> tabs,
}) {
  return tabs.where((tab) => tab.isVisible(hero)).toList(growable: false);
}

List<WorkspaceHeaderAction> _buildTalentsHeaderActions({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required bool isCompactLayout,
}) {
  final bePreview = ref.watch(combatPreviewProvider(heroId));

  void openBeDialog() {
    showAdaptiveDetailSheet<void>(
      context: context,
      builder: (_) => TalentBeConfigDialog(
        heroId: heroId,
        combatBaseBe: bePreview.valueOrNull?.beKampf ?? 0,
      ),
    );
  }

  return <WorkspaceHeaderAction>[
    WorkspaceHeaderAction(
      showWhenEditing: true,
      showWhenIdle: true,
      builder: (_) => isCompactLayout
          ? Tooltip(
              message: 'BE konfigurieren',
              child: IconButton(
                key: const ValueKey<String>('talents-be-screen-open'),
                onPressed: openBeDialog,
                icon: const Icon(Icons.shield_outlined),
              ),
            )
          : OutlinedButton.icon(
              key: const ValueKey<String>('talents-be-screen-open'),
              onPressed: openBeDialog,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('BE konfigurieren'),
            ),
    ),
  ];
}

List<WorkspaceHeaderAction> _buildNoHeaderActions({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required bool isCompactLayout,
}) {
  return const <WorkspaceHeaderAction>[];
}

bool _alwaysVisible(HeroSheet hero) => true;
