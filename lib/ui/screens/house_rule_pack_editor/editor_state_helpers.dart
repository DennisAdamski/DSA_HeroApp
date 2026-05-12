// ignore_for_file: invalid_use_of_protected_member

part of '../house_rule_pack_editor_screen.dart';

extension _HouseRulePackEditorState on _HouseRulePackEditorScreenState {
  void _handleTabChange() {
    if (_isHandlingTabChange || !_tabController.indexIsChanging) {
      return;
    }
    final nextIndex = _tabController.index;
    if (_previousTabIndex == nextIndex) {
      return;
    }

    if (_previousTabIndex == 0 && nextIndex == 1) {
      try {
        _syncStructuredToJson();
        _previousTabIndex = nextIndex;
      } on FormatException catch (error) {
        setState(() => _errorText = error.message);
        _restorePreviousTab();
      }
      return;
    }

    if (_previousTabIndex == 1 && nextIndex == 0) {
      try {
        _applyJsonToStructured();
        _previousTabIndex = nextIndex;
      } on FormatException catch (error) {
        setState(() => _errorText = error.message);
        _restorePreviousTab();
      }
    }
  }

  void _restorePreviousTab() {
    _isHandlingTabChange = true;
    _tabController.index = _previousTabIndex;
    _isHandlingTabChange = false;
  }

  void _loadStructuredState(Map<String, dynamic> manifestJson) {
    _idController.text = manifestJson['id']?.toString() ?? '';
    _titleController.text = manifestJson['title']?.toString() ?? '';
    _descriptionController.text = manifestJson['description']?.toString() ?? '';
    _parentPackIdController.text =
        manifestJson['parentPackId']?.toString() ?? '';
    _priorityController.text = manifestJson['priority']?.toString() ?? '';

    final rawPatches = manifestJson['patches'];
    if (rawPatches != null && rawPatches is! List) {
      throw const FormatException(
        'Hausregel-Paket erwartet eine JSON-Liste in "patches".',
      );
    }
    final patchDrafts = <_PatchDraftControllers>[];
    for (final rawPatch in rawPatches as List? ?? const <Object?>[]) {
      if (rawPatch is Map<String, dynamic>) {
        patchDrafts.add(
          _PatchDraftControllers.fromDraftJson(rawPatch, encoder: _jsonEncoder),
        );
        continue;
      }
      if (rawPatch is Map) {
        patchDrafts.add(
          _PatchDraftControllers.fromDraftJson(
            rawPatch.cast<String, dynamic>(),
            encoder: _jsonEncoder,
          ),
        );
        continue;
      }
      throw const FormatException(
        'Hausregel-Paket darf in "patches" nur JSON-Objekte enthalten.',
      );
    }

    final obsoletePatches = <_PatchDraftControllers>[];
    while (_patches.length > patchDrafts.length) {
      obsoletePatches.add(_patches.removeLast());
    }
    for (var index = 0; index < patchDrafts.length; index++) {
      final draft = patchDrafts[index];
      if (index < _patches.length) {
        _patches[index].overwriteFrom(draft);
        draft.dispose();
        continue;
      }
      _patches.add(draft);
    }
    if (obsoletePatches.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final patch in obsoletePatches) {
          patch.dispose();
        }
      });
    }
  }

  void _syncStructuredToJson() {
    _jsonController.text = _jsonEncoder.convert(_buildStructuredManifestJson());
    _errorText = '';
  }

  void _applyJsonToStructured() {
    final decoded = _parseJsonObject(
      _jsonController.text,
      fieldLabel: 'Manifest-JSON',
    );
    _loadStructuredState(decoded);
    _errorText = '';
  }

  Map<String, dynamic> _buildCurrentManifestJson() {
    if (_tabController.index == 1) {
      return _parseJsonObject(
        _jsonController.text,
        fieldLabel: 'Manifest-JSON',
      );
    }
    return _buildStructuredManifestJson();
  }

  Map<String, dynamic> _buildStructuredManifestJson() {
    final manifestJson = <String, dynamic>{
      'id': _idController.text.trim(),
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'patches': _patches
          .map((patch) => patch.buildJson())
          .toList(growable: false),
    };

    final parentPackId = _parentPackIdController.text.trim();
    if (parentPackId.isNotEmpty) {
      manifestJson['parentPackId'] = parentPackId;
    }

    final priorityText = _priorityController.text.trim();
    if (priorityText.isNotEmpty) {
      manifestJson['priority'] = _parseInteger(
        priorityText,
        fieldLabel: 'Standard-Priorität',
      );
    }

    return manifestJson;
  }

  void _formatJson() {
    try {
      final manifestJson = _parseJsonObject(
        _jsonController.text,
        fieldLabel: 'Manifest-JSON',
      );
      _jsonController.text = _jsonEncoder.convert(manifestJson);
      setState(() => _errorText = '');
    } on FormatException catch (error) {
      setState(() => _errorText = error.message);
    }
  }

  void _addPatch() {
    setState(() {
      _patches.add(_PatchDraftControllers.empty());
      _markValidationStale();
    });
  }

  void _duplicatePatch(int index) {
    setState(() {
      _patches.insert(
        index + 1,
        _patches[index].duplicate(encoder: _jsonEncoder),
      );
      _markValidationStale();
    });
  }

  void _movePatch(int index, int delta) {
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= _patches.length) {
      return;
    }
    setState(() {
      final patch = _patches.removeAt(index);
      _patches.insert(nextIndex, patch);
      _markValidationStale();
    });
  }

  void _removePatch(int index) {
    setState(() {
      final patch = _patches.removeAt(index);
      patch.dispose();
      _markValidationStale();
    });
  }

  void _markValidationStale() {
    _validationIsStale = true;
  }

  Map<String, dynamic> _parseJsonObject(
    String rawText, {
    required String fieldLabel,
  }) {
    final normalizedText = rawText.trim();
    if (normalizedText.isEmpty) {
      throw FormatException('$fieldLabel darf nicht leer sein.');
    }
    final decoded = jsonDecode(normalizedText);
    if (decoded is! Map) {
      throw FormatException('$fieldLabel erwartet ein JSON-Objekt.');
    }
    return decoded.cast<String, dynamic>();
  }

  int _parseInteger(String rawText, {required String fieldLabel}) {
    final value = int.tryParse(rawText.trim());
    if (value == null) {
      throw FormatException('$fieldLabel erwartet eine Ganzzahl.');
    }
    return value;
  }
}
