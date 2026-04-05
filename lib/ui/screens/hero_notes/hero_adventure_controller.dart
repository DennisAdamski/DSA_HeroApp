part of 'package:dsa_heldenverwaltung/ui/screens/hero_notes_tab.dart';

extension _HeroNotesAdventureController on _HeroNotesTabState {
  void _syncSelectedAdventureId({bool force = false}) {
    final currentId = force ? '' : _selectedAdventureId;
    _selectedAdventureId = _resolveSelectedAdventureId(
      _draftAdventures,
      currentId: currentId,
    );
  }

  HeroAdventureEntry? get _selectedAdventure {
    return _findAdventureById(_draftAdventures, _selectedAdventureId);
  }

  int get _selectedAdventureIndex {
    final selectedAdventureId = _selectedAdventureId.trim();
    if (selectedAdventureId.isEmpty) {
      return -1;
    }
    return _draftAdventures.indexWhere(
      (entry) => entry.id == selectedAdventureId,
    );
  }

  Future<void> _showAddAdventureDialog() async {
    await _startEditIfNeeded();
    if (!mounted) {
      return;
    }
    final createdAdventure = await _showAdventureCreateDialog(
      context: context,
      initial: HeroAdventureEntry(
        id: _uuid.v4(),
        startWorldDate: HeroAdventureDateValue.fromDateTime(DateTime.now()),
      ),
    );
    if (!mounted || createdAdventure == null) {
      return;
    }

    _innerTabController.animateTo(2);
    _setAdventureDrafts(
      List<HeroAdventureEntry>.from(_draftAdventures)..add(createdAdventure),
      selectedAdventureId: createdAdventure.id,
    );
  }

  void _selectAdventure(String adventureId) {
    final normalizedId = adventureId.trim();
    if (normalizedId.isEmpty || normalizedId == _selectedAdventureId) {
      return;
    }
    if (_findAdventureById(_draftAdventures, normalizedId) == null) {
      return;
    }
    _updateWidgetState(() {
      _selectedAdventureId = normalizedId;
    });
  }

  void _removeSelectedAdventure() {
    final selectedIndex = _selectedAdventureIndex;
    if (selectedIndex < 0) {
      return;
    }

    final adventure = _draftAdventures[selectedIndex];
    if (adventure.rewardsApplied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Angewendete Abenteuer müssen erst zurückgenommen werden.',
          ),
        ),
      );
      return;
    }

    final nextAdventures = List<HeroAdventureEntry>.from(_draftAdventures)
      ..removeAt(selectedIndex);
    _setAdventureDrafts(
      nextAdventures,
      cleanupConnectionReferences: true,
      preferDefaultSelection: true,
    );
  }

  void _moveSelectedAdventure(int direction) {
    final selectedIndex = _selectedAdventureIndex;
    if (selectedIndex < 0) {
      return;
    }

    final targetIndex = selectedIndex + direction;
    if (targetIndex < 0 || targetIndex >= _draftAdventures.length) {
      return;
    }

    final nextAdventures = List<HeroAdventureEntry>.from(_draftAdventures);
    final currentAdventure = nextAdventures.removeAt(selectedIndex);
    nextAdventures.insert(targetIndex, currentAdventure);
    _setAdventureDrafts(
      nextAdventures,
      selectedAdventureId: currentAdventure.id,
    );
  }

  void _updateSelectedAdventure({
    String? title,
    String? summary,
    HeroAdventureStatus? status,
    HeroAdventureDateValue? startWorldDate,
    HeroAdventureDateValue? startAventurianDate,
    HeroAdventureDateValue? endWorldDate,
    HeroAdventureDateValue? endAventurianDate,
    HeroAdventureDateValue? currentAventurianDate,
    int? apReward,
    List<HeroNoteEntry>? notes,
    List<HeroAdventurePersonEntry>? people,
    List<HeroAdventureSeReward>? seRewards,
    bool preferDefaultSelection = false,
  }) {
    final selectedIndex = _selectedAdventureIndex;
    if (selectedIndex < 0) {
      return;
    }

    final nextAdventures = List<HeroAdventureEntry>.from(_draftAdventures);
    nextAdventures[selectedIndex] = nextAdventures[selectedIndex].copyWith(
      title: title,
      summary: summary,
      status: status,
      startWorldDate: startWorldDate,
      startAventurianDate: startAventurianDate,
      endWorldDate: endWorldDate,
      endAventurianDate: endAventurianDate,
      currentAventurianDate: currentAventurianDate,
      apReward: apReward,
      notes: notes,
      people: people,
      seRewards: seRewards,
    );
    _setAdventureDrafts(
      nextAdventures,
      selectedAdventureId: nextAdventures[selectedIndex].id,
      preferDefaultSelection: preferDefaultSelection,
    );
  }

  void _updateSelectedAdventureTitle(String value) {
    _updateSelectedAdventure(title: value);
  }

  void _updateSelectedAdventureSummary(String value) {
    _updateSelectedAdventure(summary: value);
  }

  void _updateSelectedAdventureStartWorldDate(HeroAdventureDateValue value) {
    _updateSelectedAdventure(startWorldDate: value);
  }

  void _updateSelectedAdventureStartAventurianDate(
    HeroAdventureDateValue value,
  ) {
    _updateSelectedAdventure(startAventurianDate: value);
  }

  void _updateSelectedAdventureEndWorldDate(HeroAdventureDateValue value) {
    _updateSelectedAdventure(endWorldDate: value);
  }

  void _updateSelectedAdventureEndAventurianDate(HeroAdventureDateValue value) {
    _updateSelectedAdventure(endAventurianDate: value);
  }

  void _updateSelectedAdventureCurrentAventurianDate(
    HeroAdventureDateValue value,
  ) {
    _updateSelectedAdventure(currentAventurianDate: value);
  }

  void _updateSelectedAdventureApReward(String rawValue) {
    final parsedValue = int.tryParse(rawValue.trim()) ?? 0;
    _updateSelectedAdventure(apReward: parsedValue < 0 ? 0 : parsedValue);
  }

  Future<void> _addNoteForSelectedAdventure() async {
    await _startEditIfNeeded();
    if (!mounted) {
      return;
    }
    final createdNote = await _showAdventureNoteDialog(
      context: context,
      isEditing: true,
    );
    if (!mounted || createdNote == null) {
      return;
    }

    final adventure = _selectedAdventure;
    if (adventure == null) {
      return;
    }

    final nextNotes = List<HeroNoteEntry>.from(adventure.notes)
      ..add(createdNote.entry);
    _updateSelectedAdventure(notes: nextNotes);
  }

  Future<void> _openAdventureNoteDialog(int noteIndex) async {
    final adventure = _selectedAdventure;
    if (adventure == null ||
        noteIndex < 0 ||
        noteIndex >= adventure.notes.length) {
      return;
    }

    final dialogResult = await _showAdventureNoteDialog(
      context: context,
      existing: adventure.notes[noteIndex],
      isEditing: _editController.isEditing,
    );
    if (dialogResult == null || !_editController.isEditing) {
      return;
    }

    final nextNotes = List<HeroNoteEntry>.from(adventure.notes);
    if (dialogResult.deleteRequested) {
      nextNotes.removeAt(noteIndex);
    } else {
      nextNotes[noteIndex] = dialogResult.entry;
    }
    _updateSelectedAdventure(notes: nextNotes);
  }

  Future<void> _addPersonForSelectedAdventure() async {
    await _startEditIfNeeded();
    if (!mounted) {
      return;
    }
    final createdPerson = await _showAdventurePersonDialog(
      context: context,
      initial: HeroAdventurePersonEntry(id: _uuid.v4()),
      isEditing: true,
    );
    if (!mounted || createdPerson == null) {
      return;
    }

    final adventure = _selectedAdventure;
    if (adventure == null) {
      return;
    }

    final nextPeople = List<HeroAdventurePersonEntry>.from(adventure.people)
      ..add(createdPerson.entry);
    _updateSelectedAdventure(people: nextPeople);
  }

  Future<void> _openAdventurePersonDialog(int personIndex) async {
    final adventure = _selectedAdventure;
    if (adventure == null ||
        personIndex < 0 ||
        personIndex >= adventure.people.length) {
      return;
    }

    final dialogResult = await _showAdventurePersonDialog(
      context: context,
      initial: adventure.people[personIndex],
      isEditing: _editController.isEditing,
    );
    if (dialogResult == null || !_editController.isEditing) {
      return;
    }

    final nextPeople = List<HeroAdventurePersonEntry>.from(adventure.people);
    if (dialogResult.deleteRequested) {
      nextPeople.removeAt(personIndex);
    } else {
      nextPeople[personIndex] = dialogResult.entry;
    }
    _updateSelectedAdventure(people: nextPeople);
  }

  void _addSeRewardToSelectedAdventure() {
    final adventure = _selectedAdventure;
    if (adventure == null) {
      return;
    }

    final nextRewards = List<HeroAdventureSeReward>.from(adventure.seRewards)
      ..add(const HeroAdventureSeReward(count: 1));
    _updateSelectedAdventure(seRewards: nextRewards);
  }

  void _removeSeRewardFromSelectedAdventure(int rewardIndex) {
    final adventure = _selectedAdventure;
    if (adventure == null ||
        rewardIndex < 0 ||
        rewardIndex >= adventure.seRewards.length) {
      return;
    }

    final nextRewards = List<HeroAdventureSeReward>.from(adventure.seRewards)
      ..removeAt(rewardIndex);
    _updateSelectedAdventure(seRewards: nextRewards);
  }

  void _updateSelectedAdventureSeRewardCount(int rewardIndex, String rawValue) {
    final parsedValue = int.tryParse(rawValue.trim()) ?? 0;
    _updateSelectedAdventureSeReward(
      rewardIndex,
      count: parsedValue < 0 ? 0 : parsedValue,
    );
  }

  void _updateSelectedAdventureSeRewardType(
    int rewardIndex,
    HeroAdventureSeTargetType targetType, {
    required HeroSheet hero,
    RulesCatalog? catalog,
  }) {
    final defaultOption = _defaultOptionForTargetType(
      targetType: targetType,
      hero: hero,
      catalog: catalog,
    );
    _updateSelectedAdventureSeReward(
      rewardIndex,
      targetType: targetType,
      targetId: defaultOption?.id ?? '',
      targetLabel: defaultOption?.label ?? '',
    );
  }

  void _updateSelectedAdventureSeRewardTarget(
    int rewardIndex, {
    required String targetId,
    required String targetLabel,
  }) {
    _updateSelectedAdventureSeReward(
      rewardIndex,
      targetId: targetId,
      targetLabel: targetLabel,
    );
  }

  void _updateSelectedAdventureSeReward(
    int rewardIndex, {
    HeroAdventureSeTargetType? targetType,
    String? targetId,
    String? targetLabel,
    int? count,
  }) {
    final adventure = _selectedAdventure;
    if (adventure == null ||
        rewardIndex < 0 ||
        rewardIndex >= adventure.seRewards.length) {
      return;
    }

    final nextRewards = List<HeroAdventureSeReward>.from(adventure.seRewards);
    nextRewards[rewardIndex] = nextRewards[rewardIndex].copyWith(
      targetType: targetType,
      targetId: targetId,
      targetLabel: targetLabel,
      count: count,
    );
    _updateSelectedAdventure(seRewards: nextRewards);
  }

  HeroAdventureEntry _sanitizeAdventure(HeroAdventureEntry adventure) {
    return adventure.copyWith(
      title: adventure.title.trim(),
      summary: adventure.summary.trim(),
      notes: adventure.notes
          .map(_sanitizeAdventureNote)
          .where(_hasNoteContent)
          .toList(growable: false),
      people: adventure.people
          .map(_sanitizeAdventurePerson)
          .where((entry) => entry.hasContent)
          .toList(growable: false),
      startWorldDate: _sanitizeAdventureDate(adventure.startWorldDate),
      startAventurianDate: _sanitizeAdventureDate(
        adventure.startAventurianDate,
      ),
      endWorldDate: _sanitizeAdventureDate(adventure.endWorldDate),
      endAventurianDate: _sanitizeAdventureDate(adventure.endAventurianDate),
      currentAventurianDate: _sanitizeAdventureDate(
        adventure.currentAventurianDate,
      ),
      seRewards: adventure.seRewards
          .where((entry) => entry.hasContent)
          .toList(growable: false),
      lootRewards: adventure.lootRewards
          .map(_sanitizeAdventureLoot)
          .where((entry) => entry.hasContent)
          .toList(growable: false),
    );
  }

  HeroNoteEntry _sanitizeAdventureNote(HeroNoteEntry note) {
    return note.copyWith(
      title: note.title.trim(),
      description: note.description.trim(),
    );
  }

  HeroAdventurePersonEntry _sanitizeAdventurePerson(
    HeroAdventurePersonEntry person,
  ) {
    return person.copyWith(
      name: person.name.trim(),
      description: person.description.trim(),
    );
  }

  HeroAdventureDateValue _sanitizeAdventureDate(HeroAdventureDateValue value) {
    return value.copyWith(
      day: value.day.trim(),
      month: value.month.trim(),
      year: value.year.trim(),
    );
  }

  HeroAdventureLootEntry _sanitizeAdventureLoot(HeroAdventureLootEntry loot) {
    return loot.copyWith(
      name: loot.name.trim(),
      quantity: loot.quantity.trim(),
      origin: loot.origin.trim(),
      description: loot.description.trim(),
    );
  }

  HeroAdventureEntry? _findAdventureById(
    List<HeroAdventureEntry> adventures,
    String adventureId,
  ) {
    for (final adventure in adventures) {
      if (adventure.id == adventureId) {
        return adventure;
      }
    }
    return null;
  }

  List<_AdventureTargetOption> _buildTalentTargetOptions(
    HeroSheet hero,
    RulesCatalog? catalog,
  ) {
    final optionsById = <String, _AdventureTargetOption>{};

    void addOption(String id, String label) {
      final normalizedId = id.trim();
      final normalizedLabel = label.trim();
      if (normalizedId.isEmpty) {
        return;
      }
      optionsById.putIfAbsent(
        normalizedId,
        () => _AdventureTargetOption(
          id: normalizedId,
          label: normalizedLabel.isEmpty ? normalizedId : normalizedLabel,
        ),
      );
    }

    if (catalog != null) {
      final sortedTalents = List<TalentDef>.from(catalog.talents)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final talent in sortedTalents) {
        addOption(talent.id, talent.name);
      }
    }

    for (final talentId in hero.talents.keys) {
      addOption(talentId, talentId);
    }

    for (final adventure in _draftAdventures) {
      for (final reward in adventure.seRewards) {
        if (reward.targetType != HeroAdventureSeTargetType.talent) {
          continue;
        }
        addOption(reward.targetId, reward.targetLabel);
      }
    }

    final options = optionsById.values.toList(growable: false)
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  List<_AdventureTargetOption> _targetOptionsForType({
    required HeroAdventureSeTargetType targetType,
    required HeroSheet hero,
    RulesCatalog? catalog,
  }) {
    return switch (targetType) {
      HeroAdventureSeTargetType.talent => _buildTalentTargetOptions(
        hero,
        catalog,
      ),
      HeroAdventureSeTargetType.grundwert => _grundwertTargetOptions,
      HeroAdventureSeTargetType.eigenschaft => _attributeTargetOptions,
    };
  }

  _AdventureTargetOption? _defaultOptionForTargetType({
    required HeroAdventureSeTargetType targetType,
    required HeroSheet hero,
    RulesCatalog? catalog,
  }) {
    final options = _targetOptionsForType(
      targetType: targetType,
      hero: hero,
      catalog: catalog,
    );
    return options.isEmpty ? null : options.first;
  }

  String _resolveSelectedAdventureId(
    List<HeroAdventureEntry> adventures, {
    String currentId = '',
  }) {
    final normalizedCurrentId = currentId.trim();
    if (normalizedCurrentId.isNotEmpty &&
        adventures.any((entry) => entry.id == normalizedCurrentId)) {
      return normalizedCurrentId;
    }

    final currentAdventure = adventures.firstWhere(
      (entry) => entry.status == HeroAdventureStatus.current,
      orElse: () => adventures.firstOrNull ?? const HeroAdventureEntry(id: ''),
    );
    return currentAdventure.id;
  }

  void _setAdventureDrafts(
    List<HeroAdventureEntry> nextAdventures, {
    String? selectedAdventureId,
    bool cleanupConnectionReferences = false,
    bool preferDefaultSelection = false,
  }) {
    final currentId = preferDefaultSelection
        ? ''
        : selectedAdventureId ?? _selectedAdventureId;
    final resolvedAdventureId = _resolveSelectedAdventureId(
      nextAdventures,
      currentId: currentId,
    );
    _updateWidgetState(() {
      _draftAdventures = nextAdventures;
      _selectedAdventureId = resolvedAdventureId;
      if (cleanupConnectionReferences) {
        _draftConnections = cleanupAdventureReferences(
          connections: _draftConnections,
          validAdventureIds: nextAdventures.map((entry) => entry.id),
        );
      }
    });
    _markFieldChanged();
  }
}
