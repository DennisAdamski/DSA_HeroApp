enum WorkspacePageId { overview, talents, combat, magic, inventory, notes }

enum WorkspaceAreaId {
  overviewMain,
  talentsList,
  talentsSpecialAbilities,
  combatTechniquesList,
  combatMeleeCalculator,
  combatSpecialRules,
  inventoryMain,
  notesEntries,
  notesConnections,
}

enum WorkspaceAreaKind { listView, formView, calculatorView, notesView }

class WorkspaceAreaMeta {
  const WorkspaceAreaMeta({
    required this.pageId,
    required this.areaId,
    required this.kind,
    required this.supportsVisibilityMode,
    required this.supportsGroupVisibility,
    required this.supportsInlineEdit,
  });

  final WorkspacePageId pageId;
  final WorkspaceAreaId areaId;
  final WorkspaceAreaKind kind;
  final bool supportsVisibilityMode;
  final bool supportsGroupVisibility;
  final bool supportsInlineEdit;
}

const List<WorkspaceAreaMeta> workspaceAreaRegistry = <WorkspaceAreaMeta>[
  WorkspaceAreaMeta(
    pageId: WorkspacePageId.overview,
    areaId: WorkspaceAreaId.overviewMain,
    kind: WorkspaceAreaKind.formView,
    supportsVisibilityMode: false,
    supportsGroupVisibility: false,
    supportsInlineEdit: true,
  ),
  WorkspaceAreaMeta(
    pageId: WorkspacePageId.talents,
    areaId: WorkspaceAreaId.talentsList,
    kind: WorkspaceAreaKind.listView,
    supportsVisibilityMode: false,
    supportsGroupVisibility: false,
    supportsInlineEdit: true,
  ),
  WorkspaceAreaMeta(
    pageId: WorkspacePageId.talents,
    areaId: WorkspaceAreaId.talentsSpecialAbilities,
    kind: WorkspaceAreaKind.formView,
    supportsVisibilityMode: false,
    supportsGroupVisibility: false,
    supportsInlineEdit: true,
  ),
  WorkspaceAreaMeta(
    pageId: WorkspacePageId.combat,
    areaId: WorkspaceAreaId.combatTechniquesList,
    kind: WorkspaceAreaKind.listView,
    supportsVisibilityMode: false,
    supportsGroupVisibility: false,
    supportsInlineEdit: true,
  ),
  WorkspaceAreaMeta(
    pageId: WorkspacePageId.combat,
    areaId: WorkspaceAreaId.combatMeleeCalculator,
    kind: WorkspaceAreaKind.calculatorView,
    supportsVisibilityMode: false,
    supportsGroupVisibility: false,
    supportsInlineEdit: true,
  ),
  WorkspaceAreaMeta(
    pageId: WorkspacePageId.combat,
    areaId: WorkspaceAreaId.combatSpecialRules,
    kind: WorkspaceAreaKind.formView,
    supportsVisibilityMode: false,
    supportsGroupVisibility: false,
    supportsInlineEdit: true,
  ),
  WorkspaceAreaMeta(
    pageId: WorkspacePageId.inventory,
    areaId: WorkspaceAreaId.inventoryMain,
    kind: WorkspaceAreaKind.formView,
    supportsVisibilityMode: false,
    supportsGroupVisibility: false,
    supportsInlineEdit: true,
  ),
  WorkspaceAreaMeta(
    pageId: WorkspacePageId.notes,
    areaId: WorkspaceAreaId.notesEntries,
    kind: WorkspaceAreaKind.notesView,
    supportsVisibilityMode: false,
    supportsGroupVisibility: false,
    supportsInlineEdit: true,
  ),
  WorkspaceAreaMeta(
    pageId: WorkspacePageId.notes,
    areaId: WorkspaceAreaId.notesConnections,
    kind: WorkspaceAreaKind.notesView,
    supportsVisibilityMode: false,
    supportsGroupVisibility: false,
    supportsInlineEdit: true,
  ),
];

WorkspaceAreaMeta workspaceAreaMetaById(WorkspaceAreaId areaId) {
  for (final meta in workspaceAreaRegistry) {
    if (meta.areaId == areaId) {
      return meta;
    }
  }
  throw ArgumentError.value(areaId, 'areaId', 'Unknown workspace area');
}
