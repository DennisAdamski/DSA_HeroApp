import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_style.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/avatar_prompt_rules.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Dialog fuer die KI-basierte Portraet-Generierung.
class AvatarGenerationDialog extends ConsumerStatefulWidget {
  const AvatarGenerationDialog({
    super.key,
    required this.heroId,
    required this.hero,
  });

  final String heroId;
  final HeroSheet hero;

  @override
  ConsumerState<AvatarGenerationDialog> createState() =>
      _AvatarGenerationDialogState();
}

class _AvatarGenerationDialogState
    extends ConsumerState<AvatarGenerationDialog> {
  final _promptController = TextEditingController();
  AvatarStyle _selectedStyle = AvatarStyle.fantasyIllustration;
  bool _loading = false;
  bool _hasManualPromptEdits = false;
  Uint8List? _resultBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _promptController.text = _autoPrompt;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  String get _autoPrompt =>
      buildAvatarPrompt(hero: widget.hero, style: _selectedStyle);

  String get _currentPrompt => _promptController.text.trim();

  @override
  Widget build(BuildContext context) {
    final estimatedCost = ref.watch(avatarEstimatedCostProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Portraet generieren',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (_resultBytes != null) ...[
                  _buildResultView(),
                ] else ...[
                  _buildConfigView(estimatedCost),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigView(double? estimatedCost) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Stil', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AvatarStyle.values
              .map((style) {
                final selected = style == _selectedStyle;
                return ChoiceChip(
                  label: Text(style.displayName),
                  selected: selected,
                  onSelected: (_) => _selectStyle(style),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey<String>('avatar-generation-prompt-field'),
          controller: _promptController,
          decoration: const InputDecoration(
            labelText: 'Prompt',
            hintText: 'Der vollstaendige Prompt kann hier angepasst werden.',
            helperText: 'Beim Oeffnen automatisch aus den Heldendaten erzeugt.',
            border: OutlineInputBorder(),
          ),
          minLines: 6,
          maxLines: 12,
          onChanged: (_) {
            if (_loading) {
              return;
            }
            setState(() {
              _hasManualPromptEdits = true;
            });
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              key: const ValueKey<String>('avatar-generation-reset-prompt'),
              onPressed: _loading ? null : _resetPromptToAutoPrompt,
              icon: const Icon(Icons.refresh),
              label: const Text('Neu aus Heldendaten erzeugen'),
            ),
            Text(
              _hasManualPromptEdits
                  ? 'Manuell angepasst'
                  : 'Automatisch mit Stil synchronisiert',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (estimatedCost != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Geschaetzte Kosten: ~\$${estimatedCost.toStringAsFixed(2)} USD '
                  '(ueber deinen API-Key)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        if (_error != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_loading ? 'Generiere...' : 'Generieren'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: Image.memory(_resultBytes!, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _loading ? null : _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Nochmal'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _accept,
              icon: const Icon(Icons.check),
              label: const Text('Uebernehmen'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _generate() async {
    final client = ref.read(avatarApiClientProvider);
    if (client == null) return;
    if (_currentPrompt.isEmpty) {
      setState(() {
        _error = 'Der Prompt darf nicht leer sein.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = await client.generatePortrait(prompt: _currentPrompt);
      if (!mounted) return;
      setState(() {
        _resultBytes = Uint8List.fromList(bytes);
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _selectStyle(AvatarStyle style) {
    setState(() {
      _selectedStyle = style;
      if (!_hasManualPromptEdits) {
        _promptController.text = _autoPrompt;
      }
    });
  }

  void _resetPromptToAutoPrompt() {
    setState(() {
      _promptController.text = _autoPrompt;
      _hasManualPromptEdits = false;
      _error = null;
    });
  }

  void _retry() {
    setState(() {
      _resultBytes = null;
      _error = null;
    });
  }

  Future<void> _accept() async {
    if (_resultBytes == null) return;
    setState(() => _loading = true);

    try {
      await ref
          .read(heroActionsProvider)
          .saveHeroAvatar(heroId: widget.heroId, pngBytes: _resultBytes!);
      if (!mounted) return;
      Navigator.pop(context);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }
}
