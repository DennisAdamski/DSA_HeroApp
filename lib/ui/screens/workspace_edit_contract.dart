typedef WorkspaceAsyncAction = Future<void> Function();

class WorkspaceTabEditActions {
  const WorkspaceTabEditActions({
    required this.startEdit,
    required this.save,
    required this.cancel,
  });

  final WorkspaceAsyncAction startEdit;
  final WorkspaceAsyncAction save;
  final WorkspaceAsyncAction cancel;
}
