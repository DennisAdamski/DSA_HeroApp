/// Ein ausdrücklich erfasster Gegner der lokalen, flüchtigen Begegnung.
class Gefechtsgegner {
  /// Die stabile ID trennt auch Gegner mit gleichem Namen.
  const Gefechtsgegner({
    required this.id,
    required this.name,
    required this.lep,
    required this.rs,
    required this.ini,
    this.liegend = false,
    this.entwaffnet = false,
  });
  final String id, name;
  final int lep, rs, ini;
  final bool liegend, entwaffnet;

  /// Erhält die Identität bei manuellen Korrekturen und bestätigten Folgen.
  Gefechtsgegner copyWith({
    String? name,
    int? lep,
    int? rs,
    int? ini,
    bool? liegend,
    bool? entwaffnet,
  }) => Gefechtsgegner(
    id: id,
    name: name ?? this.name,
    lep: lep ?? this.lep,
    rs: rs ?? this.rs,
    ini: ini ?? this.ini,
    liegend: liegend ?? this.liegend,
    entwaffnet: entwaffnet ?? this.entwaffnet,
  );
}

/// Gemeinsam genutzte Gegner und einmalige Buchungen ohne JSON oder Speicherweg.
class Gefechtsbegegnung {
  /// Ein neuer App-Prozess beginnt mit einer leeren Begegnung.
  const Gefechtsbegegnung({this.gegner = const {}, this.buchungen = const {}});
  final Map<String, Gefechtsgegner> gegner;
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
