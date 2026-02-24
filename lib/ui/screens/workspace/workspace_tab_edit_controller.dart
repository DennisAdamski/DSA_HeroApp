/// Kapselt den gemeinsamen Editier-Lebenszyklus fuer Workspace-Tabs.
///
/// Die Klasse ist absichtlich UI-neutral und enthaelt nur den Zustand:
/// - `isEditing`: Tab befindet sich im Bearbeitungsmodus.
/// - `isDirty`: Seit Edit-Start wurden ungespeicherte Aenderungen gemacht.
/// - `lastSyncedSignature`: Fingerprint des zuletzt synchronisierten Modells.
class WorkspaceTabEditController {
  WorkspaceTabEditController({
    required void Function(bool isDirty) onDirtyChanged,
    required void Function(bool isEditing) onEditingChanged,
    required void Function() requestRebuild,
  })  : _onDirtyChanged = onDirtyChanged,
        _onEditingChanged = onEditingChanged,
        _requestRebuild = requestRebuild;

  final void Function(bool isDirty) _onDirtyChanged;
  final void Function(bool isEditing) _onEditingChanged;
  final void Function() _requestRebuild;

  bool _isDirty = false;
  bool _isEditing = false;
  String _lastSyncedSignature = '';

  bool get isDirty => _isDirty;
  bool get isEditing => _isEditing;

  void startEdit() {
    _setEditing(true);
    _setDirty(false);
  }

  void markSaved() {
    _setEditing(false);
    _setDirty(false);
  }

  void markDiscarded() {
    _setEditing(false);
    _setDirty(false);
  }

  void markFieldChanged() {
    if (_isEditing) {
      _setDirty(true);
    }
  }

  bool shouldSync(String signature, {bool force = false}) {
    if (_isEditing && !force) {
      return false;
    }
    if (!force && signature == _lastSyncedSignature) {
      return false;
    }
    _lastSyncedSignature = signature;
    return true;
  }

  void clearSyncSignature() {
    _lastSyncedSignature = '';
  }

  void emitCurrentState() {
    _onDirtyChanged(_isDirty);
    _onEditingChanged(_isEditing);
  }

  void _setDirty(bool value) {
    if (_isDirty == value) {
      return;
    }
    _isDirty = value;
    _requestRebuild();
    _onDirtyChanged(value);
  }

  void _setEditing(bool value) {
    if (_isEditing == value) {
      return;
    }
    _isEditing = value;
    _requestRebuild();
    _onEditingChanged(value);
  }
}
