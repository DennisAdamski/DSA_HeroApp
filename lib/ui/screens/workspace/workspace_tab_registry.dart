import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

/// Haltet tab-spezifischen Workspace-Zustand fuer Edit- und Dirty-Handling.
class WorkspaceTabRegistry {
  WorkspaceTabRegistry({
    required Iterable<int> editableTabs,
    this.activeTabIndex = 0,
  }) : _editableTabs = Set<int>.from(editableTabs) {
    for (final tabIndex in _editableTabs) {
      _dirtyByTab[tabIndex] = false;
      _editingByTab[tabIndex] = false;
    }
  }

  final Set<int> _editableTabs;

  final Map<int, bool> _dirtyByTab = <int, bool>{};
  final Map<int, bool> _editingByTab = <int, bool>{};
  final Map<int, WorkspaceAsyncAction> _discardByTab =
      <int, WorkspaceAsyncAction>{};
  final Map<int, WorkspaceTabEditActions> _editActionsByTab =
      <int, WorkspaceTabEditActions>{};

  int activeTabIndex;

  bool isEditableTab(int tabIndex) => _editableTabs.contains(tabIndex);

  bool isDirty(int tabIndex) => _dirtyByTab[tabIndex] ?? false;

  bool isEditing(int tabIndex) => _editingByTab[tabIndex] ?? false;

  WorkspaceAsyncAction? discardActionFor(int tabIndex) => _discardByTab[tabIndex];

  WorkspaceTabEditActions? editActionsFor(int tabIndex) =>
      _editActionsByTab[tabIndex];

  bool updateDirty(int tabIndex, bool isDirty) {
    if ((_dirtyByTab[tabIndex] ?? false) == isDirty) {
      return false;
    }
    _dirtyByTab[tabIndex] = isDirty;
    return true;
  }

  bool updateEditing(int tabIndex, bool isEditing) {
    if ((_editingByTab[tabIndex] ?? false) == isEditing) {
      return false;
    }
    _editingByTab[tabIndex] = isEditing;
    return true;
  }

  void registerDiscard(int tabIndex, WorkspaceAsyncAction discardAction) {
    _discardByTab[tabIndex] = discardAction;
  }

  bool registerEditActions(int tabIndex, WorkspaceTabEditActions actions) {
    final wasMissing = !_editActionsByTab.containsKey(tabIndex);
    _editActionsByTab[tabIndex] = actions;
    return wasMissing;
  }
}
