import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/feedback/feedback_submission.dart';
import 'package:dsa_heldenverwaltung/ui_shared/feedback/feedback_page.dart';

/// Öffnet den gemeinsamen Feedbackweg mit einem vorausgewählten App-Bereich.
Future<void> openFeedbackPage(
  BuildContext context, {
  required FeedbackSurface initialSurface,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FeedbackPage(initialSurface: initialSurface),
    ),
  );
}
