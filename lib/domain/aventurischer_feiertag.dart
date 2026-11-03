import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';

/// Art eines Feiertags, angelehnt an die Spalte „Art“ der Feiertagsliste der
/// Wiki Aventurica.
enum FeiertagArt {
  /// Fest einer Kirche oder eines Kultes; die Gottheit steht in
  /// [AventurischerFeiertag.gottheit].
  religioes,

  /// Kulturelles Fest, etwa ein Volks- oder Zunftfest.
  kulturell,

  /// Weltlicher Feiertag, etwa ein Nationalfeiertag.
  weltlich,

  /// Lokaler oder regionaler Feiertag.
  regional,

  /// Militärischer Feiertag.
  militaerisch,

  /// Trauertag.
  trauertag,

  /// Gedenktag.
  gedenktag,
}

/// Ein datumsfester Feiertag im aventurischen Kalender.
///
/// Reine Regeldaten, die nicht am Helden gespeichert werden. [art] und
/// [verbreitung] sind der Andockpunkt für die spätere Filterung nach Region,
/// Volk oder Kirche. Bewegliche Feiertage (Wochentag- oder Mondbezug) kennt das
/// Modell noch nicht.
class AventurischerFeiertag {
  /// Erzeugt einen Feiertag aus Tagesnummern im Jahr (1 bis 365).
  ///
  /// [bisTagImJahr] darf vor [vonTagImJahr] liegen: dann überspannt der
  /// Zeitraum den Jahreswechsel.
  const AventurischerFeiertag({
    required this.name,
    required this.vonTagImJahr,
    required this.bisTagImJahr,
    required this.art,
    this.gottheit,
    this.verbreitung = '',
  });

  /// Erzeugt einen Feiertag aus Tag und Monatsschlüssel ([aventurianMonths]).
  ///
  /// Ohne [bisTag] ist es ein Eintagesfest; [bisMonat] gilt nur für Zeiträume,
  /// die den Monat wechseln, und ist sonst [monat]. Ein unbekannter Monat oder
  /// ein Tag außerhalb des Monats ist ein Programmierfehler der Datentabelle.
  factory AventurischerFeiertag.am({
    required String name,
    required int tag,
    required String monat,
    int? bisTag,
    String? bisMonat,
    required FeiertagArt art,
    String? gottheit,
    String verbreitung = '',
  }) {
    return AventurischerFeiertag(
      name: name,
      vonTagImJahr: _tagImJahr(tag, monat),
      bisTagImJahr: _tagImJahr(bisTag ?? tag, bisMonat ?? monat),
      art: art,
      gottheit: gottheit,
      verbreitung: verbreitung,
    );
  }

  /// Anzeigename, z. B. `Tag des Schwures`.
  final String name;

  /// Erster Tag als laufende Nummer im Jahr (1 = 1. Praios).
  final int vonTagImJahr;

  /// Letzter Tag als laufende Nummer im Jahr; bei Eintagesfesten gleich
  /// [vonTagImJahr].
  final int bisTagImJahr;

  /// Art des Feiertags.
  final FeiertagArt art;

  /// Gottheit eines religiösen Feiertags, sonst `null`.
  final String? gottheit;

  /// Wo der Feiertag begangen wird, z. B. `Novadis` oder `Mittelreich`; leer
  /// bedeutet keine Angabe.
  final String verbreitung;

  /// Ob der Feiertag nur einen Tag dauert.
  bool get istEintaegig => vonTagImJahr == bisTagImJahr;

  /// Anzahl der Tage des Zeitraums, auch über den Jahreswechsel.
  int get dauerTage => (bisTagImJahr - vonTagImJahr) % _tageImJahr + 1;
}

// Tage in einem aventurischen Jahr (zwölf Monate zu 30 Tagen plus fünf
// Namenlose Tage); dieselbe Zahl wie `aventurianDaysPerYear`, die in der
// Regelschicht liegt und das Modell nicht importieren soll.
const int _tageImJahr =
    12 * aventurianDaysPerMonth + aventurianNamenloseTageCount;

int _tagImJahr(int tag, String monat) {
  final index = aventurianMonthIndex(monat);
  if (index == null) {
    throw ArgumentError.value(monat, 'monat', 'Unbekannter Monat');
  }
  final maxTag = aventurianMonths[index].value == aventurianNamenloseTageKey
      ? aventurianNamenloseTageCount
      : aventurianDaysPerMonth;
  if (tag < 1 || tag > maxTag) {
    throw ArgumentError.value(tag, 'tag', 'Tag außerhalb von $monat');
  }
  return index * aventurianDaysPerMonth + tag;
}
