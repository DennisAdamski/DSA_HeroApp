import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_area_registry.dart';

void main() {
  test(
    'talents list area is registered as list view with catalog support',
    () {
      final meta = workspaceAreaMetaById(WorkspaceAreaId.talentsList);

      expect(meta.pageId, WorkspacePageId.talents);
      expect(meta.kind, WorkspaceAreaKind.listView);
      expect(meta.supportsVisibilityMode, isFalse);
      expect(meta.supportsGroupVisibility, isFalse);
    },
  );

  test(
    'combat techniques area is registered as list view with catalog support',
    () {
      final meta = workspaceAreaMetaById(WorkspaceAreaId.combatTechniquesList);

      expect(meta.pageId, WorkspacePageId.combat);
      expect(meta.kind, WorkspaceAreaKind.listView);
      expect(meta.supportsVisibilityMode, isFalse);
      expect(meta.supportsGroupVisibility, isFalse);
    },
  );

  test(
    'talent special abilities area is registered as form view without visibility',
    () {
      final meta = workspaceAreaMetaById(
        WorkspaceAreaId.talentsSpecialAbilities,
      );

      expect(meta.pageId, WorkspacePageId.talents);
      expect(meta.kind, WorkspaceAreaKind.formView);
      expect(meta.supportsVisibilityMode, isFalse);
      expect(meta.supportsGroupVisibility, isFalse);
    },
  );

  test('notes connections area is registered as editable notes view', () {
    final meta = workspaceAreaMetaById(WorkspaceAreaId.notesConnections);

    expect(meta.pageId, WorkspacePageId.notes);
    expect(meta.kind, WorkspaceAreaKind.notesView);
    expect(meta.supportsInlineEdit, isTrue);
    expect(meta.supportsVisibilityMode, isFalse);
    expect(meta.supportsGroupVisibility, isFalse);
  });
}
