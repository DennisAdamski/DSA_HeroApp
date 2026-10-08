part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Kampf- und Bewegungswerte
// ---------------------------------------------------------------------------

class _KampfWerteSection extends StatelessWidget {
  const _KampfWerteSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
    this.onRaisePool,
    this.onRaiseGs,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;
  final void Function(String key, String label)? onRaisePool;
  final void Function(String art)? onRaiseGs;

  @override
  Widget build(BuildContext context) {
    // INI und Loyalitaet sind nach WdZ S. 125 nicht steigerbar; Altbuchungen
    // zaehlen weiter und stehen in den Hinweisen darunter.
    final hinweise = vertrautenSteigerungshinweise(companion);
    // Im View-Modus wirksame Werte anzeigen (Basis + Steigerung + Ausbildung).
    final iniView = isEditing
        ? companion.ini
        : companionEffektivwert(companion, 'ini') ?? companion.ini;
    final mrView = isEditing
        ? companion.magieresistenz
        : companionEffektiverPoolwert(companion, 'mr') ??
              companion.magieresistenz;
    final loyView = isEditing
        ? companion.loyalitaet
        : begleiterWirksamerWert(companion, 'loyalitaet') ??
              companion.loyalitaet;

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
                value: iniView,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(ini: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'Magieresistenz',
                value: mrView,
                isEditing: isEditing,
                onChanged: (v) =>
                    onChanged(companion.copyWith(magieresistenz: v)),
                suffixIcon:
                    onRaisePool != null && companion.magieresistenz != null
                    ? _RaiseIconButton(
                        tooltip: 'MR steigern',
                        onPressed: () => onRaisePool!('mr', 'MR'),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'Loyalität',
                value: loyView,
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
                value:
                    (companion.apGesamt != null ||
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
          speeds: isEditing
              ? companion.geschwindigkeiten
              : begleiterWirksameGeschwindigkeiten(companion),
          isEditing: isEditing,
          onChanged: (speeds) =>
              onChanged(companion.copyWith(geschwindigkeiten: speeds)),
          onRaise: onRaiseGs,
        ),
        for (final hinweis in hinweise)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hinweis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
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
    this.suffixIcon,
  });

  final String label;
  final int? value;
  final bool isEditing;
  final ValueChanged<int?> onChanged;
  final Widget? suffixIcon;

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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value?.toString() ?? '–'),
              if (suffixIcon != null) ?suffixIcon,
            ],
          ),
        ],
      );
    }
    return TextFormField(
      initialValue: value?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: suffixIcon,
        suffixIconConstraints: suffixIcon != null
            ? const BoxConstraints(minWidth: 32, minHeight: 32)
            : null,
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
    this.onRaise,
  });

  final List<HeroCompanionSpeed> speeds;
  final bool isEditing;
  final ValueChanged<List<HeroCompanionSpeed>> onChanged;
  final void Function(String art)? onRaise;

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
          Text('–', style: Theme.of(context).textTheme.bodyMedium),
        for (int i = 0; i < speeds.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _SpeedRow(
              speed: speeds[i],
              isEditing: isEditing,
              onRaise: onRaise != null && speeds[i].art.isNotEmpty
                  ? () => onRaise!(speeds[i].art)
                  : null,
              onChanged: (updated) {
                final next = List<HeroCompanionSpeed>.from(speeds);
                next[i] = updated;
                onChanged(next);
              },
              onDelete: () {
                final next = List<HeroCompanionSpeed>.from(speeds)..removeAt(i);
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
    this.onRaise,
  });

  final HeroCompanionSpeed speed;
  final bool isEditing;
  final ValueChanged<HeroCompanionSpeed> onChanged;
  final VoidCallback onDelete;
  final VoidCallback? onRaise;

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
        if (onRaise != null)
          _RaiseIconButton(
            tooltip: 'GS ${speed.art} steigern',
            onPressed: onRaise!,
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
    this.onRaisePool,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;
  final void Function(String key, String label)? onRaisePool;

  @override
  Widget build(BuildContext context) {
    // Im View-Modus effektive Pool-Werte anzeigen.
    final lepView = isEditing
        ? companion.maxLep
        : companionEffektiverPoolwert(companion, 'lep') ?? companion.maxLep;
    final aupView = isEditing
        ? companion.maxAup
        : companionEffektiverPoolwert(companion, 'aup') ?? companion.maxAup;
    final aspView = isEditing
        ? companion.maxAsp
        : companionEffektiverPoolwert(companion, 'asp') ?? companion.maxAsp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Lebenspunkte'),
        Row(
          children: [
            Expanded(
              child: _NullableIntField(
                label: 'LeP (max)',
                value: lepView,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(maxLep: v)),
                suffixIcon: onRaisePool != null && companion.maxLep != null
                    ? _RaiseIconButton(
                        tooltip: 'LeP steigern',
                        onPressed: () => onRaisePool!('lep', 'LeP'),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'AuP (max)',
                value: aupView,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(maxAup: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'AsP (max)',
                value: aspView,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(maxAsp: v)),
                suffixIcon: onRaisePool != null && companion.maxAsp != null
                    ? _RaiseIconButton(
                        tooltip: 'AsP steigern',
                        onPressed: () => onRaisePool!('asp', 'AsP'),
                      )
                    : null,
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
                value: isEditing
                    ? companion.tragkraft
                    : begleiterWirksameKraft(
                        companion.tragkraft,
                        begleiterAusbildungsModifikationen(companion).tkFaktor,
                      ),
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(tragkraft: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: EditAwareField(
                label: 'Zugkraft',
                value: isEditing
                    ? companion.zugkraft
                    : begleiterWirksameKraft(
                        companion.zugkraft,
                        begleiterAusbildungsModifikationen(companion).zkFaktor,
                      ),
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(zugkraft: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: _innerFieldSpacing),
        EditAwareField(
          // Bei Reittieren fuehrt der Abschnitt „Reittier-Ausbildung“; der
          // alte Freitext bleibt als Notiz.
          label: companion.typ == BegleiterTyp.reittier
              ? 'Ausbildung (Notiz)'
              : 'Ausbildung',
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
