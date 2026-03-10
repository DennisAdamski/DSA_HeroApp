import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

/// Haltet tab-spezifischen Workspace-Zustand fuer Edit- und Dirty-Handling.
class WorkspaceTabRegistry {
  WorkspaceTabRegistry({this.activeTabId});

  final Set<String> _editableTabs = <String>{};

  final Map<String, bool> _dirtyByTab = <String, bool>{};
  final Map<String, bool> _editingByTab = <String, bool>{};
  final Map<String, WorkspaceAsyncAction> _discardByTab =
      <String, WorkspaceAsyncAction>{};
  final Map<String, WorkspaceTabEditActions> _editActionsByTab =
      <String, WorkspaceTabEditActions>{};

  /// Aktive Tab-ID in der sichtbaren Workspace-Liste.
  String? activeTabId;

  /// Synchronisiert die editierbaren Tabs mit der aktuellen Definition.
  void setEditableTabs(Iterable<String> editableTabs) {
    _editableTabs
      ..clear()
      ..addAll(editableTabs);
    for (final tabId in _editableTabs) {
      _dirtyByTab.putIfAbsent(tabId, () => false);
      _editingByTab.putIfAbsent(tabId, () => false);
    }
  }

  /// Gibt zurueck, ob ein Tab editierbar ist.
  bool isEditableTab(String tabId) => _editableTabs.contains(tabId);

  /// Gibt zurueck, ob ein Tab ungespeicherte Aenderungen besitzt.
  bool isDirty(String tabId) => _dirtyByTab[tabId] ?? false;

  /// Gibt zurueck, ob ein Tab aktuell im Editiermodus ist.
  bool isEditing(String tabId) => _editingByTab[tabId] ?? false;

  /// Liefert die registrierte Verwerfen-Aktion eines Tabs.
  WorkspaceAsyncAction? discardActionFor(String tabId) => _discardByTab[tabId];

  /// Liefert die registrierten Edit-Aktionen eines Tabs.
  WorkspaceTabEditActions? editActionsFor(String tabId) =>
      _editActionsByTab[tabId];

  /// Aktualisiert den Dirty-Zustand eines Tabs.
  bool updateDirty(String tabId, bool isDirty) {
    if ((_dirtyByTab[tabId] ?? false) == isDirty) {
      return false;
    }
    _dirtyByTab[tabId] = isDirty;
    return true;
  }

  /// Aktualisiert den Editierzustand eines Tabs.
  bool updateEditing(String tabId, bool isEditing) {
    if ((_editingByTab[tabId] ?? false) == isEditing) {
      return false;
    }
    _editingByTab[tabId] = isEditing;
    return true;
  }

  /// Registriert die Verwerfen-Aktion eines Tabs.
  void registerDiscard(String tabId, WorkspaceAsyncAction discardAction) {
    _discardByTab[tabId] = discardAction;
  }

  /// Registriert die Edit-Aktionen eines Tabs.
  bool registerEditActions(String tabId, WorkspaceTabEditActions actions) {
    final wasMissing = !_editActionsByTab.containsKey(tabId);
    _editActionsByTab[tabId] = actions;
    return wasMissing;
  }
}
