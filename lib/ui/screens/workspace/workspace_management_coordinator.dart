import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_navigation_guard.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_registry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

/// Koordiniert Tabs, Editieraktionen und Leave-Guard der Heldenverwaltung.
///
/// Der neue Verwaltungsbody und der klassische Workspace verwenden dieselbe
/// Zustandsmaschine, damit Speichern, Verwerfen und Tabwechsel identisch
/// abgesichert sind.
class WorkspaceManagementCoordinator extends ChangeNotifier {
  /// Erstellt die Koordination für einen Helden und bindet sie an ihren Host.
  WorkspaceManagementCoordinator({
    required this.heroId,
    required this.vsync,
    required this.contextProvider,
    required this.hostIsMounted,
  }) {
    _tabController = TabController(length: 1, vsync: vsync);
    _tabController.addListener(_onTabControllerChanged);
  }

  /// ID des Helden, dessen Verwaltungszustand koordiniert wird.
  final String heroId;

  /// Tickerquelle des einbettenden Verwaltungs-Hosts.
  final TickerProvider vsync;

  /// Liefert den jeweils aktuellen Kontext des einbettenden Hosts.
  final BuildContext Function() contextProvider;

  /// Prüft, ob der einbettende Host noch verwendet werden darf.
  final bool Function() hostIsMounted;
  final WorkspaceTabRegistry _registry = WorkspaceTabRegistry();

  late TabController _tabController;
  List<WorkspaceTabSpec> _visibleTabs = const <WorkspaceTabSpec>[];
  bool _handlingTabChange = false;
  bool _revertingTabChange = false;
  bool _runningEditAction = false;
  bool _runningLeaveGuard = false;

  /// Controller für die aktuell sichtbaren Verwaltungsabschnitte.
  TabController get tabController => _tabController;

  /// Sichtbare Abschnitte in ihrer kanonischen Reihenfolge.
  List<WorkspaceTabSpec> get visibleTabs => _visibleTabs;

  /// Sperrt Editoraktionen auch während einer Verlassen-Prüfung samt Save.
  bool get isRunningEditAction => _runningEditAction || _runningLeaveGuard;

  /// Liefert die aktive Abschnitts-ID.
  String? get activeTabId => _registry.activeTabId;

  /// Liefert den aktiven Abschnitt oder `null` bei leerer Navigation.
  WorkspaceTabSpec? get activeTab {
    if (_visibleTabs.isEmpty) {
      return null;
    }
    return _visibleTabs[activeTabIndex];
  }

  /// Liefert den Index des aktiven sichtbaren Abschnitts.
  int get activeTabIndex {
    final activeId = _registry.activeTabId;
    if (_visibleTabs.isEmpty || activeId == null) {
      return 0;
    }
    final index = _visibleTabs.indexWhere((tab) => tab.id == activeId);
    return index < 0 ? 0 : index;
  }

  /// Synchronisiert Registry und Sichtbarkeit mit dem aktuellen Helden.
  void syncHero(HeroSheet hero) {
    final allTabs = buildWorkspaceTabs(
      heroId: heroId,
      callbacksForTab: callbacksForTab,
    );
    final editableTabIds = allTabs
        .where((tab) => tab.isEditable)
        .map((tab) => tab.id);
    _registry.setEditableTabs(editableTabIds);
    final visibleTabs = visibleWorkspaceTabsForHero(hero: hero, tabs: allTabs);
    _syncVisibleTabs(visibleTabs);
  }

  /// Erstellt die Host-Callbacks für einen Verwaltungsabschnitt.
  WorkspaceTabCallbacks callbacksForTab(String tabId) {
    return WorkspaceTabCallbacks(
      onDirtyChanged: (isDirty) => _updateDirty(tabId, isDirty),
      onEditingChanged: (isEditing) => _updateEditing(tabId, isEditing),
      onRegisterDiscard: (action) => _registry.registerDiscard(tabId, action),
      onRegisterEditActions: (actions) {
        final wasMissing = _registry.registerEditActions(tabId, actions);
        if (wasMissing && activeTabId == tabId) {
          notifyListeners();
        }
      },
    );
  }

  /// Gibt an, ob ein Abschnitt ungespeicherte Änderungen besitzt.
  bool isDirty(String tabId) => _registry.isDirty(tabId);

  /// Gibt an, ob ein Abschnitt gerade editiert wird.
  bool isEditing(String tabId) => _registry.isEditing(tabId);

  /// Gibt an, ob für einen Abschnitt Editoraktionen registriert sind.
  bool isEditableTab(String tabId) => _registry.isEditableTab(tabId);

  /// Liefert die registrierten Editoraktionen eines Abschnitts.
  WorkspaceTabEditActions? editActionsFor(String tabId) {
    return _registry.editActionsFor(tabId);
  }

  /// Führt eine Editoraktion aus und verhindert parallele Doppelausführung.
  Future<void> runEditAction(WorkspaceAsyncAction? action) async {
    if (isRunningEditAction || action == null) {
      return;
    }
    _runningEditAction = true;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _showSaveError(error);
    } finally {
      _runningEditAction = false;
      if (hostIsMounted()) {
        notifyListeners();
      }
    }
  }

  /// Prüft den aktiven Entwurf, bevor die Verwaltungsfläche verlassen wird.
  Future<bool> confirmLeave() async {
    final tabId = activeTabId;
    if (tabId == null) {
      return true;
    }
    return confirmLeaveForTab(tabId);
  }

  /// Prüft einen Abschnitt und behandelt Behalten, Verwerfen und Speichern.
  Future<bool> confirmLeaveForTab(
    String tabId, {
    bool allowDuringEditAction = false,
  }) async {
    if (_runningEditAction && !allowDuringEditAction) {
      return false;
    }
    if (!_registry.isDirty(tabId)) {
      return _finishCleanEditor(tabId);
    }
    if (_runningLeaveGuard || !hostIsMounted()) {
      return false;
    }

    _runningLeaveGuard = true;
    notifyListeners();
    try {
      final result = await showWorkspaceDiscardDialog(contextProvider());
      if (!hostIsMounted() || result == AdaptiveConfirmResult.cancel) {
        return false;
      }
      if (result == AdaptiveConfirmResult.save) {
        return await _saveBeforeLeaving(tabId);
      }
      return await _discardBeforeLeaving(tabId);
    } finally {
      _runningLeaveGuard = false;
      if (hostIsMounted()) {
        notifyListeners();
      }
    }
  }

  Future<bool> _finishCleanEditor(String tabId) async {
    if (!_registry.isEditing(tabId)) {
      return true;
    }
    if (_runningLeaveGuard || !hostIsMounted()) {
      return false;
    }
    final cancelAction = _registry.editActionsFor(tabId)?.cancel;
    if (cancelAction == null) {
      return false;
    }
    _runningLeaveGuard = true;
    notifyListeners();
    try {
      await cancelAction();
      return hostIsMounted() && !_registry.isEditing(tabId);
    } catch (error) {
      _showSaveError(error);
      return false;
    } finally {
      _runningLeaveGuard = false;
      if (hostIsMounted()) {
        notifyListeners();
      }
    }
  }

  /// Baut den Inhalt aller sichtbaren Abschnitte für eine TabBarView.
  List<Widget> buildTabContents() {
    return _visibleTabs
        .map(
          (tab) => tab.buildContent(
            heroId: heroId,
            callbacks: callbacksForTab(tab.id),
          ),
        )
        .toList(growable: false);
  }

  void _syncVisibleTabs(List<WorkspaceTabSpec> tabs) {
    final nextIds = tabs.map((tab) => tab.id).toList(growable: false);
    final currentIds = _visibleTabs
        .map((tab) => tab.id)
        .toList(growable: false);
    if (_listEquals(nextIds, currentIds)) {
      return;
    }

    _visibleTabs = List<WorkspaceTabSpec>.unmodifiable(tabs);
    if (_visibleTabs.isEmpty) {
      _replaceTabController(length: 1, initialIndex: 0);
      _registry.activeTabId = null;
      return;
    }

    final previousId = _registry.activeTabId;
    final retained =
        previousId != null && _visibleTabs.any((tab) => tab.id == previousId);
    final activeId = retained ? previousId : _visibleTabs.first.id;
    final index = _visibleTabs.indexWhere((tab) => tab.id == activeId);
    _replaceTabController(length: _visibleTabs.length, initialIndex: index);
    _registry.activeTabId = activeId;
  }

  void _replaceTabController({required int length, required int initialIndex}) {
    _tabController.removeListener(_onTabControllerChanged);
    _tabController.dispose();
    _tabController = TabController(
      length: length,
      vsync: vsync,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
    _tabController.addListener(_onTabControllerChanged);
  }

  void _onTabControllerChanged() {
    if (_handlingTabChange || _revertingTabChange || _visibleTabs.isEmpty) {
      return;
    }
    final nextId = _visibleTabs[_tabController.index].id;
    if (nextId == _registry.activeTabId) {
      return;
    }
    unawaited(_handleTabChangeAttempt(_tabController.index));
  }

  Future<void> _handleTabChangeAttempt(int nextIndex) async {
    if (_handlingTabChange || _visibleTabs.isEmpty) {
      return;
    }
    _handlingTabChange = true;
    try {
      final fromId = _registry.activeTabId;
      final mayLeave = fromId == null || await confirmLeaveForTab(fromId);
      if (!hostIsMounted()) {
        return;
      }
      if (mayLeave) {
        _registry.activeTabId = _visibleTabs[nextIndex].id;
        notifyListeners();
        return;
      }
      final fromIndex = _visibleTabs.indexWhere((tab) => tab.id == fromId);
      _revertingTabChange = true;
      _tabController.animateTo(fromIndex < 0 ? 0 : fromIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revertingTabChange = false;
      });
    } finally {
      _handlingTabChange = false;
    }
  }

  Future<bool> _saveBeforeLeaving(String tabId) async {
    final saveAction = _registry.editActionsFor(tabId)?.save;
    if (saveAction == null) {
      return false;
    }
    try {
      await saveAction();
    } catch (error) {
      _showSaveError(error);
      return false;
    }
    if (!hostIsMounted()) {
      return false;
    }
    if (_registry.isDirty(tabId)) {
      _showSaveError(
        StateError('Die Änderungen sind weiterhin als ungespeichert markiert.'),
      );
      return false;
    }
    return true;
  }

  Future<bool> _discardBeforeLeaving(String tabId) async {
    final discardAction = _registry.discardActionFor(tabId);
    try {
      await discardAction?.call();
    } catch (error) {
      _showSaveError(error);
      return false;
    }
    if (!hostIsMounted()) {
      return false;
    }
    if (_registry.updateDirty(tabId, false)) {
      notifyListeners();
    }
    return true;
  }

  void _showSaveError(Object error) {
    if (!hostIsMounted()) {
      return;
    }
    final detail = error is StateError ? error.message : '$error';
    ScaffoldMessenger.of(contextProvider()).showSnackBar(
      SnackBar(content: Text('Speichern fehlgeschlagen: $detail')),
    );
  }

  void _updateDirty(String tabId, bool isDirty) {
    if (_registry.updateDirty(tabId, isDirty)) {
      notifyListeners();
    }
  }

  void _updateEditing(String tabId, bool isEditing) {
    if (_registry.updateEditing(tabId, isEditing)) {
      notifyListeners();
    }
  }

  bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  /// Gibt den TabController und alle Listener des Koordinators frei.
  @override
  void dispose() {
    _tabController.removeListener(_onTabControllerChanged);
    _tabController.dispose();
    super.dispose();
  }
}
