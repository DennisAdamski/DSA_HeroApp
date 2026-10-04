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
    if (a.manuell &&
        a.probe == null &&
        a.zielwert == null &&
        a.aktion != Gefechtsaktion.orientieren)
      'Grundzielwert für die manuelle Probe eintragen.',
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
  final status = sperren.isNotEmpty
      ? Gefechtsfreigabe.gesperrt
      : fehlend.isNotEmpty || entscheidungen.isNotEmpty || hinweise.isNotEmpty
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
