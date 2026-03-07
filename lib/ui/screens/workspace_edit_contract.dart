import 'package:flutter/widgets.dart';

typedef WorkspaceAsyncAction = Future<void> Function();

class WorkspaceHeaderAction {
  const WorkspaceHeaderAction({
    required this.builder,
    this.showWhenEditing = true,
    this.showWhenIdle = false,
  });

  final WidgetBuilder builder;
  final bool showWhenEditing;
  final bool showWhenIdle;
}

class WorkspaceTabEditActions {
  const WorkspaceTabEditActions({
    required this.startEdit,
    required this.save,
    required this.cancel,
    this.headerActions = const <WorkspaceHeaderAction>[],
  });

  final WorkspaceAsyncAction startEdit;
  final WorkspaceAsyncAction save;
  final WorkspaceAsyncAction cancel;
  final List<WorkspaceHeaderAction> headerActions;
}
