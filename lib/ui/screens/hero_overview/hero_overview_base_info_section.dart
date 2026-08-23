part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroOverviewBaseInfoSection on _HeroOverviewTabState {
  Widget _buildBaseInfoSection(HeroSheet hero) {
    final aktivesBild = hero.appearance.aktivesBild;

    if (aktivesBild == null) {
      return _SectionCard(
        title: 'Basisinformationen',
        child: Column(
          children: [
            _buildStandardFieldLayout(hero),
            const SizedBox(height: _gridSpacing),
            const _SketchedAvatarPlaceholder(),
            const SizedBox(height: _gridSpacing),
            Center(
              child: _NoAvatarActions(heroId: widget.heroId, hero: hero),
            ),
          ],
        ),
      );
    }

    // Mit Avatar: LayoutBuilder entscheidet zwischen 3-Spalten und Standard.
    return _SectionCard(
      title: 'Basisinformationen',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          if (isWide) {
            return _buildWideAvatarBaseInfo(hero, aktivesBild, constraints);
          }
          return _buildNarrowAvatarBaseInfo(hero, aktivesBild);
        },
      ),
    );
  }

  /// Breites Layout: Feldgrid links, Avatar rechts.
  Widget _buildWideAvatarBaseInfo(
    HeroSheet hero,
    AvatarGalleryEntry aktivesBild,
    BoxConstraints constraints,
  ) {
    final avatarWidth = (constraints.maxWidth * 0.25).clamp(150.0, 280.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(label: 'Name', keyName: 'name'),
        const SizedBox(height: _gridSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: _buildStandardFieldRows(hero))),
            const SizedBox(width: _gridSpacing),
            SizedBox(
              width: avatarWidth,
              child: Column(
                children: [
                  _AvatarDisplay(
                    heroId: widget.heroId,
                    fileName: aktivesBild.fileName,
                  ),
                  const SizedBox(height: 8),
                  _HasAvatarActions(heroId: widget.heroId, hero: hero),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Schmales Layout mit Avatar: Bild oben, dann Felder.
  Widget _buildNarrowAvatarBaseInfo(
    HeroSheet hero,
    AvatarGalleryEntry aktivesBild,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(label: 'Name', keyName: 'name'),
        const SizedBox(height: _gridSpacing),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: _AvatarDisplay(
              heroId: widget.heroId,
              fileName: aktivesBild.fileName,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _HasAvatarActions(heroId: widget.heroId, hero: hero),
        const SizedBox(height: _gridSpacing),
        ..._buildStandardFieldRows(hero),
      ],
    );
  }

  /// Standard-Feldanordnung ohne Avatar (wie das urspruengliche Layout).
  Widget _buildStandardFieldLayout(HeroSheet hero) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(label: 'Name', keyName: 'name'),
        const SizedBox(height: _gridSpacing),
        ..._buildStandardFieldRows(hero),
      ],
    );
  }

  List<Widget> _buildStandardFieldRows(HeroSheet hero) {
    return [
      _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          _buildInputField(label: 'Rasse', keyName: 'rasse'),
          _buildInputField(label: 'Rasse Modifikatoren', keyName: 'rasse_mod'),
        ],
      ),
      const SizedBox(height: _gridSpacing),
      _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          _buildInputField(label: 'Kultur', keyName: 'kultur'),
          _buildInputField(
            label: 'Kultur Modifikatoren',
            keyName: 'kultur_mod',
          ),
        ],
      ),
      const SizedBox(height: _gridSpacing),
      _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          _buildInputField(label: 'Profession', keyName: 'profession'),
          _buildInputField(
            label: 'Profession Modifikatoren',
            keyName: 'profession_mod',
          ),
        ],
      ),
      const SizedBox(height: _gridSpacing),
      _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          _buildInputField(label: 'Geschlecht', keyName: 'geschlecht'),
          _buildInputField(label: 'Alter', keyName: 'alter'),
          _buildBirthDateField(hero),
          _buildCurrentAgeField(hero),
          _buildInputField(label: 'Größe', keyName: 'groesse'),
          _buildInputField(label: 'Gewicht', keyName: 'gewicht'),
          _buildInputField(label: 'Haarfarbe', keyName: 'haarfarbe'),
          _buildInputField(label: 'Augenfarbe', keyName: 'augenfarbe'),
          _buildInputField(label: 'Stand', keyName: 'stand'),
          _buildInputField(label: 'Titel', keyName: 'titel'),
          _buildInputField(
            label: 'Sozialstatus',
            keyName: 'sozialstatus',
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      const SizedBox(height: _gridSpacing),
      _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          _buildInputField(
            label: 'Aussehen',
            keyName: 'aussehen',
            minLines: 4,
            maxLines: 6,
          ),
          _buildInputField(
            label: 'Familie/Herkunft/Hintergrund',
            keyName: 'familie',
            minLines: 4,
            maxLines: 6,
          ),
        ],
      ),
    ];
  }

  /// Aventurisches Geburtsdatum: gelesen als formatierter Text, bearbeitet als
  /// Tag, Monatsauswahl und Jahr.
  Widget _buildBirthDateField(HeroSheet hero) {
    final geburtsdatum = _visibleBirthDate(hero);
    if (!_editController.isEditing) {
      return _buildReadOnlyValueField(
        key: const ValueKey<String>('overview-field-geburtsdatum'),
        label: 'Geburtsdatum',
        value: formatAventurianDate(geburtsdatum),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            key: const ValueKey<String>('overview-field-geburt-tag'),
            controller: _field('geburt_tag'),
            maxLines: 1,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('Tag'),
            onChanged: _onFieldChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 4, child: _buildBirthMonthDropdown()),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            key: const ValueKey<String>('overview-field-geburt-jahr'),
            controller: _field('geburt_jahr'),
            maxLines: 1,
            decoration: _inputDecoration('Jahr (BF)'),
            onChanged: _onFieldChanged,
          ),
        ),
      ],
    );
  }

  /// Monatsauswahl auf Basis des kanonischen aventurischen Kalenders.
  ///
  /// Bewusst ein `DropdownButton` statt eines `DropdownButtonFormField`: Der
  /// Monat lebt in einem Entwurfsfeld, und nur der Button uebernimmt einen von
  /// aussen geaenderten Wert bei jedem Rebuild zuverlaessig.
  Widget _buildBirthMonthDropdown() {
    final selectedMonth = _draftGeburtsmonat.isEmpty
        ? null
        : _draftGeburtsmonat;
    final items = aventurianMonths
        .map(
          (month) => DropdownMenuItem<String>(
            value: month.value,
            child: Text(
              month.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(growable: false);

    return InputDecorator(
      decoration: _inputDecoration('Monat'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const ValueKey<String>('overview-field-geburt-monat'),
          value: selectedMonth,
          isExpanded: true,
          isDense: true,
          hint: const Text('–'),
          items: items,
          onChanged: (month) => _applyDraftGeburtsmonat(month ?? ''),
        ),
      ),
    );
  }

  /// Aus Geburtsdatum und Abenteuerdatum abgeleitetes Alter (nie editierbar).
  Widget _buildCurrentAgeField(HeroSheet hero) {
    final geburtsdatum = _visibleBirthDate(hero);
    final aktuellesAlter = computeHeroAgeForBirthDate(hero, geburtsdatum);
    return _buildReadOnlyValueField(
      key: const ValueKey<String>('overview-field-alter-aktuell'),
      label: 'Alter (aktuell)',
      value: aktuellesAlter?.toString() ?? '',
    );
  }

  Widget _buildAdvantagesSection() {
    return _SectionCard(
      title: 'Vorteile und Nachteile',
      child: _buildTraitSelectionSection(),
    );
  }

  Widget _buildParserWarningsSection(HeroSheet hero) {
    return _SectionCard(
      title: 'Parser-Warnungen',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: hero.unknownModifierFragments
            .map((entry) => Chip(label: Text(entry)))
            .toList(growable: false),
      ),
    );
  }
}
