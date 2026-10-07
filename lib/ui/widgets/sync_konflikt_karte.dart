import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/sync_controller.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';
import 'package:dsa_heldenverwaltung/domain/sync_zusammenfuehrung.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/sync_conflict_comparison_table.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/sync_conflict_field_labels.dart';

/// Inhalt und Entscheidung eines Sync-Konflikts (ARCH-06).
///
/// Gemeinsam genutzt vom Start-Gate und von `Einstellungen > Konto & Sync`.
/// Liegt ein gemeinsamer Ausgangsstand vor, zeigt die Karte nur die Werte,
/// die beide Geräte verschieden geändert haben, und bietet „Automatisch“ an;
/// sonst den vollständigen Vergleich. Die Knöpfe stehen in der Reihenfolge
/// der Tabellenspalten: „Nur Online“, „Nur Lokal“, dann „Beide behalten“
/// und „Automatisch“.
class SyncKonfliktKarte extends StatefulWidget {
  /// Erzeugt die Karte.
  const SyncKonfliktKarte({
    super.key,
    required this.conflict,
    required this.controller,
    this.onAufgeloest,
  });

  /// Der offene Konflikt.
  final SyncConflict conflict;

  /// Controller, über den entschieden wird; ohne ihn sind die Knöpfe gesperrt.
  final AppSyncController? controller;

  /// Wird nach einer erfolgreichen Entscheidung aufgerufen.
  final VoidCallback? onAufgeloest;

  @override
  State<SyncKonfliktKarte> createState() => _SyncKonfliktKarteState();
}

class _SyncKonfliktKarteState extends State<SyncKonfliktKarte> {
  Future<SyncKonfliktVorschau?>? _vorschau;
  bool _arbeitet = false;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    _ladeVorschau();
  }

  @override
  void didUpdateWidget(covariant SyncKonfliktKarte oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.conflict, widget.conflict) ||
        oldWidget.controller != widget.controller) {
      _ladeVorschau();
    }
  }

  void _ladeVorschau() {
    _vorschau = widget.controller?.konfliktVorschau(widget.conflict.id);
  }

  Future<void> _entscheide(Future<void> Function() entscheidung) async {
    if (_arbeitet) {
      return;
    }
    setState(() {
      _arbeitet = true;
      _fehler = null;
    });
    try {
      await entscheidung();
      widget.onAufgeloest?.call();
    } catch (fehler) {
      if (mounted) {
        final text = fehler is StateError ? fehler.message : '$fehler';
        setState(() => _fehler = 'Nicht aufgelöst: $text');
      }
    } finally {
      if (mounted) {
        setState(() => _arbeitet = false);
      }
    }
  }

  Future<void> _waehle(SyncResolutionChoice wahl) {
    final controller = widget.controller!;
    return _entscheide(
      () => controller.resolveConflict(widget.conflict.id, wahl),
    );
  }

  Future<void> _automatisch(SyncKonfliktVorschau vorschau) async {
    final controller = widget.controller!;
    var entscheidungen = const <String, SyncSeite>{};
    if (vorschau.felder.isNotEmpty) {
      final gewaehlt = await showSyncFeldEntscheidung(
        context: context,
        felder: vorschau.felder,
      );
      if (gewaehlt == null) {
        return;
      }
      entscheidungen = gewaehlt;
    }
    await _entscheide(
      () => controller.resolveConflictAutomatisch(
        widget.conflict.id,
        entscheidungen,
      ),
    );
    if (mounted && _fehler != null) {
      // Der Stand hat sich womöglich geändert: Vorschau neu holen.
      setState(_ladeVorschau);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conflict = widget.conflict;
    final controller = widget.controller;
    return FutureBuilder<SyncKonfliktVorschau?>(
      future: _vorschau,
      builder: (context, snapshot) {
        final vorschau = snapshot.data;
        final gesperrt = controller == null || _arbeitet;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conflict.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (vorschau != null) ...[
              _Zusammenfassung(vorschau: vorschau),
              const SizedBox(height: 8),
            ],
            SyncConflictComparisonTable(
              // Neu aufbauen, sobald die Vorschau da ist: dann gilt
              // `startOffen`.
              key: ValueKey<bool>(vorschau != null),
              conflict: conflict,
              diff: vorschau == null
                  ? controller?.conflictDiff(conflict.id)
                  : _nurKonflikte(vorschau),
              startOffen: vorschau != null,
              mitZusammenfuehrung: vorschau != null,
            ),
            if (_fehler != null) ...[
              const SizedBox(height: 8),
              Text(
                _fehler!,
                key: ValueKey<String>('sync-konflikt-fehler-${conflict.id}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: ValueKey<String>('sync-konflikt-online-${conflict.id}'),
                  onPressed: gesperrt
                      ? null
                      : () => _waehle(SyncResolutionChoice.keepRemote),
                  icon: const Icon(Icons.cloud_done_outlined),
                  label: const Text('Nur Online'),
                ),
                OutlinedButton.icon(
                  key: ValueKey<String>('sync-konflikt-lokal-${conflict.id}'),
                  onPressed: gesperrt
                      ? null
                      : () => _waehle(SyncResolutionChoice.keepLocal),
                  icon: const Icon(Icons.computer),
                  label: const Text('Nur Lokal'),
                ),
                if (conflict.supportsKeepBoth)
                  OutlinedButton.icon(
                    key: ValueKey<String>('sync-konflikt-beide-${conflict.id}'),
                    onPressed: gesperrt
                        ? null
                        : () => _waehle(SyncResolutionChoice.keepBoth),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Beide behalten'),
                  ),
                if (vorschau != null)
                  FilledButton.icon(
                    key: ValueKey<String>(
                      'sync-konflikt-automatisch-${conflict.id}',
                    ),
                    onPressed: gesperrt ? null : () => _automatisch(vorschau),
                    icon: const Icon(Icons.merge_type),
                    label: const Text('Automatisch'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Nur die echten Konflikte als Vergleichszeilen.
  SyncObjectDiff _nurKonflikte(SyncKonfliktVorschau vorschau) {
    return SyncObjectDiff(
      entries: <SyncDiffEntry>[
        for (final feld in vorschau.felder)
          SyncDiffEntry(
            path: feld.pfad,
            kind: feld.onlineFehlt
                ? SyncDiffKind.onlyLocal
                : feld.lokalFehlt
                ? SyncDiffKind.onlyRemote
                : SyncDiffKind.changed,
            localValue: feld.lokal,
            remoteValue: feld.online,
          ),
      ],
    );
  }
}

class _Zusammenfassung extends StatelessWidget {
  const _Zusammenfassung({required this.vorschau});

  final SyncKonfliktVorschau vorschau;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = vorschau.felder.length;
    final widerspruch = switch (n) {
      0 => 'Nichts widerspricht sich.',
      1 => '1 Wert wurde auf beiden Geräten verschieden geändert.',
      _ => '$n Werte wurden auf beiden Geräten verschieden geändert.',
    };
    return Text(
      '$widerspruch „Automatisch“ übernimmt außerdem '
      '${_aenderungen(vorschau.vonOnline)} von online und '
      '${_aenderungen(vorschau.vonLokal)} von diesem Gerät.',
      style: theme.textTheme.bodyMedium,
    );
  }

  static String _aenderungen(int anzahl) =>
      anzahl == 1 ? '1 Änderung' : '$anzahl Änderungen';
}

/// Fragt je widersprüchlichem Wert, ob Online oder Lokal gilt.
///
/// Liefert die Entscheidungen nach Schlüssel oder `null` bei Abbruch.
Future<Map<String, SyncSeite>?> showSyncFeldEntscheidung({
  required BuildContext context,
  required List<SyncKonfliktFeld> felder,
}) {
  return showDialog<Map<String, SyncSeite>>(
    context: context,
    builder: (_) => _SyncFeldEntscheidung(felder: felder),
  );
}

class _SyncFeldEntscheidung extends StatefulWidget {
  const _SyncFeldEntscheidung({required this.felder});

  final List<SyncKonfliktFeld> felder;

  @override
  State<_SyncFeldEntscheidung> createState() => _SyncFeldEntscheidungState();
}

class _SyncFeldEntscheidungState extends State<_SyncFeldEntscheidung> {
  final Map<String, SyncSeite> _wahl = <String, SyncSeite>{};

  void _alle(SyncSeite seite) {
    setState(() {
      for (final feld in widget.felder) {
        _wahl[feld.schluessel] = seite;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vollstaendig = widget.felder.every(
      (feld) => _wahl.containsKey(feld.schluessel),
    );
    return AlertDialog(
      key: const ValueKey<String>('sync-feld-entscheidung'),
      title: const Text('Widersprüchliche Werte'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alles andere wird zusammengeführt. Diese Werte wurden auf '
                'beiden Geräten verschieden geändert — wähle je Wert, welcher '
                'gilt.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    key: const ValueKey<String>('sync-feld-alle-online'),
                    onPressed: () => _alle(SyncSeite.online),
                    child: const Text('Alle: Online'),
                  ),
                  TextButton(
                    key: const ValueKey<String>('sync-feld-alle-lokal'),
                    onPressed: () => _alle(SyncSeite.lokal),
                    child: const Text('Alle: Lokal'),
                  ),
                ],
              ),
              for (final feld in widget.felder) ...[
                const Divider(),
                Text(
                  labelForSyncDiffPath(feld.pfad),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _wahlChip(feld, SyncSeite.online),
                    _wahlChip(feld, SyncSeite.lokal),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('sync-feld-abbrechen'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('sync-feld-uebernehmen'),
          onPressed: vollstaendig
              ? () =>
                    Navigator.of(context).pop(Map<String, SyncSeite>.of(_wahl))
              : null,
          child: const Text('Zusammenführen'),
        ),
      ],
    );
  }

  Widget _wahlChip(SyncKonfliktFeld feld, SyncSeite seite) {
    final online = seite == SyncSeite.online;
    final fehlt = online ? feld.onlineFehlt : feld.lokalFehlt;
    final wert = fehlt
        ? '(nicht vorhanden)'
        : formatSyncDiffValue(online ? feld.online : feld.lokal);
    return ChoiceChip(
      key: ValueKey<String>('sync-feld-${feld.schluessel}-${seite.name}'),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(
          '${online ? 'Online' : 'Lokal'}: $wert',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      selected: _wahl[feld.schluessel] == seite,
      onSelected: (_) => setState(() => _wahl[feld.schluessel] = seite),
    );
  }
}
