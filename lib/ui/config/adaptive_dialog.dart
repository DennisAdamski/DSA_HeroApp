import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

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
///
/// Der Sheet-Inhalt erhaelt zusaetzlich einen Bottom-Padding in Hoehe der
/// Soft-Tastatur ([MediaQueryData.viewInsets]), damit Eingabefelder im Sheet
/// auf iPad-Web nicht durch die Tastatur verdeckt werden.
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
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: builder(sheetContext),
          ),
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

/// Zeigt einen Eingabe-Dialog plattformadaptiv an.
///
/// Auf Apple-Plattformen (inkl. iPad-Web) als BottomSheet, das die
/// Soft-Tastatur korrekt ueber [MediaQueryData.viewInsets] kompensiert; auf
/// anderen Plattformen als zentrierter [AlertDialog].
///
/// Der Builder muss ein [AdaptiveInputDialog] (oder kompatibles Widget)
/// zurueckgeben, das selbst entscheidet, wie es im jeweiligen Container
/// gerendert wird.
Future<T?> showAdaptiveInputDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool isDismissible = true,
}) {
  if (isApplePlatform(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    builder: builder,
  );
}

/// Adaptive Huelle fuer Eingabe-Dialoge.
///
/// Rendert sich auf Apple-Plattformen als BottomSheet-Inhalt mit Drag-Handle,
/// Tastatur-Padding und scrollbarem Body. Auf anderen Plattformen als
/// zentrierter [AlertDialog].
class AdaptiveInputDialog extends StatelessWidget {
  const AdaptiveInputDialog({
    required this.title,
    required this.content,
    required this.actions,
    this.maxWidth,
    super.key,
  });

  /// Dialog-Titel.
  final String title;

  /// Eingabefelder/Inhalt; wird intern in einer [SingleChildScrollView]
  /// platziert. Sollte mit [Column] (mainAxisSize: min) und Eingabefeldern
  /// gefuellt werden.
  final Widget content;

  /// Aktionsbuttons (z. B. Abbrechen/Speichern). Werden im AlertDialog als
  /// `actions` und im BottomSheet als rechtsbuendige Reihe gerendert.
  final List<Widget> actions;

  /// Optionale Breite fuer den AlertDialog-Pfad. Default
  /// [kDialogWidthMedium].
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform(context)) {
      return _BottomSheetInputShell(
        title: title,
        content: content,
        actions: actions,
      );
    }
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: maxWidth ?? kDialogWidthMedium,
        child: SingleChildScrollView(child: content),
      ),
      actions: actions,
    );
  }
}

class _BottomSheetInputShell extends StatelessWidget {
  const _BottomSheetInputShell({
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final mediaQuery = MediaQuery.of(context);
    final maxBodyHeight = mediaQuery.size.height -
        viewInsets.bottom -
        mediaQuery.padding.top -
        160;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxBodyHeight > 200 ? maxBodyHeight : 200,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: content,
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      actions[i],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
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
