import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';

import 'gefecht_kontext_rules.dart';
import 'kampf_aenderung_rules.dart';

/// Liest ausschließlich eindeutig numerische, aufsteigende Entfernungsgrenzen.
int? gefechtsEntfernungsband(List<RangedDistanceBand> bands, int entfernung) {
  if (entfernung < 0 || bands.length != 5) return null;
  final grenzen = <int>[];
  var vorher = 0;
  for (final b in bands) {
    final grenze = int.tryParse(b.label.trim());
    if (grenze == null || grenze <= vorher) return null;
    grenzen.add(grenze);
    vorher = grenze;
  }
  for (var i = 0; i < grenzen.length; i++) {
    if (entfernung <= grenzen[i]) return i;
  }
  return -1;
}

/// Hausregel 25818 ersetzt den Zuschlag je Kampfteilnehmer durch SF-Stufen.
int gefechtsGetuemmelZuschlag({
  bool scharfschuetze = false,
  bool meisterschuetze = false,
  bool waffenmeister = false,
}) => waffenmeister
    ? 0
    : meisterschuetze
    ? 1
    : scharfschuetze
    ? 2
    : 3;

/// Bekannt leere/ungeladene Waffen werden vor der Probe verbindlich gesperrt.
Gefechtskontextpruefung pruefeGefechtsFernkampf(
  Gefechtszustand s,
  MainWeaponSlot? waffe, {
  bool scharfschuetze = false,
  bool meisterschuetze = false,
  bool waffenmeister = false,
}) {
  final k = s.kontext;
  final mods = <Gefechtsmodifikator>[];
  final fehlend = <String>[];
  final sperren = <String>[];
  if (k.geladen == null) fehlend.add('Ladezustand bestätigen.');
  if (k.geladen == false) sperren.add('Waffe ist nicht geladen.');
  final geschoss = waffe?.rangedProfile.selectedProjectileOrNull;
  if (geschoss == null) fehlend.add('Geschoss in der Ausrüstung auswählen.');
  if (geschoss != null && geschoss.count <= 0) {
    sperren.add('Keine Munition verfügbar.');
  }
  if (k.entfernung == null) {
    fehlend.add('Entfernung in Schritt erfassen.');
  } else {
    final index = gefechtsEntfernungsband(
      waffe?.rangedProfile.distanceBands ?? [],
      k.entfernung!,
    );
    if (index == null) {
      fehlend.add('Entfernungsprofil fehlt; Zielwert manuell bestätigen.');
    }
    if (index == -1) sperren.add('Ziel außerhalb der Waffenreichweite.');
    if (index != null && index >= 0) {
      mods.add(Gefechtsmodifikator('Entfernung', [-2, 0, 4, 8, 12][index]));
    }
  }
  if (k.situationsZuschlag == null) {
    fehlend.add('Zielgröße, Bewegung, Sicht und Deckung bestätigen.');
  }
  if (k.situationsZuschlag != null) {
    mods.add(Gefechtsmodifikator('Zielsituation', k.situationsZuschlag!));
  }
  if (k.getuemmel) {
    mods.add(
      Gefechtsmodifikator(
        'Kampfgetümmel',
        gefechtsGetuemmelZuschlag(
          scharfschuetze: scharfschuetze,
          meisterschuetze: meisterschuetze,
          waffenmeister: waffenmeister,
        ),
      ),
    );
  }
  return Gefechtskontextpruefung(mods, fehlend, sperren);
}

/// Verbraucht ein Geschoss frisch; ein leer gewordener Bestand darf nicht klemmen.
CombatConfig verbraucheGefechtsGeschoss(
  CombatConfig config,
  MainWeaponSlot angezeigt,
) {
  final frisch = config.weaponSlots
      .where((w) => w.id == angezeigt.id)
      .firstOrNull;
  if (frisch == null || frisch.id.isEmpty) {
    throw StateError('Waffe nicht mehr eindeutig vorhanden.');
  }
  final geschoss = angezeigt.rangedProfile.selectedProjectileOrNull;
  if (geschoss == null) throw StateError('Kein bestätigtes Geschoss.');
  final aktuell = frisch.rangedProfile.projectiles
      .where((g) => g.id == geschoss.id)
      .firstOrNull;
  if (aktuell == null || aktuell.count <= 0) {
    throw StateError('Geschoss fehlt oder ist inzwischen leer.');
  }
  return mitGeschossSchritt(
    config,
    angezeigt,
    geschoss,
    -1,
    geschossIndex: angezeigt.rangedProfile.selectedProjectileIndex,
  );
}
