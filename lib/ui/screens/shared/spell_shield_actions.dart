import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_protection_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

/// Ergebnis eines Auffangvorgangs für den Aufrufer.
class SchildAuffangErgebnis {
  /// Erstellt das Ergebnis.
  const SchildAuffangErgebnis({
    required this.aufgefangen,
    required this.durchschlag,
  });

  /// Vom Schild aufgenommene TP.
  final int aufgefangen;

  /// TP, die der Schild nicht aufnimmt und die als Schaden zu buchen bleiben.
  final int durchschlag;
}

/// Lässt den Schutzschild [instanz] einen direkten magischen Treffer
/// auffangen.
///
/// Fragt die eingehenden TP ab, bucht den Auffangvorgang auf dem frisch
/// gespeicherten Zustand und liefert den Durchschlag. `null` bei Abbruch,
/// Speicherfehler oder einem Vorrat, der sich inzwischen geändert hat (dann
/// wurde nichts verändert und ein Hinweis erscheint). Nie erneut buchen: Der
/// erwartete Restvorrat verhindert eine Doppelbuchung bei Wiederholung.
///
/// [vorbelegtTp] belegt das Feld vor, etwa mit den TP des Schadensdialogs.
Future<SchildAuffangErgebnis?> fangeTrefferMitSchildAuf({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required SpellEffectInstance instanz,
  String schildName = 'Zauberschild',
  int? vorbelegtTp,
}) async {
  final rest = schutzRestVon(instanz);
  final tp = await showAdaptiveInputDialog<int>(
    context: context,
    builder: (_) => _SchildAuffangDialog(
      name: schildName,
      rest: rest,
      vorbelegtTp: vorbelegtTp,
    ),
  );
  if (tp == null || !context.mounted) {
    return null;
  }
  SchutzAuffangErgebnis? ergebnis;
  final gespeichert = await aendereZustandMitMeldung(
    context: context,
    ref: ref,
    heroId: heroId,
    was: 'Zauberschild',
    aenderung: (HeroState aktuell) {
      final vorgang = fangeMagischenSchadenAuf(
        aktuell,
        instanzId: instanz.id,
        eingehend: tp,
        erwarteterRest: rest,
      );
      ergebnis = vorgang;
      return vorgang.zustand;
    },
  );
  final vorgang = ergebnis;
  if (gespeichert == null || vorgang == null || !context.mounted) {
    return null;
  }
  if (vorgang.status != SchutzAuffangStatus.aufgefangen) {
    await _zeigeAbweichung(context, vorgang);
    return null;
  }
  return SchildAuffangErgebnis(
    aufgefangen: vorgang.aufgefangen,
    durchschlag: vorgang.durchschlag,
  );
}

Future<void> _zeigeAbweichung(
  BuildContext context,
  SchutzAuffangErgebnis vorgang,
) {
  final text = switch (vorgang.status) {
    SchutzAuffangStatus.nichtGefunden =>
      'Der Zauberschild ist nicht mehr gespeichert.',
    SchutzAuffangStatus.unwirksam =>
      'Der Zauberschild ist unterdrückt und fängt nichts auf.',
    SchutzAuffangStatus.restAbweichend =>
      'Der Schutzvorrat hat sich inzwischen geändert (jetzt '
          '${vorgang.restVorher} TP). Es wurde nichts gebucht; bitte erneut '
          'öffnen.',
    SchutzAuffangStatus.aufgefangen => '',
  };
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey<String>('schild-abweichung'),
      title: const Text('Nicht gebucht'),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Schließen'),
        ),
      ],
    ),
  );
}

class _SchildAuffangDialog extends StatefulWidget {
  const _SchildAuffangDialog({
    required this.name,
    required this.rest,
    this.vorbelegtTp,
  });

  final String name;
  final int rest;
  final int? vorbelegtTp;

  @override
  State<_SchildAuffangDialog> createState() => _SchildAuffangDialogState();
}

class _SchildAuffangDialogState extends State<_SchildAuffangDialog> {
  late final TextEditingController _tp = TextEditingController(
    text: widget.vorbelegtTp == null ? '' : '${widget.vorbelegtTp}',
  );

  @override
  void dispose() {
    _tp.dispose();
    super.dispose();
  }

  int? get _wert => int.tryParse(_tp.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tp = _wert;
    final aufgefangen = tp == null
        ? null
        : (tp < widget.rest ? tp : widget.rest);
    return AdaptiveInputDialog(
      title: '${widget.name}: Treffer auffangen',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nur für direkte magische Angriffe: Schadenszauber und Schaden '
            'erzeugende Zauber von Dämonen, Elementaren oder Geistern. Magisch '
            'erhöhte Waffen-TP und physische Angriffe fängt der Schild nicht '
            'auf.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: kDialogFieldSpacing),
          Text(
            'Schutzvorrat: ${widget.rest} TP',
            key: const ValueKey<String>('schild-auffang-vorrat'),
          ),
          const SizedBox(height: kDialogFieldSpacing),
          TextField(
            key: const ValueKey<String>('schild-auffang-tp'),
            controller: _tp,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              labelText: 'Eingehende TP des magischen Angriffs',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: kDialogInlineSpacing),
          Text(
            tp == null
                ? 'TP eintragen'
                : 'Fängt $aufgefangen TP auf · Rest '
                      '${widget.rest - aufgefangen!} TP · Durchschlag '
                      '${tp - aufgefangen} TP',
            key: const ValueKey<String>('schild-auffang-vorschau'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('schild-auffang-bestaetigen'),
          onPressed: tp == null ? null : () => Navigator.of(context).pop(tp),
          child: const Text('Auffangen'),
        ),
      ],
    );
  }
}

/// Fragt den neuen Restvorrat des Schilds [instanz] ab (Korrektur, etwa nach
/// einem AsP-Verlust durch einen Schadenszauber ohne direkte TP) und liefert
/// ihn; `null` bei Abbruch.
Future<int?> fragePasseSchutzRestAn({
  required BuildContext context,
  required SpellEffectInstance instanz,
}) {
  return showAdaptiveInputDialog<int>(
    context: context,
    builder: (_) => _SchutzRestDialog(instanz: instanz),
  );
}

class _SchutzRestDialog extends StatefulWidget {
  const _SchutzRestDialog({required this.instanz});

  final SpellEffectInstance instanz;

  @override
  State<_SchutzRestDialog> createState() => _SchutzRestDialogState();
}

class _SchutzRestDialogState extends State<_SchutzRestDialog> {
  late final TextEditingController _rest = TextEditingController(
    text: '${schutzRestVon(widget.instanz)}',
  );

  @override
  void dispose() {
    _rest.dispose();
    super.dispose();
  }

  int? get _wert => int.tryParse(_rest.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maximal = widget.instanz.amount;
    final wert = _wert;
    final gueltig = wert != null && wert >= 0 && wert <= maximal;
    return AdaptiveInputDialog(
      title: 'Schutzvorrat anpassen',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Verliert der Schild AsP durch einen Schadenszauber ohne direkte '
            'TP (Kosten des Zaubers), oder soll ein Fehler korrigiert werden, '
            'trage hier den verbleibenden Vorrat ein (0 bis $maximal TP).',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: kDialogFieldSpacing),
          TextField(
            key: const ValueKey<String>('schild-rest-feld'),
            controller: _rest,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              labelText: 'Verbleibender Vorrat (TP)',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('schild-rest-bestaetigen'),
          onPressed: gueltig ? () => Navigator.of(context).pop(wert) : null,
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
