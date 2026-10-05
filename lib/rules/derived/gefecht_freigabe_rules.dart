import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';

/// Ergänzt Formularpflichten unter Erhalt aller Budget- und Kampfmittelmetadaten.
Gefechtspruefung ergaenzeGefechtsfreigabe(
  Gefechtspruefung p,
  GefechtAuftrag a,
) {
  final sperren = p.sperrgruende.isNotEmpty
      ? p.sperrgruende
      : p.status == Gefechtsfreigabe.gesperrt
      ? p.gruende
      : <String>[];
  final fehlend = <String>[
    ...p.fehlendeAngaben,
    ...a.eingabefehler,
    if (a.dauer < 1) 'Gesamtdauer muss mindestens eine Aktion betragen.',
    if (a.kosten < 0 || a.kosten > 2) 'Kosten müssen zwischen 0 und 2 liegen.',
  ];
  final entscheidungen = <String>[
    ...p.entscheidungen,
    if (a.manuell) 'Wirkung und Ressourcen dieser Sonderaktion festgelegt.',
  ].where((e) => !a.bestaetigteEntscheidungen.contains(e)).toList();
  final hinweise = p.hinweise.isNotEmpty
      ? p.hinweise
      : p.gruende
            .where(
              (g) =>
                  !sperren.contains(g) &&
                  !fehlend.contains(g) &&
                  !p.entscheidungen.contains(g),
            )
            .toList();
  // Hinweise allein verhindern kein „Bereit“: sie blockieren die Ausführung
  // nicht (`Gefechtspruefung.ausfuehrbar`) und bleiben im Dialog sichtbar.
  final status = sperren.isNotEmpty
      ? Gefechtsfreigabe.gesperrt
      : fehlend.isNotEmpty || entscheidungen.isNotEmpty
      ? Gefechtsfreigabe.pruefen
      : Gefechtsfreigabe.bereit;
  return Gefechtspruefung(
    aktion: p.aktion,
    status: status,
    gruende: [...sperren, ...fehlend, ...entscheidungen, ...hinweise],
    sperrgruende: sperren,
    fehlendeAngaben: fehlend,
    entscheidungen: entscheidungen,
    hinweise: hinweise,
    zielwert: p.zielwert,
    angriffe: p.angriffe,
    paraden: p.paraden,
    freie: p.freie,
    zusatz: p.zusatz,
    erschwernis: p.erschwernis,
    modifikatoren: p.modifikatoren,
    kampfmittel: p.kampfmittel,
    ausruestungspaar: p.ausruestungspaar,
    mitAnsage: p.mitAnsage,
    probenart: p.probenart,
  );
}

/// Wichtigster sichtbare Grund einer Prüfung für Knopf und Leiste.
///
/// Reihenfolge: Sperre, fehlende Angabe, offene Entscheidung, Hinweis. Ohne
/// Grund ist die Aktion ohne weitere Klärung ausführbar (`null`).
String? gefechtsHauptgrund(Gefechtspruefung p) {
  for (final liste in [
    p.sperrgruende,
    if (p.status == Gefechtsfreigabe.gesperrt) p.gruende,
    p.fehlendeAngaben,
    p.entscheidungen,
    p.hinweise,
  ]) {
    if (liste.isNotEmpty) return liste.first;
  }
  return null;
}

/// Kurzer Statustext eines Aktionsknopfs: Würfeln mit Zielwert, sonst Status.
String gefechtsKnopfstatus(Gefechtspruefung p) => switch (p.status) {
  Gefechtsfreigabe.gesperrt => 'Gesperrt',
  Gefechtsfreigabe.pruefen =>
    p.fehlendeAngaben.isNotEmpty ? 'Angabe fehlt' : 'Klären',
  Gefechtsfreigabe.bereit =>
    p.zielwert == null ? 'Bereit' : 'Würfeln · ${p.zielwert}',
};
