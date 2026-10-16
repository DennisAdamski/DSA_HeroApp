import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/data/feedback/feedback_diagnostics_collector.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_result.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_submission.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/state/feedback/feedback_controller.dart';
import 'package:dsa_heldenverwaltung/state/feedback/feedback_providers.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/app_layout.dart';
import 'package:dsa_heldenverwaltung/ui_shared/feedback/feedback_preview_dialog.dart';
import 'package:dsa_heldenverwaltung/ui_shared/feedback/feedback_result_view.dart';

/// Gemeinsames, adaptives Formular für Bug, Feature-Anfrage und Regelfrage.
class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({
    super.key,
    this.initialSurface = FeedbackSurface.other,
    this.embedded = false,
  });

  final FeedbackSurface initialSurface;
  final bool embedded;

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _optional = TextEditingController();
  FeedbackKind _kind = FeedbackKind.bug;
  late FeedbackSurface _surface = widget.initialSurface;
  bool _includeDiagnostics = true;
  bool _refreshing = false;
  FeedbackResult? _result;
  String? _resultAccount;
  String? _loadedAccount;

  @override
  void dispose() {
    _title.dispose();
    _primary.dispose();
    _secondary.dispose();
    _optional.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider).asData?.value;
    final controller = ref.watch(feedbackControllerProvider);
    final collector = ref.watch(feedbackDiagnosticsCollectorProvider);
    final content = _buildContent(context, user, controller, collector);
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback senden')),
      body: content,
    );
  }

  Widget _buildContent(
    BuildContext context,
    AuthUser? user,
    FeedbackController? controller,
    AsyncValue<FeedbackDiagnosticsCollector> collector,
  ) {
    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Bitte zuerst mit deinem bestehenden App-Konto anmelden, um Feedback zu senden.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (controller == null) {
      return const Center(child: Text('Feedback ist derzeit nicht verfügbar.'));
    }
    _loadPending(user.uid, controller);
    final diagnosticsCollector = collector.asData?.value;
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Direkt an GitHub',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Deine Meldung wird öffentlich gespeichert. Es werden keine E-Mail, UID oder Heldendaten übertragen.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FeedbackKind>(
              key: const ValueKey('feedback-kind'),
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Meldeart'),
              items: const [
                DropdownMenuItem(value: FeedbackKind.bug, child: Text('Bug')),
                DropdownMenuItem(
                  value: FeedbackKind.feature,
                  child: Text('Feature-Anfrage'),
                ),
                DropdownMenuItem(
                  value: FeedbackKind.rules,
                  child: Text('Regelfrage'),
                ),
              ],
              onChanged: (value) => setState(() {
                _kind = value ?? FeedbackKind.bug;
                _primary.clear();
                _secondary.clear();
                _optional.clear();
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FeedbackSurface>(
              initialValue: _surface,
              decoration: const InputDecoration(labelText: 'Bereich'),
              items: [
                for (final surface in FeedbackSurface.values)
                  DropdownMenuItem(value: surface, child: Text(surface.label)),
              ],
              onChanged: (value) => setState(() {
                _surface = value ?? FeedbackSurface.other;
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('feedback-title'),
              controller: _title,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Titel'),
              validator: (value) => _required(value, min: 5, label: 'Titel'),
            ),
            TextFormField(
              key: const ValueKey('feedback-primary'),
              controller: _primary,
              minLines: 3,
              maxLines: 8,
              maxLength: 8000,
              decoration: InputDecoration(labelText: _primaryLabel),
              validator: (value) =>
                  _required(value, min: 20, label: _primaryLabel),
            ),
            TextFormField(
              key: const ValueKey('feedback-secondary'),
              controller: _secondary,
              minLines: 2,
              maxLines: 8,
              maxLength: _kind == FeedbackKind.rules ? 300 : 8000,
              decoration: InputDecoration(labelText: _secondaryLabel),
              validator: _kind == FeedbackKind.rules
                  ? null
                  : (value) =>
                        _required(value, min: 20, label: _secondaryLabel),
            ),
            if (_kind != FeedbackKind.feature)
              TextFormField(
                key: const ValueKey('feedback-optional'),
                controller: _optional,
                minLines: 2,
                maxLines: 8,
                maxLength: 8000,
                decoration: InputDecoration(labelText: _optionalLabel),
              ),
            if (_kind == FeedbackKind.bug)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Diagnosedaten mitsenden'),
                subtitle: const Text(
                  'Betriebssystem, Sprache, Fenster, Layout und Oberflächeneinstellungen. Vollständig in der Vorschau sichtbar.',
                ),
                value: _includeDiagnostics,
                onChanged: (value) => setState(() {
                  _includeDiagnostics = value ?? false;
                }),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: diagnosticsCollector == null
                  ? null
                  : () => _preview(user, controller, diagnosticsCollector),
              icon: collector.isLoading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.preview_outlined),
              label: const Text('Vorschau öffnen'),
            ),
            if (_result != null && _resultAccount == user.uid) ...[
              const SizedBox(height: 16),
              FeedbackResultView(
                result: _result!,
                refreshing: _refreshing,
                onRefresh: _result!.status == FeedbackResultStatus.created
                    ? null
                    : () => _refresh(user, controller),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _primaryLabel => switch (_kind) {
    FeedbackKind.bug => 'Was ist passiert?',
    FeedbackKind.feature => 'Welches Problem möchtest du lösen?',
    FeedbackKind.rules => 'Welche Regelfrage möchtest du klären?',
  };

  String get _secondaryLabel => switch (_kind) {
    FeedbackKind.bug => 'Was wurde erwartet?',
    FeedbackKind.feature => 'Wie soll es idealerweise funktionieren?',
    FeedbackKind.rules => 'Regelwerk/Fundstelle (optional)',
  };

  String get _optionalLabel => switch (_kind) {
    FeedbackKind.bug => 'Schritte zur Reproduktion (optional)',
    FeedbackKind.feature => 'Zusätzliche Hinweise (optional)',
    FeedbackKind.rules => 'Eigene Auslegung (optional)',
  };

  String? _required(String? value, {required int min, required String label}) {
    final length = value?.trim().characters.length ?? 0;
    if (length < min) return '$label benötigt mindestens $min Zeichen.';
    return null;
  }

  Future<void> _preview(
    AuthUser user,
    FeedbackController controller,
    FeedbackDiagnosticsCollector collector,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final submission = _buildSubmission(collector);
    final result = await showDialog<FeedbackResult>(
      context: context,
      builder: (_) => FeedbackPreviewDialog(
        submission: submission,
        onSend: () => controller.submit(user.uid, submission),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _result = result;
        _resultAccount = user.uid;
      });
    }
  }

  FeedbackSubmission _buildSubmission(FeedbackDiagnosticsCollector collector) {
    final metadata = collector.metadata();
    final requestId = const Uuid().v4();
    if (_kind == FeedbackKind.feature) {
      return FeatureFeedbackSubmission(
        requestId: requestId,
        title: _title.text,
        surface: _surface,
        metadata: metadata,
        problem: _primary.text,
        desiredBehavior: _secondary.text,
      );
    }
    if (_kind == FeedbackKind.rules) {
      return RulesFeedbackSubmission(
        requestId: requestId,
        title: _title.text,
        surface: _surface,
        metadata: metadata,
        question: _primary.text,
        source: _secondary.text,
        interpretation: _optional.text,
      );
    }
    return BugFeedbackSubmission(
      requestId: requestId,
      title: _title.text,
      surface: _surface,
      metadata: metadata,
      actualBehavior: _primary.text,
      expectedBehavior: _secondary.text,
      reproductionSteps: _optional.text,
      diagnostics: _includeDiagnostics ? _diagnostics(collector) : null,
    );
  }

  BugDiagnostics _diagnostics(FeedbackDiagnosticsCollector collector) {
    final media = MediaQuery.of(context);
    final settings =
        ref.read(appSettingsProvider).asData?.value ?? const AppSettings();
    final firebase = ref.read(firebaseBootstrapProvider);
    return collector.diagnostics(
      locale: Localizations.localeOf(context).toLanguageTag(),
      viewportWidth: media.size.width,
      viewportHeight: media.size.height,
      devicePixelRatio: media.devicePixelRatio,
      layoutClass: appLayoutOf(context).name,
      interfaceVariant: settings.oberflaeche.name,
      brightness: Theme.of(context).brightness.name,
      tableMode: switch (settings.tabellenAnsicht) {
        TabellenAnsicht.automatisch => 'automatic',
        TabellenAnsicht.tabelle => 'table',
        TabellenAnsicht.karten => 'cards',
      },
      firebaseAvailable: firebase.isAvailable,
      authenticated: true,
    );
  }

  void _loadPending(String accountId, FeedbackController controller) {
    if (_loadedAccount == accountId) return;
    _loadedAccount = accountId;
    controller.pending(accountId).then((pending) {
      if (!mounted || pending == null || _loadedAccount != accountId) return;
      setState(() {
        _result = FeedbackResult(
          requestId: pending.requestId,
          status: pending.status,
          issueNumber: pending.issueNumber,
          issueUrl: pending.issueUrl,
        );
        _resultAccount = accountId;
      });
    });
  }

  Future<void> _refresh(AuthUser user, FeedbackController controller) async {
    final requestId = _result?.requestId;
    if (_refreshing || requestId == null) return;
    setState(() => _refreshing = true);
    try {
      final result = await controller.refresh(user.uid, requestId);
      if (mounted) {
        setState(() {
          _result = result;
          _resultAccount = user.uid;
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }
}
