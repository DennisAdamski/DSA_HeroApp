import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';

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
      datum.day == station.datum.day &&
      datum.month == station.datum.month &&
      datum.year == station.datum.year;
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
  });

  /// Vorbelegung bzw. bestehende Station.
  final HeroReiseStation station;

  /// Abenteuer des Helden zur Zuordnung.
  final List<HeroAdventureEntry> abenteuer;

  /// Ob eine vorhandene Station bearbeitet wird.
  final bool bearbeitet;

  @override
  State<KartoReiseStationDialog> createState() =>
      _KartoReiseStationDialogState();
}

class _KartoReiseStationDialogState extends State<KartoReiseStationDialog> {
  late final TextEditingController _ort = TextEditingController(
    text: widget.station.ort,
  );
  late final TextEditingController _tag = TextEditingController(
    text: widget.station.datum.day,
  );
  late final TextEditingController _jahr = TextEditingController(
    text: widget.station.datum.year,
  );
  late final TextEditingController _notiz = TextEditingController(
    text: widget.station.notiz,
  );
  late String _monat = normalizeAventurianMonth(widget.station.datum.month);
  late String _abenteuerId = widget.station.adventureId;

  @override
  void dispose() {
    _ort.dispose();
    _tag.dispose();
    _jahr.dispose();
    _notiz.dispose();
    super.dispose();
  }

  bool get _leer =>
      _ort.text.trim().isEmpty &&
      _notiz.text.trim().isEmpty &&
      _tag.text.trim().isEmpty &&
      _jahr.text.trim().isEmpty &&
      _monat.isEmpty;

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
              TextField(
                key: const ValueKey<String>('karto-reise-ort'),
                controller: _ort,
                autofocus: !widget.bearbeitet && widget.station.ort.isEmpty,
                decoration: const InputDecoration(
                  labelText: 'Ort',
                  hintText: 'z. B. Gareth',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Abstand.weit),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: TextField(
                      key: const ValueKey<String>('karto-reise-tag'),
                      controller: _tag,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tag'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Abstand.normal),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey<String>('karto-reise-monat'),
                      initialValue: _monat,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Monat'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('—')),
                        for (final monat in aventurianMonths)
                          DropdownMenuItem(
                            value: monat.value,
                            child: Text(monat.label),
                          ),
                      ],
                      onChanged: (wert) => setState(() => _monat = wert ?? ''),
                    ),
                  ),
                  const SizedBox(width: Abstand.normal),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      key: const ValueKey<String>('karto-reise-jahr'),
                      controller: _jahr,
                      decoration: const InputDecoration(
                        labelText: 'Jahr',
                        suffixText: 'BF',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
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
                    // Per `copyWith`, damit unbekannte Felder erhalten bleiben.
                    datum: widget.station.datum.copyWith(
                      day: _tag.text.trim(),
                      month: _monat,
                      year: _jahr.text.trim(),
                    ),
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
