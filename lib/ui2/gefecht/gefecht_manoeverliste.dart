import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';

/// Suchbare Manöverliste hält Verteidigung auch bei großen Katalogen erreichbar.
class GefechtManoeverliste extends StatefulWidget {
  /// Die Reihenfolge stammt aus den Regeln; Darstellung berechnet keine Freigaben.
  const GefechtManoeverliste({
    super.key,
    required this.manoever,
    required this.knopf,
  });
  final List<ManeuverDef> manoever;
  final Widget Function(ManeuverDef) knopf;
  @override
  State<GefechtManoeverliste> createState() => _GefechtManoeverlisteState();
}

class _GefechtManoeverlisteState extends State<GefechtManoeverliste> {
  String _suche = '';
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
        if (widget.manoever.isEmpty)
          const Text('Keine Manöver im aktuellen Katalog.'),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final m in widget.manoever)
                  if (m.name.toLowerCase().contains(_suche)) widget.knopf(m),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
