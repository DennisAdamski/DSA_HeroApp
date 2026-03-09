import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';

/// Rueckgabewerte fuer adaptive Bestaetigungsdialoge.
enum AdaptiveConfirmResult {
  /// Der Nutzer hat den Vorgang abgebrochen.
  cancel,

  /// Der Nutzer hat den Vorgang bestaetigt.
  confirm,

  /// Der Nutzer moechte vorher speichern.
  save,
}

/// Zeigt einen Detail-/Editor-Dialog plattformadaptiv an.
///
/// Auf Apple-Plattformen wird ein [DraggableScrollableSheet] als BottomSheet
/// angezeigt; auf allen anderen Plattformen ein zentrierter [Dialog].
Future<T?> showAdaptiveDetailSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
}) {
  if (isApplePlatform(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: useRootNavigator,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (sheetContext, scrollController) => Material(
          child: builder(sheetContext),
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: builder,
  );
}

/// Zeigt einen Bestaetigungsdialog plattformadaptiv an.
///
/// Nutzt [AlertDialog.adaptive] fuer automatische Cupertino-Optik auf iOS.
Future<AdaptiveConfirmResult> showAdaptiveConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String cancelLabel = 'Abbrechen',
  required String confirmLabel,
  String? saveLabel,
  bool isDestructive = false,
}) async {
  final result = await showDialog<AdaptiveConfirmResult>(
    context: context,
    builder: (dialogContext) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(AdaptiveConfirmResult.cancel),
          child: Text(cancelLabel),
        ),
        if (saveLabel != null)
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(AdaptiveConfirmResult.save),
            child: Text(saveLabel),
          ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(AdaptiveConfirmResult.confirm),
          style: isDestructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? AdaptiveConfirmResult.cancel;
}
