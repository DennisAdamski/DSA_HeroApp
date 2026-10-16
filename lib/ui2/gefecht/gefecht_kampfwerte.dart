import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfwerte_rules.dart';

import 'gefecht_anordnung.dart';
import 'gefecht_herleitung_schritte.dart';

/// Schmale, fixierte Leiste der Kampfwerte (INI, AT, PA, Ausweichen …).
///
/// Sie sitzt unter der Kopfzeile der Gefechtsansicht und scrollt nicht mit.
/// Jeder Eintrag zeigt Kürzel und Grundwert, bei veränderter Probe dahinter
/// den Zielwert. Antippen öffnet den Rechenweg. Das Widget rechnet nichts:
/// alle Werte kommen fertig aus `gefechtsKampfwerte`.
class GefechtKampfwerteLeiste extends StatelessWidget
    implements PreferredSizeWidget {
  /// Zeigt [werte] einzeilig; zu viele Einträge lassen sich seitlich wischen.
  const GefechtKampfwerteLeiste({super.key, required this.werte});

  /// Kampfwerte im aktuellen Gefechtsstand.
  final List<GefechtsKampfwert> werte;

  /// Höhe der Leiste.
  static const double hoehe = 40;

  @override
  Size get preferredSize => const Size.fromHeight(hoehe);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('gefecht-kampfwerte'),
      height: hoehe,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final w in werte)
            _Eintrag(wert: w, onTap: () => zeigeGefechtKampfwert(context, w)),
        ],
      ),
    );
  }
}

class _Eintrag extends StatelessWidget {
  const _Eintrag({required this.wert, required this.onTap});

  final GefechtsKampfwert wert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;
    final leicht = (wert.zielwert ?? 0) > (wert.wert ?? 0);
    final zielFarbe = leicht ? farben.primary : farben.error;
    final klein = theme.textTheme.labelSmall?.copyWith(
      color: farben.onSurfaceVariant,
    );
    return Semantics(
      button: true,
      label:
          '${wert.titel} ${wert.anzeige}'
          '${wert.weichtAb ? ', aktuell ${wert.zielwert}' : ''}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('gefecht-kampfwert-${wert.id}'),
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(wert.kuerzel, style: klein),
                const SizedBox(width: 4),
                Text(
                  wert.anzeige,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (wert.weichtAb) ...[
                  const SizedBox(width: 3),
                  Text(
                    key: ValueKey('gefecht-kampfwert-${wert.id}-aktuell'),
                    '→${wert.zielwert}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: zielFarbe,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Öffnet den Rechenweg von [wert]: auf schmalen Fenstern als Blatt, auf
/// breiten als Dialog.
Future<void> zeigeGefechtKampfwert(
  BuildContext context,
  GefechtsKampfwert wert,
) {
  final breit = MediaQuery.sizeOf(context).width >= kGefechtZweispaltig;
  if (breit) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${wert.titel} · ${wert.anzeige}'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: GefechtKampfwertDetails(wert: wert),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${wert.titel} · ${wert.anzeige}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            GefechtKampfwertDetails(wert: wert),
          ],
        ),
      ),
    ),
  );
}

/// Rechenweg eines Kampfwerts: Grundwert, Hinweise und die aktuelle
/// Erschwernis der Gefechtslage.
class GefechtKampfwertDetails extends StatelessWidget {
  /// Zeigt die Schritte von [wert].
  const GefechtKampfwertDetails({super.key, required this.wert});

  /// Anzuzeigender Kampfwert.
  final GefechtsKampfwert wert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leise = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      key: const ValueKey('gefecht-kampfwert-blatt'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (wert.herleitung case final h?)
          GefechtHerleitungSchritte(herleitung: h)
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Für diesen Wert liegt keine Herleitung vor.',
              style: leise,
            ),
          ),
        for (final hinweis in wert.hinweise)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(hinweis, style: leise),
          ),
        if (wert.zielwert != null &&
            (wert.erschwernis != 0 || wert.weichtAb)) ...[
          const Divider(height: 24),
          Text('Aktuell im Gefecht', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (wert.erschwernisHerleitung case final h?)
            GefechtHerleitungSchritte(herleitung: h),
          Text(
            key: const ValueKey('gefecht-kampfwert-zielwert'),
            wert.wert != null && wert.wert! - wert.erschwernis == wert.zielwert
                ? 'Zielwert: ${wert.wert} − ${wert.erschwernis} = ${wert.zielwert}'
                : 'Zielwert ${wert.zielwert} bei Erschwernis ${wert.erschwernis}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}
