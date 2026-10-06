import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_filter_rules.dart';

/// Suchbare Liste der erlernten und allgemein verfügbaren Manöver.
class GefechtManoeverliste extends StatefulWidget {
  /// Die Reihenfolge stammt aus den Regeln; Darstellung berechnet keine Freigaben.
  const GefechtManoeverliste({
    super.key,
    required this.manoever,
    required this.knopf,
    this.gesperrt,
  });
  final List<ManeuverDef> manoever;
  final Widget Function(ManeuverDef) knopf;
  final bool Function(ManeuverDef)? gesperrt;
  @override
  State<GefechtManoeverliste> createState() => _GefechtManoeverlisteState();
}

class _GefechtManoeverlisteState extends State<GefechtManoeverliste> {
  String _suche = '';
  GefechtsManoeverfilter _kategorie = GefechtsManoeverfilter.alle;
  bool _ohneSperre = false;
  @override
  Widget build(BuildContext context) => KartoAbschnitt(
    titel: 'Manöver',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Manöver suchen',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() {
            _suche = v.toLowerCase();
          }),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final k in GefechtsManoeverfilter.values)
              ChoiceChip(
                label: Text(switch (k) {
                  GefechtsManoeverfilter.alle => 'Alle',
                  GefechtsManoeverfilter.angriff => 'Angriff',
                  GefechtsManoeverfilter.verteidigung => 'Verteidigung',
                  GefechtsManoeverfilter.sonstige => 'Sonstige',
                }),
                selected: _kategorie == k,
                onSelected: (_) => setState(() {
                  _kategorie = k;
                }),
              ),
            FilterChip(
              label: const Text('Ohne bekannte Sperre'),
              selected: _ohneSperre,
              onSelected: (v) => setState(() {
                _ohneSperre = v;
              }),
            ),
          ],
        ),
        if (widget.manoever.isEmpty)
          const Text('Keine erlernten oder allgemein verfügbaren Manöver.'),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final m in widget.manoever)
                  if (gefechtsManoeverImFilter(
                    m,
                    kategorie: _kategorie,
                    suche: _suche,
                    ohneSperre: _ohneSperre,
                    gesperrt: widget.gesperrt?.call(m) ?? false,
                  ))
                    widget.knopf(m),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
