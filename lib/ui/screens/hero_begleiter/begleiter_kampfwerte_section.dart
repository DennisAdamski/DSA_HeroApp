part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Kampf- und Bewegungswerte
// ---------------------------------------------------------------------------

class _KampfWerteSection extends StatelessWidget {
  const _KampfWerteSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Kampf- und Bewegungswerte'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NullableIntField(
                label: 'INI',
                value: companion.ini,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(ini: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'Magieresistenz',
                value: companion.magieresistenz,
                isEditing: isEditing,
                onChanged: (v) =>
                    onChanged(companion.copyWith(magieresistenz: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'Loyalität',
                value: companion.loyalitaet,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(loyalitaet: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: _innerFieldSpacing),
        // AP-Zeile
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NullableIntField(
                label: 'AP Gesamt',
                value: companion.apGesamt,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(apGesamt: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'AP Ausgegeben',
                value: companion.apAusgegeben,
                isEditing: isEditing,
                onChanged: (v) =>
                    onChanged(companion.copyWith(apAusgegeben: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'AP Verfügbar',
                value: (companion.apGesamt != null ||
                        companion.apAusgegeben != null)
                    ? computeAvailableAp(
                        companion.apGesamt ?? 0,
                        companion.apAusgegeben ?? 0,
                      )
                    : null,
                isEditing: false,
                onChanged: (_) {},
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: _innerFieldSpacing),
        _GeschwindigkeitenEditor(
          speeds: companion.geschwindigkeiten,
          isEditing: isEditing,
          onChanged: (speeds) =>
              onChanged(companion.copyWith(geschwindigkeiten: speeds)),
        ),
      ],
    );
  }
}

class _NullableIntField extends StatelessWidget {
  const _NullableIntField({
    required this.label,
    required this.value,
    required this.isEditing,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final bool isEditing;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value?.toString() ?? '–'),
        ],
      );
    }
    return TextFormField(
      initialValue: value?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) => onChanged(int.tryParse(v)),
    );
  }
}

class _GeschwindigkeitenEditor extends StatelessWidget {
  const _GeschwindigkeitenEditor({
    required this.speeds,
    required this.isEditing,
    required this.onChanged,
  });

  final List<HeroCompanionSpeed> speeds;
  final bool isEditing;
  final ValueChanged<List<HeroCompanionSpeed>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Geschwindigkeit',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Geschwindigkeit hinzufügen',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final next = List<HeroCompanionSpeed>.from(speeds)
                    ..add(const HeroCompanionSpeed());
                  onChanged(next);
                },
              ),
          ],
        ),
        if (speeds.isEmpty && !isEditing)
          Text(
            '–',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        for (int i = 0; i < speeds.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _SpeedRow(
              speed: speeds[i],
              isEditing: isEditing,
              onChanged: (updated) {
                final next = List<HeroCompanionSpeed>.from(speeds);
                next[i] = updated;
                onChanged(next);
              },
              onDelete: () {
                final next = List<HeroCompanionSpeed>.from(speeds)
                  ..removeAt(i);
                onChanged(next);
              },
            ),
          ),
      ],
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.speed,
    required this.isEditing,
    required this.onChanged,
    required this.onDelete,
  });

  final HeroCompanionSpeed speed;
  final bool isEditing;
  final ValueChanged<HeroCompanionSpeed> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return Text('${speed.art}: ${speed.wert}');
    }
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: speed.art,
            decoration: const InputDecoration(
              labelText: 'Art',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => onChanged(speed.copyWith(art: v)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: speed.wert.toString(),
            decoration: const InputDecoration(
              labelText: 'Wert',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) =>
                onChanged(speed.copyWith(wert: int.tryParse(v) ?? speed.wert)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// LeP / AuP / AsP
// ---------------------------------------------------------------------------

class _LepSection extends StatelessWidget {
  const _LepSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Lebenspunkte'),
        Row(
          children: [
            Expanded(
              child: _NullableIntField(
                label: 'LeP (max)',
                value: companion.maxLep,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(maxLep: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'AuP (max)',
                value: companion.maxAup,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(maxAup: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'AsP (max)',
                value: companion.maxAsp,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(maxAsp: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Weiteres
// ---------------------------------------------------------------------------

class _WeiteresSection extends StatelessWidget {
  const _WeiteresSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Weiteres'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EditAwareField(
                label: 'Tragkraft',
                value: companion.tragkraft,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(tragkraft: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: EditAwareField(
                label: 'Zugkraft',
                value: companion.zugkraft,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(zugkraft: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: _innerFieldSpacing),
        EditAwareField(
          label: 'Ausbildung',
          value: companion.ausbildung,
          isEditing: isEditing,
          maxLines: 3,
          onChanged: (v) => onChanged(companion.copyWith(ausbildung: v)),
        ),
        const SizedBox(height: _innerFieldSpacing),
        EditAwareField(
          label: 'Futterbedarf',
          value: companion.futterbedarf,
          isEditing: isEditing,
          onChanged: (v) => onChanged(companion.copyWith(futterbedarf: v)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vor- und Nachteile
// ---------------------------------------------------------------------------

class _VorNachteileSection extends StatelessWidget {
  const _VorNachteileSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Vor- und Nachteile'),
        EditAwareField(
          label: 'Vorteile',
          value: companion.vorteile,
          isEditing: isEditing,
          maxLines: 5,
          onChanged: (v) => onChanged(companion.copyWith(vorteile: v)),
        ),
        const SizedBox(height: _fieldSpacing),
        EditAwareField(
          label: 'Nachteile',
          value: companion.nachteile,
          isEditing: isEditing,
          maxLines: 5,
          onChanged: (v) => onChanged(companion.copyWith(nachteile: v)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Merkmale Gw / Au
// ---------------------------------------------------------------------------

class _MerkmaleSection extends StatelessWidget {
  const _MerkmaleSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Gefahrenwert / Ausdauer-Runden'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EditAwareIntField(
                label: 'GW (Gefahrenwert, 0–20)',
                value: companion.gw,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(gw: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: EditAwareIntField(
                label: 'AU (Ausdauer-Runden)',
                value: companion.au,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(au: v)),
              ),
            ),
            const Spacer(),
            const Spacer(),
          ],
        ),
      ],
    );
  }
}
