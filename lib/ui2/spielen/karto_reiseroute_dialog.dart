import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_datum_felder.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ort_feld.dart';

/// Ergebnis des Stationsdialogs: die geänderten Felder oder der Löschwunsch.
class KartoReiseStationEingabe {
  /// Erfasste Werte einer Station.
  const KartoReiseStationEingabe({
    required this.ort,
    required this.datum,
    required this.notiz,
    required this.adventureId,
    this.ortId = '',
    this.kartenX,
    this.kartenY,
  }) : loeschen = false;

  /// Die Station soll entfernt werden.
  const KartoReiseStationEingabe.loeschen()
    : ort = '',
      datum = const HeroAdventureDateValue(),
      notiz = '',
      adventureId = '',
      ortId = '',
      kartenX = null,
      kartenY = null,
      loeschen = true;

  final String ort;
  final HeroAdventureDateValue datum;
  final String notiz;
  final String adventureId;

  /// Kennung des Orts der Karte, auf den [ort] verweist; leer ohne Verweis
  /// (Freitext, Ort ohne Position oder Ortsverzeichnis nicht verfügbar).
  final String ortId;

  /// Kartenposition des verknüpften Orts, oder `null` ohne Verweis.
  final double? kartenX;

  /// Kartenposition des verknüpften Orts, oder `null` ohne Verweis.
  final double? kartenY;

  final bool loeschen;

  /// Ob die Eingabe einen Verweis auf einen Ort der Karte trägt.
  bool get hatOrtsVerweis =>
      ortId.isNotEmpty && kartenX != null && kartenY != null;

  /// Ob die Eingabe dieselben Werte wie [station] trägt.
  ///
  /// Eine Eingabe ohne Verweis lässt einen bestehenden Verweis der Station
  /// unberührt; ein neuer oder anderer Verweis zählt als Änderung.
  bool gleichWie(HeroReiseStation station) =>
      !loeschen &&
      ort == station.ort &&
      (!hatOrtsVerweis || ortId == station.ortId) &&
      notiz == station.notiz &&
      adventureId == station.adventureId &&
      datum.gleicheAngabe(station.datum);
}

/// Erfasst oder bearbeitet eine Station der Reiseroute: Ort, aventurisches
/// Datum, Abenteuer und Notiz.
///
/// Verweist der Ortsname auf einen Ort mit Kartenposition (gewählter
/// Vorschlag oder eindeutig gleicher Name), trägt die Eingabe dessen Kennung
/// und Position.
class KartoReiseStationDialog extends ConsumerStatefulWidget {
  /// Dialog für [station]; [bearbeitet] bietet zusätzlich das Löschen an.
  const KartoReiseStationDialog({
    super.key,
    required this.station,
    required this.abenteuer,
    this.bearbeitet = false,
    this.orte,
  });

  /// Vorbelegung bzw. bestehende Station.
  final HeroReiseStation station;

  /// Abenteuer des Helden zur Zuordnung.
  final List<HeroAdventureEntry> abenteuer;

  /// Ob eine vorhandene Station bearbeitet wird.
  final bool bearbeitet;

  /// Festes Ortsverzeichnis für die Vorschläge im Ortsfeld.
  ///
  /// Ohne Angabe gilt die laufende Auswahlliste (`ortsverzeichnisProvider`);
  /// der Dialog fordert dann das Ortsverzeichnis von Avesmaps an.
  final List<OrtEintrag>? orte;

  @override
  ConsumerState<KartoReiseStationDialog> createState() =>
      _KartoReiseStationDialogState();
}

class _KartoReiseStationDialogState
    extends ConsumerState<KartoReiseStationDialog> {
  late final TextEditingController _ort = TextEditingController(
    text: widget.station.ort,
  );
  late HeroAdventureDateValue _datum = widget.station.datum;
  late final TextEditingController _notiz = TextEditingController(
    text: widget.station.notiz,
  );
  late String _abenteuerId = widget.station.adventureId;

  // Zuletzt übernommener Vorschlag; gilt, solange sein Name im Feld steht.
  OrtEintrag? _gewaehlt;

  @override
  void initState() {
    super.initState();
    if (widget.orte == null) {
      // Nach dem Bauen: Ein Provider darf währenddessen nicht geändert werden.
      Future<void>.microtask(() {
        if (!mounted) return;
        ref.read(avesmapsOrteAnforderungProvider.notifier).fordereAn();
      });
    }
  }

  @override
  void dispose() {
    _ort.dispose();
    _notiz.dispose();
    super.dispose();
  }

  bool get _leer =>
      _ort.text.trim().isEmpty &&
      _notiz.text.trim().isEmpty &&
      !_datum.hasContent;

  @override
  Widget build(BuildContext context) {
    // Eine Zuordnung zu einem inzwischen gelöschten Abenteuer bleibt
    // auswählbar, damit sie nicht still verloren geht.
    final abenteuerIds = {for (final a in widget.abenteuer) a.id};
    final verwaist =
        _abenteuerId.isNotEmpty && !abenteuerIds.contains(_abenteuerId);
    final fest = widget.orte;
    final List<OrtEintrag> orte = fest ?? ref.watch(ortsverzeichnisProvider);
    return AlertDialog(
      title: Text(widget.bearbeitet ? 'Station bearbeiten' : 'Neue Station'),
      content: SizedBox(
        width: Breite.klein,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KartoOrtFeld(
                feldSchluessel: const ValueKey<String>('karto-reise-ort'),
                controller: _ort,
                orte: orte,
                autofocus: !widget.bearbeitet && widget.station.ort.isEmpty,
                onChanged: (_) => setState(() {}),
                onOrtGewaehlt: (ort) => _gewaehlt = ort,
                onlineSuche: fest == null
                    ? ref.watch(avesmapsOnlineSucheProvider)
                    : null,
              ),
              const SizedBox(height: Abstand.weit),
              KartoDatumFelder(
                kennung: 'karto-reise',
                initial: widget.station.datum,
                onChanged: (datum) => setState(() => _datum = datum),
              ),
              const SizedBox(height: Abstand.weit),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('karto-reise-abenteuer'),
                initialValue: _abenteuerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Abenteuer'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('—')),
                  for (final abenteuer in widget.abenteuer)
                    DropdownMenuItem(
                      value: abenteuer.id,
                      child: Text(
                        abenteuer.title.trim().isEmpty
                            ? 'Ohne Titel'
                            : abenteuer.title.trim(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (verwaist)
                    DropdownMenuItem(
                      value: _abenteuerId,
                      child: const Text('Entferntes Abenteuer'),
                    ),
                ],
                onChanged: (wert) => setState(() => _abenteuerId = wert ?? ''),
              ),
              const SizedBox(height: Abstand.weit),
              TextField(
                key: const ValueKey<String>('karto-reise-notiz'),
                controller: _notiz,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Notiz',
                  hintText: 'Was ist hier geschehen?',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.bearbeitet)
          TextButton(
            key: const ValueKey<String>('karto-reise-loeschen'),
            onPressed: () =>
                Navigator.of(context)
                    .pop(const KartoReiseStationEingabe.loeschen()),
            child: const Text('Löschen'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-reise-speichern'),
          onPressed: _leer
              ? null
              : () {
                  final verweis = ortsVerweisFuer(
                    _ort.text,
                    orte,
                    gewaehlt: _gewaehlt,
                  );
                  Navigator.of(context).pop(
                    KartoReiseStationEingabe(
                      ort: _ort.text.trim(),
                      datum: _datum,
                      notiz: _notiz.text.trim(),
                      adventureId: _abenteuerId,
                      ortId: verweis?.ortId ?? '',
                      kartenX: verweis?.kartenX,
                      kartenY: verweis?.kartenY,
                    ),
                  );
                },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
