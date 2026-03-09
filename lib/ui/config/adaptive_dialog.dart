import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';

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
Future<bool> showAdaptiveConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String cancelLabel = 'Abbrechen',
  required String confirmLabel,
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
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
  return result ?? false;
}
