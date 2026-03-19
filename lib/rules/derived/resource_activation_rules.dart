import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';

/// Effektiver Aktivierungsstatus eines einzelnen Ressourcen-Bereichs.
class ResourceActivationStatus {
  /// Erstellt den Aktivierungsstatus fuer einen Bereich.
  const ResourceActivationStatus({
    required this.autoEnabled,
    required this.isEnabled,
    required this.manualOverride,
  });

  /// Zeigt, ob die automatische Erkennung den Bereich aktivieren wuerde.
  final bool autoEnabled;

  /// Effektiver Aktivierungsstatus nach Anwendung eines manuellen Overrides.
  final bool isEnabled;

  /// Persistierter manueller Override; `null` bedeutet Auto-Modus.
  final bool? manualOverride;

  /// Kennzeichnet einen expliziten manuellen Override.
  bool get hasManualOverride => manualOverride != null;

  /// UI-Hinweis fuer die Herkunft des Status.
  String get sourceLabel => hasManualOverride ? 'manuell' : 'automatisch';
}

/// Effektiver Aktivierungsstatus fuer Magie und goettliche Ressourcen.
class HeroResourceActivation {
  /// Erstellt den kombinierten Aktivierungsstatus.
  const HeroResourceActivation({
    required this.magic,
    required this.divine,
  });

  /// Effektiver Status fuer Magie und AsP.
  final ResourceActivationStatus magic;

  /// Effektiver Status fuer goettliche Ressourcen und KaP.
  final ResourceActivationStatus divine;
}

/// Berechnet den effektiven Aktivierungsstatus eines Helden.
HeroResourceActivation computeHeroResourceActivation(HeroSheet hero) {
  final autoMagicEnabled = hasAutomaticMagicActivation(hero);
  final autoDivineEnabled = hasAutomaticDivineActivation(hero);
  final config = hero.resourceActivationConfig;
  return HeroResourceActivation(
    magic: ResourceActivationStatus(
      autoEnabled: autoMagicEnabled,
      isEnabled: config.magicEnabledOverride ?? autoMagicEnabled,
      manualOverride: config.magicEnabledOverride,
    ),
    divine: ResourceActivationStatus(
      autoEnabled: autoDivineEnabled,
      isEnabled: config.divineEnabledOverride ?? autoDivineEnabled,
      manualOverride: config.divineEnabledOverride,
    ),
  );
}

/// Prueft die automatische Aktivierung von Magie anhand der Stammdaten.
bool hasAutomaticMagicActivation(HeroSheet hero) {
  return _hasOriginOrAdvantageModifier(
    hero,
    recognizedCodes: const <String>{'ASP'},
  );
}

/// Prueft die automatische Aktivierung goettlicher Ressourcen.
bool hasAutomaticDivineActivation(HeroSheet hero) {
  return _hasOriginOrAdvantageModifier(
    hero,
    recognizedCodes: const <String>{'KAP'},
  );
}

bool _hasOriginOrAdvantageModifier(
  HeroSheet hero, {
  required Set<String> recognizedCodes,
}) {
  final relevantTexts = <String>[
    hero.background.rasseModText,
    hero.background.kulturModText,
    hero.background.professionModText,
    hero.vorteileText,
  ];
  for (final text in relevantTexts) {
    final codes = extractNormalizedStatModifierCodes(text);
    if (codes.any(recognizedCodes.contains)) {
      return true;
    }
  }
  return false;
}

/// Baut eine Persistenz-Konfiguration aus den uebergebenen Override-Werten.
HeroResourceActivationConfig buildResourceActivationConfig({
  bool? magicEnabledOverride,
  bool? divineEnabledOverride,
}) {
  return HeroResourceActivationConfig(
    magicEnabledOverride: magicEnabledOverride,
    divineEnabledOverride: divineEnabledOverride,
  );
}
