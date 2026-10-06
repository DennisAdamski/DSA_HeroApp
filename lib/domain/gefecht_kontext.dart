/// Art eines einzelnen gegnerischen Angriffs; unbekannt ist kein Nahkampf.
enum Gefechtsangriffsart { nahkampf, fernkampf, besonders }

/// Nur flüchtiger Kontakt; null bedeutet ausdrücklich noch nicht erfasst.
class Gefechtskontext {
  /// Trennt länger gültige Kontaktwerte von Angaben des aktuellen Angriffs.
  const Gefechtskontext({
    this.kontakt = '',
    this.gegnerId,
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
    this.schildWmWirksam,
  });
  final String kontakt;

  /// Stabile ID des ausdrücklich gewählten lokalen Gegners.
  final String? gegnerId;

  /// Zielzeit ist bei erfassten Gegnern an Identität statt Namen gebunden.
  String get zielkennung => gegnerId == null ? kontakt : 'gegner:$gegnerId';
  final int? gegnerzahl, finte, entfernung, situationsZuschlag;
  final String? gegnerDk;
  final Gefechtsangriffsart? angriffsart;
  final bool? paradeVerboten,
      platzZumAusweichen,
      sehrGross,
      grosserSchild,
      geladen;

  /// Für diesen Angriff: Kettenstab, Kettenwaffe oder Peitsche hebt den WM auf.
  final bool? schildWmWirksam;
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
    bool? schildWmWirksam,
    bool ohneEntfernung = false,
    bool ohneSituationsZuschlag = false,
    bool ohneLadezustand = false,
  }) => Gefechtskontext(
    kontakt: kontakt,
    gegnerId: gegnerId,
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
    geladen: ohneLadezustand ? null : geladen ?? this.geladen,
    getuemmel: getuemmel ?? this.getuemmel,
    kontrollbereich: kontrollbereich ?? this.kontrollbereich,
    situationsZuschlag: ohneSituationsZuschlag
        ? null
        : situationsZuschlag ?? this.situationsZuschlag,
    schildWmWirksam: schildWmWirksam ?? this.schildWmWirksam,
  );

  /// Ein abgewehrter Angriff hinterlässt keine Finte für den folgenden Angriff.
  ///
  /// Die eigene Zielsituation im Fernkampf beschreibt das Ziel, nicht den
  /// gegnerischen Angriff, und bleibt deshalb wie die Entfernung erhalten.
  Gefechtskontext ohneAngriff() => Gefechtskontext(
    kontakt: kontakt,
    gegnerId: gegnerId,
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
    situationsZuschlag: situationsZuschlag,
  );
}

/// Bezeichneter Zielwertanteil, positiv als Erschwernis dargestellt.
class Gefechtsmodifikator {
  /// Behält die Herkunft statt eines undurchsichtigen Gesamtzuschlags.
  const Gefechtsmodifikator(this.name, this.wert);
  final String name;
  final int wert;
}
