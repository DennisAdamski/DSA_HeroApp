part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroOverviewBaseInfoSection on _HeroOverviewTabState {
  Widget _buildBaseInfoSection(HeroSheet hero) {
    final hasAvatar = hero.appearance.avatarFileName.isNotEmpty;

    if (!hasAvatar) {
      return _SectionCard(
        title: 'Basisinformationen',
        child: Column(
          children: [
            _buildStandardFieldLayout(),
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
            return _buildWideAvatarBaseInfo(hero, constraints);
          }
          return _buildNarrowAvatarBaseInfo(hero);
        },
      ),
    );
  }

  /// Breites Layout: Feldgrid links, Avatar rechts.
  Widget _buildWideAvatarBaseInfo(HeroSheet hero, BoxConstraints constraints) {
    final avatarWidth = (constraints.maxWidth * 0.25).clamp(150.0, 280.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(label: 'Name', keyName: 'name'),
        const SizedBox(height: _gridSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: _buildStandardFieldRows())),
            const SizedBox(width: _gridSpacing),
            SizedBox(
              width: avatarWidth,
              child: Column(
                children: [
                  _AvatarDisplay(
                    heroId: widget.heroId,
                    avatarFileName: hero.appearance.avatarFileName,
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
  Widget _buildNarrowAvatarBaseInfo(HeroSheet hero) {
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
              avatarFileName: hero.appearance.avatarFileName,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _HasAvatarActions(heroId: widget.heroId, hero: hero),
        const SizedBox(height: _gridSpacing),
        ..._buildStandardFieldRows(),
      ],
    );
  }

  /// Standard-Feldanordnung ohne Avatar (wie das urspruengliche Layout).
  Widget _buildStandardFieldLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(label: 'Name', keyName: 'name'),
        const SizedBox(height: _gridSpacing),
        ..._buildStandardFieldRows(),
      ],
    );
  }

  List<Widget> _buildStandardFieldRows() {
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
          _buildInputField(label: 'Groesse', keyName: 'groesse'),
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

  Widget _buildAdvantagesSection() {
    return _SectionCard(
      title: 'Vorteile und Nachteile',
      child: _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          _buildInputField(
            label: 'Vorteile',
            keyName: 'vorteile',
            minLines: 2,
            maxLines: null,
          ),
          _buildInputField(
            label: 'Nachteile',
            keyName: 'nachteile',
            minLines: 2,
            maxLines: null,
          ),
        ],
      ),
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
