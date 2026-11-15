part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

/// Oeffnet den Dialog zur Bearbeitung mehrerer Talent-Modifikatorbausteine
/// (gemeinsamer Baustein: [showModifikatorenDialog]).
Future<List<HeroTalentModifier>?> _showTalentModifiersDialog({
  required BuildContext context,
  required String talentName,
  required List<HeroTalentModifier> initialModifiers,
}) {
  return showModifikatorenDialog(
    context: context,
    bezeichnung: talentName,
    schluesselPrefix: 'talent',
    modifikatoren: initialModifiers,
    leerText: 'Keine Modifikatoren vorhanden.',
  );
}
