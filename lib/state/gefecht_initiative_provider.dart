import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_initiative.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_initiative_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';

import 'gefecht_provider.dart';
import 'gefecht_patzer_provider.dart';

import 'package:dsa_heldenverwaltung/rules/derived/gefecht_patzer_rules.dart';

import 'gefecht_begegnung_provider.dart';
import 'hero_providers.dart';
import 'catalog_providers.dart';

/// Verbindet ausdrücklich gewählte Heldensitzungen ohne Repository-Schreibzugriff.
class GefechtsinitiativController extends Notifier<Gefechtsinitiative> {
  /// Gruppenmitgliedschaft besteht ausschließlich im aktuellen App-Prozess.
  @override
  Gefechtsinitiative build() => const Gefechtsinitiative();

  /// Hinzufügen benötigt eine laufende Sitzung und einen geklärten Zeitpunkt.
  void hinzufuegen(String heroId, {required bool zeitpunktVorbei}) {
    final s = ref.read(gefechtProvider(heroId));
    if (s == null || s.auftrag != null || s.handlung != null) {
      throw StateError(
        'Zuerst das Einzelgefecht beginnen und offene Aufträge abschließen.',
      );
    }
    if (state.helden.isNotEmpty && s.runde != state.runde) {
      throw StateError('Held und Gruppe müssen in derselben Runde sein.');
    }
    state = state.copyWith(
      helden: Set.unmodifiable({...state.helden, heroId}),
      runde: state.helden.isEmpty ? s.runde : state.runde,
      erledigt: Set.unmodifiable({
        ...state.erledigt,
        if (zeitpunktVorbei) '$heroId:regulaer',
        if (zeitpunktVorbei) '$heroId:umgewandelt',
      }),
    );
  }

  /// Verabschiedet eine vollständig geklärte Sitzung aus der gemeinsamen Runde.
  void entfernen(String heroId) {
    final s = ref.read(gefechtProvider(heroId));
    final patzer = ref.read(gefechtPatzerProvider(heroId));
    if (gefechtFolgewuerfeOffen(patzer) ||
        s?.auftrag != null ||
        s?.handlung != null ||
        s?.angriffsergebnisse.isNotEmpty == true) {
      throw StateError('Offene Aufträge und Treffer zuerst abschließen.');
    }
    state = state.copyWith(
      helden: Set.unmodifiable(state.helden.where((id) => id != heroId)),
    );
  }

  /// Bestätigt einen am Tisch abgewickelten Zeitpunkt ohne zusätzliche Buchung.
  void abschliessen(String zeitId) {
    _pruefeOffeneAuftraege();
    final offen = _zeitpunkte(ref, state, beobachten: false);
    final z = offen.where((z) => z.id == zeitId).firstOrNull;
    if (z == null) return;
    if (z.reserve) {
      throw StateError('Reserve über ihre tatsächliche AT/PA abwickeln.');
    }
    final phase = state.phase ?? offen.firstOrNull?.ini;
    if (z.ini != phase) throw StateError('Nur die aktuelle Phase abschließen.');
    if (z.umgewandelt && offen.any((a) => a.ini == phase && !a.umgewandelt)) {
      throw StateError('Reguläre Aktionen zuerst abschließen.');
    }
    final weitereInPhase = offen.any((a) => a.ini == phase && a.id != zeitId);
    state = state.copyWith(
      erledigt: Set.unmodifiable({...state.erledigt, zeitId}),
      ohnePhase: !weitereInPhase,
    );
  }

  /// Wählt nach ausdrücklicher Klärung auch einen durch INI-Änderung verschobenen Zeitpunkt.
  void phaseSetzen(int ini) {
    _pruefeOffeneAuftraege();
    state = state.copyWith(phase: ini);
  }

  /// Gemeinsamer Rundenwechsel prüft alle Sitzungen vor der ersten Änderung.
  ///
  /// [vonRunde] ist die Runde, die der Aufrufer angezeigt hat. Ein zweiter
  /// Aufruf derselben Anzeige (Doppeltipp vor dem Neuaufbau) ändert nichts,
  /// statt alle Teilnehmer eine weitere Runde vorzurücken.
  void naechsteRunde({required int vonRunde}) {
    if (state.runde != vonRunde) return;
    _pruefeOffeneAuftraege();
    final neu = <String, Gefechtszustand>{};
    for (final id in state.helden) {
      final s = ref.read(gefechtProvider(id));
      if (s == null) throw StateError('Teilnehmersitzung fehlt.');
      neu[id] = naechsteGefechtsrunde(s);
    }
    for (final e in neu.entries) {
      ref.read(gefechtProvider(e.key).notifier).setzen(e.value);
    }
    state = state.copyWith(
      runde: state.runde + 1,
      erledigt: const {},
      ohnePhase: true,
    );
  }

  // Zwischenstände dürfen weder durch Phase noch gemeinsamen Rundenwechsel verloren gehen.
  void _pruefeOffeneAuftraege() {
    final sperre = _gruppenSperre(ref, state, beobachten: false);
    if (sperre != null) throw StateError(sperre);
    for (final id in state.helden) {
      final s = ref.read(gefechtProvider(id));
      final patzer = ref.read(gefechtPatzerProvider(id));
      final folgenOffen = gefechtFolgewuerfeOffen(patzer);
      if (folgenOffen ||
          s == null ||
          s.auftrag != null ||
          s.handlung?.verbleibend == 0 ||
          s.angriffsergebnisse.isNotEmpty ||
          s.klingen?.parade == false) {
        throw StateError(
          'Offene Probe, Treffer oder Übernahme zuerst abschließen.',
        );
      }
    }
  }
}

/// Gemeinsame Phasenführung wird erst durch ausdrückliche Teilnahme aktiviert.
final gefechtInitiativeProvider =
    NotifierProvider<GefechtsinitiativController, Gefechtsinitiative>(
      GefechtsinitiativController.new,
    );

/// Ermittelt offene Zeitpunkte aus frischen INI-Werten und bereits gebuchten Aktionen.
final gefechtsZeitpunkteProvider = Provider<List<Gefechtszeitpunkt>>(
  (ref) =>
      _zeitpunkte(ref, ref.watch(gefechtInitiativeProvider), beobachten: true),
);

/// Benennt unvollständige Teilnehmerdaten, statt ihre Zeitpunkte zu überspringen.
final gefechtInitiativSperreProvider = Provider<String?>(
  (ref) => _gruppenSperre(
    ref,
    ref.watch(gefechtInitiativeProvider),
    beobachten: true,
  ),
);

// Aktive Gruppenaktionen benötigen die Initiative aller gewählten Teilnehmer.
String? _gruppenSperre(
  Ref ref,
  Gefechtsinitiative gruppe, {
  required bool beobachten,
}) {
  for (final id in gruppe.helden) {
    final s = beobachten
        ? ref.watch(gefechtProvider(id))
        : ref.read(gefechtProvider(id));
    final snap = beobachten
        ? ref.watch(heroComputedProvider(id))
        : ref.read(heroComputedProvider(id));
    if (s == null || snap.asData?.value == null) {
      return 'Spielwerte eines Gruppenteilnehmers nicht geladen ($id). '
          'Aktive Gruppenaktionen bis zur Wiederherstellung gesperrt.';
    }
  }
  return null;
}

// Der Controller liest Quellen direkt, niemals einen von ihm abhängigen Provider.
List<Gefechtszeitpunkt> _zeitpunkte(
  Ref ref,
  Gefechtsinitiative gruppe, {
  required bool beobachten,
}) {
  if (_gruppenSperre(ref, gruppe, beobachten: beobachten) != null) {
    return const [];
  }
  final begegnung = beobachten
      ? ref.watch(gefechtBegegnungProvider)
      : ref.read(gefechtBegegnungProvider);
  final katalog =
      (beobachten
              ? ref.watch(rulesCatalogProvider)
              : ref.read(rulesCatalogProvider))
          .asData
          ?.value;
  final liste = <Gefechtszeitpunkt>[];
  final reserven = <({String id, String name, int ini})>[];
  for (final id in gruppe.helden) {
    final s = beobachten
        ? ref.watch(gefechtProvider(id))
        : ref.read(gefechtProvider(id));
    final snap =
        (beobachten
                ? ref.watch(heroComputedProvider(id))
                : ref.read(heroComputedProvider(id)))
            .asData
            ?.value;
    if (s == null || snap == null) continue;
    final w = gefechtswerteFuer(snap, katalog: katalog);
    if (s.reserveIni != null && s.reserveBereit) {
      reserven.add((id: id, name: snap.hero.name, ini: s.reserveIni!));
    }
    liste.addAll(
      gefechtsHeldenzeitpunkte(id, snap.hero.name, s, gefechtsInitiative(s, w)),
    );
  }
  for (final g in begegnung.gegner.values) {
    liste.add(
      Gefechtszeitpunkt(
        id: 'gegner:${g.id}',
        teilnehmerId: g.id,
        name: g.name,
        ini: g.ini,
        ursprungsIni: g.ini,
        gegner: true,
      ),
    );
  }
  final regulareOffen = sortiereGefechtszeitpunkte(
    liste.where((z) => !gruppe.erledigt.contains(z.id)),
  );
  final reservePhase = gruppe.phase ?? regulareOffen.firstOrNull?.ini ?? 0;
  for (final r in reserven) {
    liste.add(
      Gefechtszeitpunkt(
        id: '${r.id}:reserve',
        teilnehmerId: r.id,
        name: r.name,
        ini: reservePhase,
        ursprungsIni: r.ini,
        reserve: true,
      ),
    );
  }
  return sortiereGefechtszeitpunkte(
    liste.where((z) => !gruppe.erledigt.contains(z.id)),
  );
}

/// Derselbe frische Phasenstand versorgt Liste, Dialog und tatsächliche Ausführung.
final gefechtMitInitiativeProvider = Provider.family<Gefechtszustand?, String>((
  ref,
  id,
) {
  final roh = ref.watch(gefechtProvider(id));
  if (roh == null) return null;
  final patzer = ref.watch(gefechtPatzerProvider(id));
  final sperrt = gefechtPatzerSperrt(patzer, roh.runde);
  final s = roh.copyWith(
    patzerSperre: sperrt
        ? 'Patzer-/Bruchfolgen offen oder restliche Rundenaktionen verloren.'
        : null,
    ohnePatzerSperre: !sperrt,
    gesperrteKampfmittel: patzer.gesperrteMittel,
  );
  final gruppe = ref.watch(gefechtInitiativeProvider);
  if (!gruppe.helden.contains(id)) {
    return s.copyWith(gemeinsameInitiative: false, ohneInitiativSperre: true);
  }
  final initiativSperre = ref.watch(gefechtInitiativSperreProvider);
  final offen = ref.watch(gefechtsZeitpunkteProvider);
  final phase = gruppe.phase ?? offen.firstOrNull?.ini;
  final zweite =
      s.umwandlung == Gefechtsumwandlung.zweiteAttacke &&
      s.angriffeVerbraucht > 0;
  final key = '$id:${zweite ? "umgewandelt" : "regulaer"}';
  final reserve = offen
      .where((z) => z.ini == phase && z.reserve && z.teilnehmerId == id)
      .firstOrNull;
  final vorrang =
      reserve != null &&
      !offen.any(
        (z) =>
            z.ini == phase &&
            z.teilnehmerId != id &&
            z.ursprungsIni > reserve.ursprungsIni &&
            !z.umgewandelt,
      );
  return s.copyWith(
    gemeinsameInitiative: true,
    initiativSperre: initiativSperre,
    ohneInitiativSperre: initiativSperre == null,
    initiativphase: phase,
    ohneInitiativphase: phase == null,
    zeitpunktAbgeschlossen: gruppe.erledigt.contains(key),
    regulaerePhaseOffen: offen.any((z) => z.ini == phase && !z.umgewandelt),
    reserveHatVorrang: vorrang,
  );
});
