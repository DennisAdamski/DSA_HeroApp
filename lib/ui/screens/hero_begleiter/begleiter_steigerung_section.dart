part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Steigerung (nur Vertraute)
// ---------------------------------------------------------------------------

class _SteigerungSection extends StatelessWidget {
  const _SteigerungSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
    required this.onSaveImmediate,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  /// Speichert den Companion sofort (fuer AP-Verbrauch ausserhalb des
  /// Edit-Modus-Drafts).
  final ValueChanged<HeroCompanion> onSaveImmediate;

  int get _apVerfuegbar => companionApVerfuegbar(companion);

  // ---- Hilfsmethoden -------------------------------------------------------

  Future<void> _steigereWert(
    BuildContext context, {
    required String label,
    required String key,
    required int aktuellerSteigerungswert,
    required int maxWert,
  }) async {
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: '$label (Vertrauter)',
      aktuellerWert: aktuellerSteigerungswert,
      maxWert: maxWert,
      effektiveKomplexitaet: kVertrauterKomplexitaet,
      verfuegbareAp: _apVerfuegbar,
    );
    if (result == null) return;

    final neueSteigerungen = Map<String, int>.from(companion.steigerungen);
    neueSteigerungen[key] = result.neuerWert;

    final updated = companion.copyWith(
      steigerungen: neueSteigerungen,
      apAusgegeben: (companion.apAusgegeben ?? 0) + result.apKosten,
    );
    onSaveImmediate(updated);
  }

  Future<void> _steigereAngriffAt(
    BuildContext context,
    HeroCompanionAttack angriff,
  ) async {
    final maxWert = regMaxSteigerung(
      aktuellerSteigerungswert: angriff.steigerungAt,
      verfuegbareAp: _apVerfuegbar,
    );
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: '${angriff.name} AT (Vertrauter)',
      aktuellerWert: angriff.steigerungAt,
      maxWert: maxWert,
      effektiveKomplexitaet: kVertrauterKomplexitaet,
      verfuegbareAp: _apVerfuegbar,
    );
    if (result == null) return;

    final updatedAngriff = angriff.copyWith(steigerungAt: result.neuerWert);
    final updatedAngriffe = companion.angriffe
        .map((a) => a.id == angriff.id ? updatedAngriff : a)
        .toList();
    final updated = companion.copyWith(
      angriffe: updatedAngriffe,
      apAusgegeben: (companion.apAusgegeben ?? 0) + result.apKosten,
    );
    onSaveImmediate(updated);
  }

  Future<void> _steigereAngriffPa(
    BuildContext context,
    HeroCompanionAttack angriff,
  ) async {
    if (angriff.pa == null) return;
    final maxWert = regMaxSteigerung(
      aktuellerSteigerungswert: angriff.steigerungPa,
      verfuegbareAp: _apVerfuegbar,
    );
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: '${angriff.name} PA (Vertrauter)',
      aktuellerWert: angriff.steigerungPa,
      maxWert: maxWert,
      effektiveKomplexitaet: kVertrauterKomplexitaet,
      verfuegbareAp: _apVerfuegbar,
    );
    if (result == null) return;

    final updatedAngriff = angriff.copyWith(steigerungPa: result.neuerWert);
    final updatedAngriffe = companion.angriffe
        .map((a) => a.id == angriff.id ? updatedAngriff : a)
        .toList();
    final updated = companion.copyWith(
      angriffe: updatedAngriffe,
      apAusgegeben: (companion.apAusgegeben ?? 0) + result.apKosten,
    );
    onSaveImmediate(updated);
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (companion.typ != BegleiterTyp.vertrauter) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final apText = 'AP verfügbar: $_apVerfuegbar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionHeader('Steigerung'),
            const Spacer(),
            Text(
              apText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        // Eigenschaften
        ..._buildEigenschaftRows(context),
        const SizedBox(height: _innerFieldSpacing),
        // Kampfwerte (INI, Loyalitaet)
        ..._buildKampfwertRows(context),
        const SizedBox(height: _innerFieldSpacing),
        // Pool-Werte (LeP, AsP, MR)
        ..._buildPoolRows(context),
        // Angriffe (AT/PA)
        if (companion.angriffe.isNotEmpty) ...[
          const SizedBox(height: _innerFieldSpacing),
          ..._buildAngriffRows(context),
        ],
      ],
    );
  }

  List<Widget> _buildEigenschaftRows(BuildContext context) {
    return [
      for (final (label, key) in kCompanionEigenschaftKeys)
        if (companionBasiswert(companion, key) != null)
          _SteigerungsZeile(
            label: label,
            basiswert: companionBasiswert(companion, key)!,
            steigerung: companionSteigerung(companion, key),
            canRaise: _apVerfuegbar > 0 && isEditing,
            onRaise: () {
              final stg = companionSteigerung(companion, key);
              final maxWert = regMaxSteigerung(
                aktuellerSteigerungswert: stg,
                verfuegbareAp: _apVerfuegbar,
              );
              _steigereWert(
                context,
                label: label,
                key: key,
                aktuellerSteigerungswert: stg,
                maxWert: maxWert,
              );
            },
          ),
    ];
  }

  List<Widget> _buildKampfwertRows(BuildContext context) {
    return [
      for (final (label, key) in kCompanionKampfwertKeys)
        if (companionBasiswert(companion, key) != null)
          _SteigerungsZeile(
            label: label,
            basiswert: companionBasiswert(companion, key)!,
            steigerung: companionSteigerung(companion, key),
            canRaise: _apVerfuegbar > 0 && isEditing,
            onRaise: () {
              final stg = companionSteigerung(companion, key);
              final maxWert = regMaxSteigerung(
                aktuellerSteigerungswert: stg,
                verfuegbareAp: _apVerfuegbar,
              );
              _steigereWert(
                context,
                label: label,
                key: key,
                aktuellerSteigerungswert: stg,
                maxWert: maxWert,
              );
            },
          ),
    ];
  }

  List<Widget> _buildPoolRows(BuildContext context) {
    return [
      for (final (label, key) in kCompanionPoolKeys)
        if (companionPoolBasiswert(companion, key) != null ||
            companionPoolStartwert(companion, key) != null)
          Builder(builder: (context) {
            final startwert = companionPoolStartwert(companion, key) ??
                companionPoolBasiswert(companion, key)!;
            final stg = companionSteigerung(companion, key);
            final maxStg = poolMaxSteigerung(startwert);
            final effektivMax = math.min(
              maxStg,
              regMaxSteigerung(
                aktuellerSteigerungswert: stg,
                verfuegbareAp: _apVerfuegbar,
              ),
            );
            return _SteigerungsZeile(
              label: label,
              basiswert: startwert,
              steigerung: stg,
              maxSteigerung: maxStg,
              canRaise: _apVerfuegbar > 0 && stg < maxStg && isEditing,
              onRaise: () => _steigereWert(
                context,
                label: label,
                key: key,
                aktuellerSteigerungswert: stg,
                maxWert: effektivMax,
              ),
            );
          }),
    ];
  }

  List<Widget> _buildAngriffRows(BuildContext context) {
    final rows = <Widget>[];
    for (final angriff in companion.angriffe) {
      if (angriff.at != null) {
        rows.add(
          _SteigerungsZeile(
            label: '${angriff.name} AT',
            basiswert: angriff.at!,
            steigerung: angriff.steigerungAt,
            canRaise: _apVerfuegbar > 0 && isEditing,
            onRaise: () => _steigereAngriffAt(context, angriff),
          ),
        );
      }
      if (angriff.pa != null) {
        rows.add(
          _SteigerungsZeile(
            label: '${angriff.name} PA',
            basiswert: angriff.pa!,
            steigerung: angriff.steigerungPa,
            canRaise: _apVerfuegbar > 0 && isEditing,
            onRaise: () => _steigereAngriffPa(context, angriff),
          ),
        );
      }
    }
    return rows;
  }
}

// ---------------------------------------------------------------------------
// Einzelne Steigerungszeile
// ---------------------------------------------------------------------------

class _SteigerungsZeile extends StatelessWidget {
  const _SteigerungsZeile({
    required this.label,
    required this.basiswert,
    required this.steigerung,
    required this.canRaise,
    required this.onRaise,
    this.maxSteigerung,
  });

  final String label;
  final int basiswert;
  final int steigerung;
  final bool canRaise;
  final VoidCallback onRaise;

  /// Optionales Maximum fuer Pool-Werte (wird als Hinweis angezeigt).
  final int? maxSteigerung;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effektiv = basiswert + steigerung;
    final subLabel = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$basiswert',
              textAlign: TextAlign.center,
              style: subLabel,
            ),
          ),
          if (steigerung > 0)
            Text(
              ' +$steigerung',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            '= $effektiv',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (maxSteigerung != null) ...[
            const SizedBox(width: 4),
            Text(
              '(max +$maxSteigerung)',
              style: subLabel,
            ),
          ],
          const Spacer(),
          if (canRaise)
            IconButton(
              icon: const Icon(Icons.trending_up, size: 18),
              tooltip: '$label steigern',
              visualDensity: VisualDensity.compact,
              onPressed: onRaise,
            ),
        ],
      ),
    );
  }
}
