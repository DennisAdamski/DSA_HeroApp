import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_meisterparade_rules.dart';

/// Zeigt die konkrete manuelle Folge erst nach einer einmalig gebuchten Fehlprobe.
Future<void> zeigeMeisterparadeFehlschlag(
  BuildContext context,
  GefechtAuftrag a,
  HeroComputedSnapshot snap,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Meisterparade misslungen'),
    content: SingleChildScrollView(
      child: Text(gefechtsMeisterparadeFehlschlag(a, snap)),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Am Tisch berücksichtigen'),
      ),
    ],
  ),
);
