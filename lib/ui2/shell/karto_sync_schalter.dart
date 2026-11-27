import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/sync_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_sync_anzeige.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Zeigt den Konto-Sync des gemeinsamen [syncStatusProvider] und gleicht auf
/// Tipp sofort ab.
///
/// Breit als ruhiger Fußeintrag der Bereichsnavigation, schmal als Symbol in
/// der AppBar mit demselben Text als Tooltip. Ohne Konto entfällt der Eintrag.
/// Zuordnung und Wortlaut liefert [beschreibeKartoSync]: Offene Konflikte
/// öffnen die Einstellungen, weil nur dort entschieden wird; sonst stößt der
/// Tipp `syncNow` an und meldet das Ergebnis kurz.
class KartoSyncSchalter extends ConsumerStatefulWidget {
  /// Erstellt den Schalter.
  const KartoSyncSchalter({
    super.key,
    required this.kompakt,
    required this.onEinstellungen,
  });

  /// Symbol statt Fußeintrag.
  final bool kompakt;

  /// Öffnet die Einstellungen (Konflikte, Fehlerdetails).
  final VoidCallback onEinstellungen;

  @override
  ConsumerState<KartoSyncSchalter> createState() => _KartoSyncSchalterState();
}

class _KartoSyncSchalterState extends ConsumerState<KartoSyncSchalter> {
  bool _laeuft = false;

  Future<void> _tippen(KartoSyncAnzeige anzeige) async {
    if (anzeige.aktion == KartoSyncAktion.einstellungen) {
      widget.onEinstellungen();
      return;
    }
    final controller = ref.read(syncControllerProvider);
    if (controller == null || _laeuft || controller.currentStatus.isSyncing) {
      return;
    }
    final meldungen = ScaffoldMessenger.maybeOf(context);
    setState(() => _laeuft = true);
    try {
      await controller.syncNow();
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
    if (!mounted || meldungen == null) return;
    final status = controller.currentStatus;
    final fehler = status.lastFailure;
    final konflikte = status.openConflicts.length;
    final String text;
    SnackBarAction? weiter;
    if (fehler != null) {
      text = 'Sync fehlgeschlagen: ${fehler.message}';
      weiter = SnackBarAction(
        label: 'Details',
        onPressed: widget.onEinstellungen,
      );
    } else if (konflikte > 0) {
      text = konflikte == 1
          ? 'Abgeglichen, 1 Konflikt offen.'
          : 'Abgeglichen, $konflikte Konflikte offen.';
      weiter = SnackBarAction(
        label: 'Lösen',
        onPressed: widget.onEinstellungen,
      );
    } else {
      text = 'Abgeglichen.';
    }
    meldungen
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: weiter));
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider).asData?.value;
    final anzeige = status == null
        ? null
        : beschreibeKartoSync(status, jetzt: DateTime.now());
    if (anzeige == null) return const SizedBox.shrink();
    final token = KartoTheme.of(context);
    final dringend = anzeige.stufe != KartoSyncStufe.ruhig;
    final farbe = dringend ? token.messingNavigation : token.navigationMuted;
    final onTap = _laeuft ? null : () => _tippen(anzeige);
    if (widget.kompakt) {
      return IconButton(
        key: const ValueKey<String>('karto-sync-anzeige'),
        tooltip: anzeige.text,
        onPressed: onTap,
        icon: Icon(anzeige.icon, color: dringend ? token.messing : null),
      );
    }
    // MergeSemantics: der Tooltip legt seine Angabe unter sich, die Prüfung
    // sucht vom Tooltip aus nach oben (siehe `_Fussziel`).
    return MergeSemantics(
      child: Tooltip(
        message: anzeige.text,
        child: InkWell(
          key: const ValueKey<String>('karto-sync-anzeige'),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: Abstand.block,
              vertical: Abstand.normal,
            ),
            child: Row(
              children: [
                Icon(anzeige.icon, size: 20, color: farbe),
                const SizedBox(width: Abstand.weit),
                Expanded(
                  child: Text(
                    anzeige.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: farbe,
                      fontWeight: dringend ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
