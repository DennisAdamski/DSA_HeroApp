import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';

/// Wirkung **einer** effektiven Wunde auf Kampfwerte und Eigenschaften.
///
/// Die Hausregel „Erweiterung und Überarbeitung des Regelwerks“ (S. 3) lässt
/// jede Wunde kombiniert nach Gesamt- und Zonensystem wirken: die
/// allgemeinen Abzüge ([kWundAllgemein], WdS S. 58) **plus** die der Zone
/// ([wundZonenWirkung], WdS S. 108 f.).
///
/// [eigenschaften] gelten nur für Proben. Laut WdS S. 111 (und BRW S. 194
/// für die GE) wirken wundbedingte Eigenschaftsverluste nicht auf AT-, PA-,
/// FK- und INI-Basis; die App lässt sie auch aus allen anderen abgeleiteten
/// Werten heraus (LeP, MR, Wundschwelle, TP/KK).
class WundWirkung {
  /// Erstellt eine Wirkung; ohne Angaben wirkt nichts.
  const WundWirkung({
    this.at = 0,
    this.pa = 0,
    this.fk = 0,
    this.iniBasis = 0,
    this.gs = 0,
    this.eigenschaften = const AttributeModifiers(),
    this.armgebunden = false,
  });

  /// AT-Abzug.
  final int at;

  /// PA-Abzug.
  final int pa;

  /// FK-Abzug.
  final int fk;

  /// Abzug auf den INI-Basiswert.
  final int iniBasis;

  /// GS-Abzug.
  final int gs;

  /// Eigenschaftsverluste, die ausschließlich bei Proben zählen.
  final AttributeModifiers eigenschaften;

  /// [at] und [pa] gelten nur für Waffen in diesem Arm („wenn er diesen Arm
  /// benutzt“, WdS S. 109) und nicht allgemein.
  final bool armgebunden;
}

/// Allgemeine Abzüge je Wunde (Gesamtsystem, WdS S. 58, BRW S. 194).
const WundWirkung kWundAllgemein = WundWirkung(
  at: -2,
  pa: -2,
  fk: -2,
  iniBasis: -2,
  gs: -1,
  eigenschaften: AttributeModifiers(ge: -2),
);

/// Zusätzliche Abzüge je Wunde in [zone] (Zonenwunden, WdS S. 108 f.).
///
/// Der Rücken zählt wie die Brust („Brust/Rücken“). Die gewürfelten 2W6
/// aktueller INI einer Kopfwunde betreffen nur den laufenden Kampf und
/// stehen deshalb nicht hier, sondern als Hinweis im `WundZustand`.
WundWirkung wundZonenWirkung(WundZone zone) {
  return switch (zone) {
    WundZone.kopf => const WundWirkung(
      iniBasis: -2,
      eigenschaften: AttributeModifiers(mu: -2, kl: -2, inn: -2),
    ),
    WundZone.brust || WundZone.ruecken => const WundWirkung(
      at: -1,
      pa: -1,
      eigenschaften: AttributeModifiers(ko: -1, kk: -1),
    ),
    WundZone.bauch => const WundWirkung(
      at: -1,
      pa: -1,
      iniBasis: -1,
      gs: -1,
      eigenschaften: AttributeModifiers(ko: -1, kk: -1),
    ),
    WundZone.linkerArm || WundZone.rechterArm => const WundWirkung(
      at: -2,
      pa: -2,
      eigenschaften: AttributeModifiers(ff: -2, kk: -2),
      armgebunden: true,
    ),
    WundZone.linkesBein || WundZone.rechtesBein => const WundWirkung(
      at: -2,
      pa: -2,
      iniBasis: -2,
      gs: -1,
      eigenschaften: AttributeModifiers(ge: -2),
    ),
  };
}

/// Rolle eines Arms im Kampf (WdS S. 108: Schwertarm und Schildarm).
enum ArmRolle {
  /// Führt die Hauptwaffe.
  schwertarm,

  /// Führt Schild, Parierwaffe oder Nebenhandwaffe.
  schildarm,
}

/// Anzeigenamen der Armrollen.
const Map<ArmRolle, String> armRolleLabel = <ArmRolle, String>{
  ArmRolle.schwertarm: 'Schwertarm',
  ArmRolle.schildarm: 'Schildarm',
};

/// Liefert die Rolle des Arms [zone] oder `null` für andere Zonen.
///
/// Standard ist rechts der Schwertarm, wie in der Trefferzonentabelle. Mit
/// dem Vorteil Linkshänder (Katalogschalter `linkshaender`) ist es
/// umgekehrt. Beidhändige Helden gelten wie Rechtshänder.
ArmRolle? armRolleFuer(WundZone zone, {required bool linkshaender}) {
  final rechts = switch (zone) {
    WundZone.rechterArm => true,
    WundZone.linkerArm => false,
    _ => null,
  };
  if (rechts == null) {
    return null;
  }
  return rechts != linkshaender ? ArmRolle.schwertarm : ArmRolle.schildarm;
}

/// Die Armzone, die für einen Helden die Rolle [rolle] trägt.
WundZone armZoneFuer(ArmRolle rolle, {required bool linkshaender}) {
  final schwertarmRechts = !linkshaender;
  final rechts = rolle == ArmRolle.schwertarm
      ? schwertarmRechts
      : !schwertarmRechts;
  return rechts ? WundZone.rechterArm : WundZone.linkerArm;
}

/// Zonenname samt Armrolle für die Anzeige, z. B. `Linker Arm (Schildarm)`.
String wundZonenAnzeige(WundZone zone, {required bool linkshaender}) {
  final label = wundZoneLabel[zone] ?? zone.name;
  final rolle = armRolleFuer(zone, linkshaender: linkshaender);
  return rolle == null ? label : '$label (${armRolleLabel[rolle]})';
}

/// Ob die dritte Wunde in [zone] den Helden kampfunfähig macht.
///
/// Kopf, Brust, Rücken und Bauch: ja. Die dritte Arm- oder Beinwunde legt
/// nur Arm bzw. Bein lahm (WdS S. 109: Arm aktionsunfähig, Bein Sturz und
/// kein Nahkampf), der Held bleibt handlungsfähig.
bool dritteWundeMachtKampfunfaehig(WundZone zone) {
  return switch (zone) {
    WundZone.kopf ||
    WundZone.brust ||
    WundZone.ruecken ||
    WundZone.bauch => true,
    _ => false,
  };
}

/// Skaliert [mods] mit [faktor], z. B. die Verluste einer Wunde auf n Wunden.
AttributeModifiers skaliereEigenschaften(AttributeModifiers mods, int faktor) {
  return AttributeModifiers(
    mu: mods.mu * faktor,
    kl: mods.kl * faktor,
    inn: mods.inn * faktor,
    ch: mods.ch * faktor,
    ff: mods.ff * faktor,
    ge: mods.ge * faktor,
    ko: mods.ko * faktor,
    kk: mods.kk * faktor,
  );
}

/// Folgen der dritten Wunde in [zone] nach WdS S. 108 f., als Hinweistext.
///
/// Die App rechnet sie nicht aus: Bewusstlosigkeit, Blutverlust und
/// Stürze gehören an den Spieltisch. Der Zusatzschaden der dritten Kopfwunde
/// steht im Schadensdialog als Zusatzwurf.
String dritteWundeFolge(WundZone zone) {
  return switch (zone) {
    WundZone.kopf =>
      '+2W6 SP, kampfunfähig, bewusstlos für W20 KR, '
          '1 LeP/KR Blutverlust bis versorgt',
    WundZone.brust || WundZone.ruecken || WundZone.bauch =>
      'kampfunfähig, bewusstlos für 1W20 KR, '
          '1 LeP/KR Blutverlust bis versorgt',
    WundZone.linkerArm ||
    WundZone.rechterArm => 'Arm aktionsunfähig, gehaltene Waffe fällt',
    WundZone.linkesBein ||
    WundZone.rechtesBein => 'Sturz, keine Teilnahme am Nahkampf',
  };
}
