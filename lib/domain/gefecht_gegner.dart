import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';

/// Größenklassen nach der Zielgrößentabelle (WdS S. 97).
enum GefechtsGroesse { winzig, sehrKlein, klein, mittel, gross, sehrGross }

/// Deutschsprachige Anzeigenamen der Größenklassen.
const Map<GefechtsGroesse, String> gefechtsGroesseLabel = {
  GefechtsGroesse.winzig: 'winzig',
  GefechtsGroesse.sehrKlein: 'sehr klein',
  GefechtsGroesse.klein: 'klein',
  GefechtsGroesse.mittel: 'mittel',
  GefechtsGroesse.gross: 'groß',
  GefechtsGroesse.sehrGross: 'sehr groß',
};

/// Körperbau bestimmt später die Trefferzonen (WdS S. 97 und 108).
enum GefechtsKoerperbau { zweibeiner, tier }

/// Ob ein Gegner noch am Kampf teilnimmt; nur der Nutzer setzt ihn.
enum GefechtsgegnerStatus { kaempft, kampfunfaehig, tot, geflohen }

/// Deutschsprachige Anzeigenamen der Gegnerzustände.
const Map<GefechtsgegnerStatus, String> gefechtsgegnerStatusLabel = {
  GefechtsgegnerStatus.kaempft: 'kämpft',
  GefechtsgegnerStatus.kampfunfaehig: 'kampfunfähig',
  GefechtsgegnerStatus.tot: 'tot',
  GefechtsgegnerStatus.geflohen: 'geflohen',
};

/// Ein bestätigter Treffer gegen einen Gegner.
///
/// Gespeichert werden nur die Eingaben; SP, LeP und Wunden leitet
/// `gefechtsGegnerstand` ab, damit ein später bekannter RS oder KO alle
/// Treffer neu verrechnet.
class Gefechtsgegnertreffer {
  /// [buchungId] ist dieselbe ID, die doppelte Buchungen verhindert.
  const Gefechtsgegnertreffer({
    required this.buchungId,
    required this.tp,
    this.direkt = false,
    this.zone,
    this.wunden,
    this.runde,
    this.von = '',
  });
  final String buchungId;
  final int tp;

  /// Direkte SP umgehen den Rüstungsschutz (WdS S. 56).
  final bool direkt;
  final WundZone? zone;

  /// Von Hand bestätigte Wunden; gelten nur, wenn RS oder KO unbekannt sind.
  final int? wunden;
  final int? runde;

  /// Anzeigename des Angreifers oder der Quelle.
  final String von;
}

/// Ein ausdrücklich erfasster Gegner der lokalen, flüchtigen Begegnung.
class Gefechtsgegner {
  /// Die stabile ID trennt auch Gegner mit gleichem Namen.
  const Gefechtsgegner({
    required this.id,
    required this.name,
    this.lep,
    this.rs,
    this.ko,
    required this.ini,
    this.liegend = false,
    this.entwaffnet = false,
    this.groesse = GefechtsGroesse.mittel,
    this.koerperbau = GefechtsKoerperbau.zweibeiner,
    this.status = GefechtsgegnerStatus.kaempft,
    this.bindet,
    this.treffer = const [],
  });
  final String id, name;

  /// LeP zu Beginn der Begegnung; `null`, solange sie unbekannt sind.
  final int? lep;

  /// Rüstungsschutz; `null`, solange er unbekannt ist.
  final int? rs;

  /// Konstitution für die Wundschwellen; `null`, solange sie unbekannt ist.
  final int? ko;
  final int ini;
  final bool liegend, entwaffnet;
  final GefechtsGroesse groesse;
  final GefechtsKoerperbau koerperbau;
  final GefechtsgegnerStatus status;

  /// Teilnehmer-ID (Held oder Gefährte), den dieser Gegner bindet.
  final String? bindet;

  /// Bestätigte Treffer in Buchungsreihenfolge.
  final List<Gefechtsgegnertreffer> treffer;

  /// Erhält die Identität bei manuellen Korrekturen und bestätigten Folgen.
  ///
  /// Für [lep], [rs], [ko] und [bindet] setzt ein ausdrückliches `null` den
  /// Wert auf unbekannt; ohne Angabe bleibt er erhalten.
  Gefechtsgegner copyWith({
    String? name,
    Object? lep = keepFieldValue,
    Object? rs = keepFieldValue,
    Object? ko = keepFieldValue,
    int? ini,
    bool? liegend,
    bool? entwaffnet,
    GefechtsGroesse? groesse,
    GefechtsKoerperbau? koerperbau,
    GefechtsgegnerStatus? status,
    Object? bindet = keepFieldValue,
    List<Gefechtsgegnertreffer>? treffer,
  }) => Gefechtsgegner(
    id: id,
    name: name ?? this.name,
    lep: identical(lep, keepFieldValue) ? this.lep : lep as int?,
    rs: identical(rs, keepFieldValue) ? this.rs : rs as int?,
    ko: identical(ko, keepFieldValue) ? this.ko : ko as int?,
    ini: ini ?? this.ini,
    liegend: liegend ?? this.liegend,
    entwaffnet: entwaffnet ?? this.entwaffnet,
    groesse: groesse ?? this.groesse,
    koerperbau: koerperbau ?? this.koerperbau,
    status: status ?? this.status,
    bindet: identical(bindet, keepFieldValue) ? this.bindet : bindet as String?,
    treffer: treffer ?? this.treffer,
  );
}

/// Gemeinsam genutzte Gegner und einmalige Buchungen ohne JSON oder Speicherweg.
class Gefechtsbegegnung {
  /// Ein neuer App-Prozess beginnt mit einer leeren Begegnung.
  const Gefechtsbegegnung({this.gegner = const {}, this.buchungen = const {}});
  final Map<String, Gefechtsgegner> gegner;

  /// Verbrauchte Buchungs-IDs; eine Rücknahme gibt sie nicht wieder frei.
  final Set<String> buchungen;

  /// Übergibt unveränderliche Ergebnisse reiner Regeln an den Provider.
  Gefechtsbegegnung copyWith({
    Map<String, Gefechtsgegner>? gegner,
    Set<String>? buchungen,
  }) => Gefechtsbegegnung(
    gegner: gegner ?? this.gegner,
    buchungen: buchungen ?? this.buchungen,
  );
}
