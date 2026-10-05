import 'gefecht.dart';
import 'probe_engine.dart';

/// Konkretes Kampfmittel einschließlich bestätigtem BF und Profilnachweis.
class GefechtsBruchprofil {
  /// Bindet Folgewürfe an einen stabilen Inventareintrag.
  const GefechtsBruchprofil(this.wahl, this.name, this.bf, this.nachweis);
  final GefechtsKampfmittelwahl wahl;
  final String name, nachweis;
  final int bf;
}

/// Belegte Nahkampf-Patzerfolge; Umgebung und Verletzungen bleiben gezielt manuell.
class GefechtsPatzerfolge {
  /// Trennt Tabellenwirkung von noch fehlenden situativen Angaben.
  const GefechtsPatzerfolge({
    required this.titel,
    required this.iniVerlust,
    this.zerbrochen = false,
    this.waffeVerloren = false,
    this.sturz = false,
    this.bfAenderung = 0,
    this.schadensFaktor = 0,
  });
  final String titel;
  final int iniVerlust, bfAenderung, schadensFaktor;
  final bool zerbrochen, waffeVerloren, sturz;
}

/// Einfrieren des Bruchwürfels verhindert Wiederholungswürfe nach Speicherfehlern.
class GefechtsBruchauftrag {
  /// Der Anlass ist ausdrücklich am Tisch festgestellt, kein angenommener Treffer.
  const GefechtsBruchauftrag({
    required this.profil,
    required this.kritisch,
    this.wurf,
    this.erledigt = false,
  });
  final GefechtsBruchprofil profil;
  final bool kritisch, erledigt;
  final int? wurf;

  /// Erhält den Wurf auch bei erneut zu bestätigendem aktuellem Profil.
  GefechtsBruchauftrag copyWith({
    GefechtsBruchprofil? profil,
    int? wurf,
    bool? erledigt,
  }) => GefechtsBruchauftrag(
    profil: profil ?? this.profil,
    kritisch: kritisch,
    wurf: wurf ?? this.wurf,
    erledigt: erledigt ?? this.erledigt,
  );
}

/// Tatsächlich gebuchte Zwanzig mit ursprünglichem modifiziertem Kontrollziel.
class GefechtsPatzerauftrag {
  /// Kontroll- und Tabellenwürfe werden jeweils höchstens einmal ausgewertet.
  const GefechtsPatzerauftrag({
    required this.id,
    required this.original,
    required this.kampfmittel,
    this.profil,
    this.kontrolle,
    this.tabelle,
    this.erledigt = false,
  });
  final String id;
  final ProbeResult original;
  final GefechtsKampfmittelwahl? kampfmittel;
  final GefechtsBruchprofil? profil;
  final ProbeResult? kontrolle;
  final int? tabelle;
  final bool erledigt;

  /// Hält bereits gewürfelte Folgeschritte für Wiederaufnahme fest.
  GefechtsPatzerauftrag copyWith({
    ProbeResult? kontrolle,
    GefechtsBruchprofil? profil,
    int? tabelle,
    bool? erledigt,
  }) => GefechtsPatzerauftrag(
    id: id,
    original: original,
    kampfmittel: kampfmittel,
    profil: profil ?? this.profil,
    kontrolle: kontrolle ?? this.kontrolle,
    tabelle: tabelle ?? this.tabelle,
    erledigt: erledigt ?? this.erledigt,
  );
}

/// Bruchtestergebnis ändert niemals eigenständig den Waffenbestand.
class GefechtsBruchergebnis {
  /// BF ist der nach Quellen/Hausregel zu speichernde Wert.
  const GefechtsBruchergebnis(this.bf, this.zerbrochen);
  final int bf;
  final bool zerbrochen;
}

/// Nur innerhalb einer laufenden Heldensitzung gültige Defekte und Folgewürfe.
class GefechtsPatzerstand {
  /// Kein Teil dieses Zustands wird in ein Heldenmodell serialisiert.
  const GefechtsPatzerstand({
    this.patzer,
    this.bruch,
    this.gesperrteMittel = const {},
    this.verloreneMittel = const {},
    this.verloreneRunde,
    this.verarbeiteteAuftraege = const {},
  });
  final GefechtsPatzerauftrag? patzer;
  final GefechtsBruchauftrag? bruch;
  final Map<String, String> gesperrteMittel;
  final Set<String> verloreneMittel;
  final int? verloreneRunde;
  final Set<String> verarbeiteteAuftraege;

  /// Bewahrt gefrorene Ergebnisse und verhindert doppelte Auftragseinträge.
  GefechtsPatzerstand copyWith({
    GefechtsPatzerauftrag? patzer,
    GefechtsBruchauftrag? bruch,
    Map<String, String>? gesperrteMittel,
    Set<String>? verloreneMittel,
    int? verloreneRunde,
    Set<String>? verarbeiteteAuftraege,
    bool ohnePatzer = false,
    bool ohneBruch = false,
  }) => GefechtsPatzerstand(
    patzer: ohnePatzer ? null : patzer ?? this.patzer,
    bruch: ohneBruch ? null : bruch ?? this.bruch,
    gesperrteMittel: gesperrteMittel ?? this.gesperrteMittel,
    verloreneMittel: verloreneMittel ?? this.verloreneMittel,
    verloreneRunde: verloreneRunde ?? this.verloreneRunde,
    verarbeiteteAuftraege: verarbeiteteAuftraege ?? this.verarbeiteteAuftraege,
  );
}
