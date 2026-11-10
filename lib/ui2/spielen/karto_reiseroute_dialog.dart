import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
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
  }) : loeschen = false;

  /// Die Station soll entfernt werden.
  const KartoReiseStationEingabe.loeschen()
    : ort = '',
      datum = const HeroAdventureDateValue(),
      notiz = '',
      adventureId = '',
      loeschen = true;

  final String ort;
  final HeroAdventureDateValue datum;
  final String notiz;
  final String adventureId;
  final bool loeschen;

  /// Ob die Eingabe dieselben Werte wie [station] trägt.
  bool gleichWie(HeroReiseStation station) =>
      !loeschen &&
      ort == station.ort &&
      notiz == station.notiz &&
      adventureId == station.adventureId &&
      datum.gleicheAngabe(station.datum);
}

/// Erfasst oder bearbeitet eine Station der Reiseroute: Ort, aventurisches
/// Datum, Abenteuer und Notiz.
class KartoReiseStationDialog extends StatefulWidget {
  /// Dialog für [station]; [bearbeitet] bietet zusätzlich das Löschen an.
  const KartoReiseStationDialog({
    super.key,
    required this.station,
    required this.abenteuer,
    this.bearbeitet = false,
    this.orte = const <OrtEintrag>[],
  });

  /// Vorbelegung bzw. bestehende Station.
  final HeroReiseStation station;

  /// Abenteuer des Helden zur Zuordnung.
  final List<HeroAdventureEntry> abenteuer;

  /// Ob eine vorhandene Station bearbeitet wird.
  final bool bearbeitet;

  /// Ortsverzeichnis für die Vorschläge im Ortsfeld.
  final List<OrtEintrag> orte;

  @override
  State<KartoReiseStationDialog> createState() =>
      _KartoReiseStationDialogState();
}

class _KartoReiseStationDialogState extends State<KartoReiseStationDialog> {
  late final TextEditingController _ort = TextEditingController(
    text: widget.station.ort,
  );
  late HeroAdventureDateValue _datum = widget.station.datum;
  late final TextEditingController _notiz = TextEditingController(
    text: widget.station.notiz,
  );
  late String _abenteuerId = widget.station.adventureId;

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
                orte: widget.orte,
                autofocus: !widget.bearbeitet && widget.station.ort.isEmpty,
                onChanged: (_) => setState(() {}),
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
              : () => Navigator.of(context).pop(
                  KartoReiseStationEingabe(
                    ort: _ort.text.trim(),
                    datum: _datum,
                    notiz: _notiz.text.trim(),
                    adventureId: _abenteuerId,
                  ),
                ),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
