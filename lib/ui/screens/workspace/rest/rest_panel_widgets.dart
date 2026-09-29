part of '../rest_dialog.dart';

IconData _activityIcon(RestActivity activity) {
  switch (activity) {
    case RestActivity.kurzeRast:
      return Icons.schedule;
    case RestActivity.schlaf:
      return Icons.bedtime;
    case RestActivity.bettruhe:
      return Icons.hotel;
    case RestActivity.nurAusruhen:
      return Icons.weekend;
  }
}

String _activityLabel(RestActivity activity) {
  switch (activity) {
    case RestActivity.kurzeRast:
      return 'Kurze Rast';
    case RestActivity.schlaf:
      return 'Schlaf';
    case RestActivity.bettruhe:
      return 'Bettruhe';
    case RestActivity.nurAusruhen:
      return 'Nur ausruhen';
  }
}

String _activitySubtitle(RestActivity activity) {
  switch (activity) {
    case RestActivity.kurzeRast:
      return 'Zustände';
    case RestActivity.schlaf:
      return 'Ausdauer + Regeneration';
    case RestActivity.bettruhe:
      return 'Bis zu zwei Phasen';
    case RestActivity.nurAusruhen:
      return 'Nur Ausdauer';
  }
}

String _activityDescription(RestActivity activity) {
  switch (activity) {
    case RestActivity.kurzeRast:
      return 'Baut nur Überanstrengung & Erschöpfung ab '
          '(Rast-Tempo, Stunden frei wählbar).';
    case RestActivity.schlaf:
      return 'Volle Nachtruhe: Ausdauer-Erholung, Erschöpfung-Abbau im '
          'Schlaftempo (8 h) und eine Regenerationsphase für LeP/AsP.';
    case RestActivity.bettruhe:
      return 'Wie Schlaf, aber mit optionaler zweiter '
          'Regenerationsphase für LeP/AsP.';
    case RestActivity.nurAusruhen:
      return 'Nur die Ausdauer wird regeneriert – kein Schlaf, keine '
          'Regeneration, kein Erschöpfung-Abbau.';
  }
}

class _RestSectionSurface extends StatelessWidget {
  const _RestSectionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Unter Kartograph eine eingelassene senke-Flaeche mit Haarlinie, wie
    // jede Begleitflaeche; klassisch die halbdurchsichtige Tafel.
    final karto = kartoVariante(context);
    return DecoratedBox(
      decoration: karto != null
          ? BoxDecoration(
              color: karto.senke,
              borderRadius: BorderRadius.circular(kKartoRadius),
              border: Border.all(color: karto.hoehenlinie, width: 0.5),
            )
          : BoxDecoration(
              color: codex.panelRaised.withValues(alpha: isDark ? 0.38 : 0.55),
              borderRadius: BorderRadius.circular(codex.panelRadius),
              border: Border.all(color: codex.rule),
            ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _RestActivityTile extends StatelessWidget {
  const _RestActivityTile({
    required this.activity,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onSelected,
  });

  final RestActivity activity;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final ValueChanged<RestActivity> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    final borderRadius = BorderRadius.circular(codex.panelRadius);
    final selectedBackground = codex.brass.withValues(alpha: 0.14);
    final defaultBackground = codex.panel.withValues(alpha: 0.62);
    final borderColor = selected ? codex.brass : codex.rule;
    final foregroundColor = selected ? codex.brass : codex.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => onSelected(activity),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? selectedBackground : defaultBackground,
              borderRadius: borderRadius,
              border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: foregroundColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, size: 18, color: codex.brass),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestNumberStepper extends StatelessWidget {
  const _RestNumberStepper({
    required this.value,
    required this.decreaseTooltip,
    required this.increaseTooltip,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final String decreaseTooltip;
  final String increaseTooltip;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: codex.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(codex.panelRadius),
        border: Border.all(color: codex.rule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RestStepperButton(
            tooltip: decreaseTooltip,
            icon: Icons.remove,
            onPressed: onDecrease,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          ),
          _RestStepperButton(
            tooltip: increaseTooltip,
            icon: Icons.add,
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _RestStepperButton extends StatelessWidget {
  const _RestStepperButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      iconSize: 18,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

/// Äußere Umstände der Regeneration (Wetter, Lager, Störungen, Krankheit).
class _RestEnvironmentSection extends StatelessWidget {
  const _RestEnvironmentSection({
    required this.environment,
    required this.onChanged,
  });

  final RestEnvironmentInput environment;
  final ValueChanged<RestEnvironmentInput> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Äußere Umstände', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: const ValueKey<String>('rest-weather-modifier'),
          initialValue: environment.weatherModifier,
          decoration: const InputDecoration(
            labelText: 'Wetter',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem<int>(value: 0, child: Text('Kein Malus')),
            DropdownMenuItem<int>(value: -1, child: Text('-1')),
            DropdownMenuItem<int>(value: -2, child: Text('-2')),
            DropdownMenuItem<int>(value: -3, child: Text('-3')),
            DropdownMenuItem<int>(value: -4, child: Text('-4')),
            DropdownMenuItem<int>(value: -5, child: Text('-5')),
          ],
          onChanged: (value) =>
              onChanged(environment.copyWith(weatherModifier: value ?? 0)),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: const ValueKey<String>('rest-sleep-site-modifier'),
          initialValue: environment.sleepSiteModifier,
          decoration: const InputDecoration(
            labelText: 'Lagerstätte',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem<int>(value: 0, child: Text('0')),
            DropdownMenuItem<int>(value: 1, child: Text('+1')),
            DropdownMenuItem<int>(value: 2, child: Text('+2')),
          ],
          onChanged: (value) =>
              onChanged(environment.copyWith(sleepSiteModifier: value ?? 0)),
        ),
        SwitchListTile(
          key: const ValueKey<String>('rest-bad-camp'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Schlechter Lagerplatz'),
          value: environment.hasBadCamp,
          onChanged: (value) =>
              onChanged(environment.copyWith(hasBadCamp: value)),
        ),
        SwitchListTile(
          key: const ValueKey<String>('rest-night-disturbance'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Ruhestörung'),
          value: environment.hasNightDisturbance,
          onChanged: (value) =>
              onChanged(environment.copyWith(hasNightDisturbance: value)),
        ),
        SwitchListTile(
          key: const ValueKey<String>('rest-watch-duty'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Wache gehalten'),
          value: environment.hasWatchDuty,
          onChanged: (value) =>
              onChanged(environment.copyWith(hasWatchDuty: value)),
        ),
        SwitchListTile(
          key: const ValueKey<String>('rest-is-ill'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Held ist erkrankt'),
          value: environment.isIll,
          onChanged: (value) => onChanged(environment.copyWith(isIll: value)),
        ),
        TextFormField(
          key: const ValueKey<String>('rest-extra-modifier'),
          initialValue: '${environment.extraModifier}',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Freier Rest-Modifikator',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => onChanged(
            environment.copyWith(
              extraModifier: int.tryParse(value.trim()) ?? 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Effektiver Umweltmodifikator: '
          '${computeRestEnvironmentModifier(environment)}',
        ),
      ],
    );
  }
}
