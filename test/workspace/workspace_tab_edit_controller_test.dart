import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';

void main() {
  test('edit lifecycle toggles editing and dirty state', () {
    final dirtyEvents = <bool>[];
    final editingEvents = <bool>[];
    var rebuildCount = 0;

    final controller = WorkspaceTabEditController(
      onDirtyChanged: dirtyEvents.add,
      onEditingChanged: editingEvents.add,
      requestRebuild: () {
        rebuildCount++;
      },
    );

    controller.startEdit();
    expect(controller.isEditing, isTrue);
    expect(controller.isDirty, isFalse);

    controller.markFieldChanged();
    expect(controller.isDirty, isTrue);

    controller.markSaved();
    expect(controller.isEditing, isFalse);
    expect(controller.isDirty, isFalse);

    expect(editingEvents, <bool>[true, false]);
    expect(dirtyEvents, <bool>[true, false]);
    expect(rebuildCount, 4);
  });

  test('sync signature blocks redundant sync and edit-time sync', () {
    final controller = WorkspaceTabEditController(
      onDirtyChanged: (_) {},
      onEditingChanged: (_) {},
      requestRebuild: () {},
    );

    expect(controller.shouldSync('same'), isTrue);
    expect(controller.shouldSync('same'), isFalse);

    controller.startEdit();
    expect(controller.shouldSync('new-during-edit'), isFalse);
    expect(controller.shouldSync('new-during-edit', force: true), isTrue);
  });

  test('discard resets state and allows forced resync from blank signature', () {
    final controller = WorkspaceTabEditController(
      onDirtyChanged: (_) {},
      onEditingChanged: (_) {},
      requestRebuild: () {},
    );

    expect(controller.shouldSync('v1'), isTrue);
    controller.startEdit();
    controller.markFieldChanged();
    controller.clearSyncSignature();
    controller.markDiscarded();

    expect(controller.isEditing, isFalse);
    expect(controller.isDirty, isFalse);
    expect(controller.shouldSync('v1'), isTrue);
  });
}
