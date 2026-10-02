/// Art eines einzelnen gegnerischen Angriffs; unbekannt ist kein Nahkampf.
enum Gefechtsangriffsart { nahkampf, fernkampf, besonders }

/// Nur flüchtiger Kontakt; null bedeutet ausdrücklich noch nicht erfasst.
class Gefechtskontext {
  /// Trennt länger gültige Kontaktwerte von Angaben des aktuellen Angriffs.
  const Gefechtskontext({
    this.kontakt = '',
    this.gegnerzahl,
    this.gegnerDk,
    this.angriffsart,
    this.finte,
    this.paradeVerboten,
    this.platzZumAusweichen,
    this.sehrGross,
    this.grosserSchild,
    this.halbschwert = false,
    this.weitereRegelnGeprueft = false,
    this.entfernung,
    this.geladen,
    this.getuemmel = false,
    this.kontrollbereich = false,
    this.situationsZuschlag,
  });
  final String kontakt;
  final int? gegnerzahl, finte, entfernung, situationsZuschlag;
  final String? gegnerDk;
  final Gefechtsangriffsart? angriffsart;
  final bool? paradeVerboten,
      platzZumAusweichen,
      sehrGross,
      grosserSchild,
      geladen;
  final bool halbschwert, weitereRegelnGeprueft, getuemmel, kontrollbereich;

  /// Ändert nur benannte Kontextwerte; Angriffsdaten werden separat gelöscht.
  Gefechtskontext copyWith({
    int? entfernung,
    bool? geladen,
    bool? getuemmel,
    bool? kontrollbereich,
    int? situationsZuschlag,
    bool? weitereRegelnGeprueft,
    bool? halbschwert,
    bool ohneEntfernung = false,
    bool ohneSituationsZuschlag = false,
  }) => Gefechtskontext(
    kontakt: kontakt,
    gegnerzahl: gegnerzahl,
    gegnerDk: gegnerDk,
    angriffsart: angriffsart,
    finte: finte,
    paradeVerboten: paradeVerboten,
    platzZumAusweichen: platzZumAusweichen,
    sehrGross: sehrGross,
    grosserSchild: grosserSchild,
    halbschwert: halbschwert ?? this.halbschwert,
    weitereRegelnGeprueft: weitereRegelnGeprueft ?? this.weitereRegelnGeprueft,
    entfernung: ohneEntfernung ? null : entfernung ?? this.entfernung,
    geladen: geladen ?? this.geladen,
    getuemmel: getuemmel ?? this.getuemmel,
    kontrollbereich: kontrollbereich ?? this.kontrollbereich,
    situationsZuschlag: ohneSituationsZuschlag
        ? null
        : situationsZuschlag ?? this.situationsZuschlag,
  );

  /// Ein abgewehrter Angriff hinterlässt keine Finte für den folgenden Angriff.
  Gefechtskontext ohneAngriff() => Gefechtskontext(
    kontakt: kontakt,
    gegnerzahl: gegnerzahl,
    gegnerDk: gegnerDk,
    platzZumAusweichen: platzZumAusweichen,
    sehrGross: sehrGross,
    grosserSchild: grosserSchild,
    halbschwert: halbschwert,
    entfernung: entfernung,
    geladen: geladen,
    getuemmel: getuemmel,
    kontrollbereich: kontrollbereich,
  );
}

/// Bezeichneter Zielwertanteil, positiv als Erschwernis dargestellt.
class Gefechtsmodifikator {
  /// Behält die Herkunft statt eines undurchsichtigen Gesamtzuschlags.
  const Gefechtsmodifikator(this.name, this.wert);
  final String name;
  final int wert;
}
