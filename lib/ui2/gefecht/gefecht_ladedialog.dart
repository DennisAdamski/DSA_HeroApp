import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';

/// Klärt den anfänglichen Zustand konkret statt eine globale Ladung anzunehmen.
class GefechtLadedialog extends StatefulWidget {
  /// Bekannte Ladung bleibt verbindlich; nur ein unbekannter Anfang wird erfragt.
  const GefechtLadedialog({
    super.key,
    required this.zustand,
    required this.snapshot,
    required this.kampfmittel,
  });
  final Gefechtszustand zustand;
  final HeroComputedSnapshot snapshot;
  final GefechtsKampfmittelwahl kampfmittel;
  /// Erhält die ausdrückliche Anfangswahl während der Profil- und Budgetprüfung.
  @override
  State<GefechtLadedialog> createState() => _LadedialogState();
}

class _LadedialogState extends State<GefechtLadedialog> {
  bool? _anfang;
  @override
  Widget build(BuildContext context) {
    final w = gefechtsKampfmittelFuer(
      widget.snapshot,
      widget.kampfmittel,
    )?.waffe;
    final bekannt = gefechtsLadezustand(widget.zustand, w);
    final geladen = bekannt ?? _anfang;
    String? grund;
    Gefechtszustand? vorschau;
    try {
      vorschau = beginneGefechtsLaden(
        widget.zustand,
        widget.snapshot,
        widget.kampfmittel,
        anfangGeladen: geladen,
      );
    } on StateError catch (e) {
      grund = e.message.toString();
    }
    final dauer = widget.kampfmittel.art == GefechtsKampfmittelArt.nebenwaffe
        ? widget.snapshot.combatPreviewStats.offhandPreview?.reloadTimeDisplay
        : widget.snapshot.combatPreviewStats.reloadTimeDisplay;
    return AlertDialog(
      title: Text('${w?.name ?? 'Waffe'} laden / vorbereiten'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Aktuelle Ladezeit: ${dauer ?? 'Profil fehlt'}'),
              const Text(
                'Nur reguläre Aktionen bezahlen die Vorbereitung. '
                'Munition wird erst beim ausgeführten Schuss verbraucht.',
              ),
              if (bekannt == null)
                DropdownButtonFormField<bool>(
                  key: const ValueKey('gefecht-laden-anfang'),
                  initialValue: _anfang,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ladezustand zu Beginn',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: true,
                      child: Text('Geladen / bereit'),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text('Nicht geladen / nicht bereit'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _anfang = v),
                ),
              if (bekannt != null)
                Text(
                  bekannt ? 'Diese Waffe ist geladen.' : 'Diese Waffe ist entladen; die volle Vorbereitung ist erforderlich.',
                ),
              if (vorschau?.handlung != null)
                Text(
                  'Jetzt 1 Aktion bezahlen; ${vorschau!.handlung!.verbleibend} Aktionen bleiben.',
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (grund != null) Text(grund),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey('gefecht-laden-starten'),
          onPressed: grund == null
              ? () => Navigator.pop(context, geladen)
              : null,
          child: Text(
            geladen == true ? 'Anfangszustand übernehmen' : 'Laden beginnen',
          ),
        ),
      ],
    );
  }
}
