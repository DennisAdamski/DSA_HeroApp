/// Ausbildungskatalog für Pferde und andere Reittiere (ZBA S. 32–40).
///
/// Die Konstanten sind die Quelle; `assets/catalogs/house_rules_v1/
/// reittier_ausbildung.json` ist ihr per Test geprüfter Spiegel (Muster wie
/// `vertrautenmagie_preset.dart`). Texte sind kurze Zusammenfassungen, keine
/// Buchzitate. Gespeicherte Helden verweisen nur über die stabilen IDs
/// (`pvar_…`, `psf_…`, `punart_…`) auf diesen Katalog.
library;

import 'package:dsa_heldenverwaltung/catalog/pferde_sf_katalog.dart';
import 'package:dsa_heldenverwaltung/catalog/reittier_ausbildung_typen.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/reittier_ausbildungsstufe.dart';

export 'package:dsa_heldenverwaltung/catalog/pferde_sf_katalog.dart';
export 'package:dsa_heldenverwaltung/catalog/reittier_ausbildung_typen.dart';

/// Erzeugt die Probenliste eines fundierten Schritts: je [anzahl] Proben auf
/// Abrichten, Tierkunde und Reiten (Zugtiere: Fahrzeug Lenken).
List<ReittierProbeDef> _fundierteProben(int anzahl, int erschwernis) =>
    <ReittierProbeDef>[
      ReittierProbeDef(
        talentId: 'tal_abrichten',
        talentName: 'Abrichten',
        anzahl: anzahl,
        erschwernis: erschwernis,
      ),
      ReittierProbeDef(
        talentId: 'tal_tierkunde',
        talentName: 'Tierkunde',
        anzahl: anzahl,
        erschwernis: erschwernis,
      ),
      ReittierProbeDef(
        talentId: 'tal_reiten',
        talentName: 'Reiten',
        anzahl: anzahl,
        erschwernis: erschwernis,
        alternativeTalentId: 'tal_fahrzeug_lenken',
        alternativeTalentName: 'Fahrzeug Lenken',
      ),
    ];

/// Alle Ausbildungsschritte (ZBA S. 34 f.).
final List<ReittierStufenschrittDef> kReittierStufenschritte =
    List<ReittierStufenschrittDef>.unmodifiable(<ReittierStufenschrittDef>[
      const ReittierStufenschrittDef(
        von: ReittierAusbildungsstufe.ungearbeitet,
        nach: ReittierAusbildungsstufe.unerfahren,
        art: ReittierAusbildungsart.laendlich,
        proben: <ReittierProbeDef>[
          ReittierProbeDef(
            talentId: 'tal_reiten',
            talentName: 'Reiten',
            anzahl: 1,
            erschwernis: 3,
            alternativeTalentId: 'tal_fahrzeug_lenken',
            alternativeTalentName: 'Fahrzeug Lenken',
          ),
        ],
        hinweis:
            'Einreiten über zwei bis drei Arbeitseinsätze, je Einsatz eine '
            'Probe. Jede misslungene Probe bringt eine Unart nach Meisterwahl.',
      ),
      ReittierStufenschrittDef(
        von: ReittierAusbildungsstufe.ungearbeitet,
        nach: ReittierAusbildungsstufe.unerfahren,
        art: ReittierAusbildungsart.fundiert,
        modifikationen: const ReittierModifikationen(lo: 2, kk: 1),
        proben: _fundierteProben(3, 0),
        hinweis:
            'Drei bis sechs Monate beim Zureiter. Je drei misslungene Proben '
            'bringen eine Unart nach Meisterwahl.',
      ),
      const ReittierStufenschrittDef(
        von: ReittierAusbildungsstufe.unerfahren,
        nach: ReittierAusbildungsstufe.erprobt,
        art: ReittierAusbildungsart.laendlich,
        modifikationen: ReittierModifikationen(
          lo: 4,
          kk: 3,
          auTrab: 2,
          auGalopp: 1,
        ),
        hinweis:
            'Etwa ein Jahr tägliche Arbeit, Proben entfallen. Nach fundiertem '
            'Beginn nur die halben Modifikationen, danach keine Schulung mehr.',
      ),
      ReittierStufenschrittDef(
        von: ReittierAusbildungsstufe.unerfahren,
        nach: ReittierAusbildungsstufe.erprobt,
        art: ReittierAusbildungsart.fundiert,
        modifikationen: const ReittierModifikationen(lo: 2, kk: 2, auTrab: 1),
        proben: _fundierteProben(2, 3),
        hinweis:
            'Anderthalb bis zwei Jahre Aufbauarbeit. Je drei misslungene '
            'Proben bringen eine Unart nach Meisterwahl.',
      ),
      ReittierStufenschrittDef(
        von: ReittierAusbildungsstufe.erprobt,
        nach: ReittierAusbildungsstufe.geschult,
        art: ReittierAusbildungsart.fundiert,
        modifikationen: const ReittierModifikationen(lo: 3),
        proben: _fundierteProben(2, 5),
        hinweis:
            'Schulung in einer Ausbildungsvariante; deren Modifikationen und '
            'Sonderfertigkeiten kommen hinzu. Ländlich erprobte Tiere: Proben '
            'um bis zu 5 zusätzlich erschwert.',
      ),
    ]);

/// Reiten-Modifikatoren je Stufe (ZBA S. 35); positiv heißt erschwert.
const List<ReittierReitenModifikatorDef> kReittierReitenModifikatoren =
    <ReittierReitenModifikatorDef>[
      ReittierReitenModifikatorDef(
        stufe: ReittierAusbildungsstufe.ungearbeitet,
        normal: 3,
        imKampf: 6,
        imKampfAlsKampfpferd: 6,
      ),
      ReittierReitenModifikatorDef(
        stufe: ReittierAusbildungsstufe.unerfahren,
        normal: 1,
        imKampf: 3,
        imKampfAlsKampfpferd: 3,
      ),
      ReittierReitenModifikatorDef(
        stufe: ReittierAusbildungsstufe.erprobt,
        normal: -1,
        imKampf: 0,
        imKampfAlsKampfpferd: 0,
      ),
      ReittierReitenModifikatorDef(
        stufe: ReittierAusbildungsstufe.geschult,
        normal: -2,
        imKampf: -1,
        imKampfAlsKampfpferd: -3,
      ),
    ];

/// Zusatzerschwernis der Reiten-Probe im Kampf auf ländlich ausgebildeten
/// Tieren (beidhändige Reitweise, ZBA S. 35).
const int kReittierLaendlichReitenImKampf = 3;

/// Zusatzerschwernis der Kampfhandlungen des Reiters auf ländlich
/// ausgebildeten Tieren (ZBA S. 35).
const int kReittierLaendlichKampfhandlungen = 3;

/// Zusatzerschwernis von AT, PA und Ausweichen auf ungearbeiteten Tieren,
/// weil beide Hände am Zügel sind (ZBA S. 35).
const int kReittierUngearbeitetKampfhandlungen = 3;

/// Erleichterung der Reiten-Probe auf einem Magierpferd für Viertel-, Halb-
/// und Vollzauberer (ZBA S. 35).
const int kMagierpferdZaubererErleichterung = 1;

/// Alle Ausbildungsvarianten der fundierten Schulung (ZBA S. 32).
const List<ReittierAusbildungsvarianteDef>
kReittierVarianten = <ReittierAusbildungsvarianteDef>[
  ReittierAusbildungsvarianteDef(
    id: 'pvar_adelsross',
    name: 'Adelsross',
    kategorie: ReittierVariantenKategorie.schaupferd,
    sfIds: <String>[
      'psf_almadaner_schritt',
      'psf_capriola',
      'psf_corbetto',
      'psf_galoppwechsel',
      'psf_kreisel',
      'psf_passage',
      'psf_piaffe',
      'psf_seitengaenge',
      'psf_steigen',
      'psf_weiches_gangwerk',
    ],
    hinweis: 'Capriola nicht für zu schwere Rassen.',
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_botenpferd',
    name: 'Botenpferd',
    kategorie: ReittierVariantenKategorie.reitpferd,
    modifikationen: ReittierModifikationen(
      gsTrab: 2,
      gsGalopp: 1,
      auTrab: 3,
      auGalopp: 2,
    ),
    sfIds: <String>[
      'psf_schrecksicher',
      'psf_gelaendehindernisse',
      'psf_sprungsicherheit',
    ],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_huetepferd',
    name: 'Hütepferd',
    kategorie: ReittierVariantenKategorie.reitpferd,
    modifikationen: ReittierModifikationen(gsGalopp: 1),
    sfIds: <String>[
      'psf_separieren',
      'psf_stopp',
      'psf_galoppwechsel',
      'psf_steigen',
      'psf_stillstand',
      'psf_kehrtwende',
    ],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_lasttragtier',
    name: 'Lasttragtier',
    kategorie: ReittierVariantenKategorie.lasttier,
    modifikationen: ReittierModifikationen(kk: 1, tkFaktor: 1),
    sfIds: <String>[
      'psf_gelaendehindernisse',
      'psf_schrecksicher',
      'psf_kommen_auf_signal',
    ],
    hinweis: 'Erhält zusätzlich den Vorteil Trittsicherheit (Geländeart).',
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_leichtes_streitross',
    name: 'Leichtes Streitross',
    kategorie: ReittierVariantenKategorie.schlachtross,
    kampfpferd: true,
    modifikationen: ReittierModifikationen(lo: 1, at: 1, tpTritt: 1),
    sfIds: <String>[
      'psf_lanzengang',
      'psf_kreisel',
      'psf_steigen',
      'psf_corbetto',
      'psf_stopp',
      'psf_kehrtwende',
      'psf_capriola',
      'psf_gezielter_biss',
      'psf_gezielter_tritt',
      'psf_sprungsicherheit',
    ],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_linienkutschpferd',
    name: 'Linienkutschpferd',
    kategorie: ReittierVariantenKategorie.zugpferd,
    modifikationen: ReittierModifikationen(
      gsTrab: 2,
      gsGalopp: 1,
      auTrab: 3,
      auGalopp: 2,
    ),
    sfIds: <String>[
      'psf_eingefahren',
      'psf_mehrspaennig',
      'psf_schrecksicher',
      'psf_gelaendehindernisse',
    ],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_magierpferd',
    name: 'Magierpferd',
    kategorie: ReittierVariantenKategorie.magierpferd,
    sfIds: <String>[
      'psf_weiches_gangwerk',
      'psf_stopp',
      'psf_kehrtwende',
      'psf_lenken_ohne_zuegel',
      'psf_seitengaenge',
      'psf_stillstand',
      'psf_schrecksicher',
    ],
    hinweis:
        'Nur Tulamiden, Firn- oder Paaviponys mit Magiegespür. Reiten −1 '
        'für Viertel-, Halb- und Vollzauberer.',
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_mittelschweres_streitross',
    name: 'Mittelschweres Streitross',
    kategorie: ReittierVariantenKategorie.schlachtross,
    kampfpferd: true,
    modifikationen: ReittierModifikationen(lo: 1, at: 1, tpTritt: 2),
    sfIds: <String>[
      'psf_lanzengang',
      'psf_kreisel',
      'psf_steigen',
      'psf_corbetto',
      'psf_stopp',
      'psf_kehrtwende',
      'psf_gezielter_biss',
      'psf_gezielter_tritt',
      'psf_capriola',
    ],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_novadisches_kriegspferd',
    name: 'Novadisches Kriegspferd',
    kategorie: ReittierVariantenKategorie.schlachtross,
    kampfpferd: true,
    modifikationen: ReittierModifikationen(
      lo: 5,
      at: 1,
      gsTrab: 1,
      gsGalopp: 1,
      auTrab: 2,
      auGalopp: 2,
    ),
    sfIds: <String>[
      'psf_kommen_auf_signal',
      'psf_lanzengang',
      'psf_stopp',
      'psf_kehrtwende',
      'psf_steigen',
      'psf_kreisel',
      'psf_hinlegen',
      'psf_reitertreue',
      'psf_gezielter_biss',
      'psf_gezielter_tritt',
      'psf_wacht',
      'psf_rastullahs_schwingen',
      'psf_stille_wacht',
    ],
    hinweis:
        'Wie das tulamidische Kriegspferd, zusätzlich LO +3, Rastullahs '
        'Schwingen und Stille Wacht. Fast nur bei Novadis.',
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_prunkkutschpferd',
    name: 'Prunkkutschpferd',
    kategorie: ReittierVariantenKategorie.zugpferd,
    sfIds: <String>[
      'psf_eingefahren',
      'psf_gespanngewoehnung',
      'psf_mehrspaennig',
      'psf_passage',
      'psf_almadaner_schritt',
    ],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_rennkutschpferd',
    name: 'Rennkutschpferd',
    kategorie: ReittierVariantenKategorie.zugpferd,
    modifikationen: ReittierModifikationen(gsGalopp: 3, auGalopp: 1),
    sfIds: <String>[
      'psf_eingefahren',
      'psf_gespanngewoehnung',
      'psf_mehrspaennig',
    ],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_rennpferd_renner',
    name: 'Rennpferd (Renner)',
    kategorie: ReittierVariantenKategorie.rennpferd,
    modifikationen: ReittierModifikationen(
      gsTrab: 3,
      gsGalopp: 4,
      auTrab: 2,
      auGalopp: 2,
    ),
    hinweis: 'Für Kurzstreckenrennen.',
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_rennpferd_steher',
    name: 'Rennpferd (Steher)',
    kategorie: ReittierVariantenKategorie.rennpferd,
    modifikationen: ReittierModifikationen(
      gsTrab: 1,
      gsGalopp: 2,
      auTrab: 4,
      auGalopp: 4,
    ),
    hinweis: 'Für Langstreckenrennen.',
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_schuetzenpferd',
    name: 'Schützenpferd',
    kategorie: ReittierVariantenKategorie.reitpferd,
    kampfpferd: true,
    sfIds: <String>[
      'psf_weiches_gangwerk',
      'psf_stopp',
      'psf_kehrtwende',
      'psf_lenken_ohne_zuegel',
      'psf_seitengaenge',
      'psf_stillstand',
    ],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_schweres_streitross',
    name: 'Schweres Streitross',
    kategorie: ReittierVariantenKategorie.schlachtross,
    kampfpferd: true,
    modifikationen: ReittierModifikationen(lo: 2, at: 1, tpTritt: 3),
    sfIds: <String>[
      'psf_kommen_auf_signal',
      'psf_lanzengang',
      'psf_wacht',
      'psf_steigen',
      'psf_gezielter_tritt',
      'psf_gezielter_biss',
      'psf_corbetto',
      'psf_kreisel',
      'psf_trampeln',
      'psf_reitertreue',
    ],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_streitwagenpferd',
    name: 'Streitwagenpferd',
    kategorie: ReittierVariantenKategorie.zugpferd,
    kampfpferd: true,
    modifikationen: ReittierModifikationen(
      gsTrab: 1,
      gsGalopp: 1,
      auTrab: 1,
      auGalopp: 1,
    ),
    sfIds: <String>['psf_eingefahren', 'psf_mehrspaennig', 'psf_schrecksicher'],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_trosskutschpferd',
    name: 'Trosskutschpferd',
    kategorie: ReittierVariantenKategorie.zugpferd,
    modifikationen: ReittierModifikationen(kk: 2, zkFaktor: 2),
    sfIds: <String>['psf_eingefahren', 'psf_mehrspaennig', 'psf_schrecksicher'],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_tulamidisches_kriegspferd',
    name: 'Tulamidisches Kriegspferd',
    kategorie: ReittierVariantenKategorie.schlachtross,
    kampfpferd: true,
    modifikationen: ReittierModifikationen(
      lo: 2,
      at: 1,
      gsTrab: 1,
      gsGalopp: 1,
      auTrab: 2,
      auGalopp: 2,
    ),
    sfIds: <String>[
      'psf_kommen_auf_signal',
      'psf_lanzengang',
      'psf_stopp',
      'psf_kehrtwende',
      'psf_steigen',
      'psf_kreisel',
      'psf_hinlegen',
      'psf_reitertreue',
      'psf_gezielter_biss',
      'psf_gezielter_tritt',
      'psf_wacht',
    ],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_wanderreitpferd',
    name: 'Wanderreitpferd',
    kategorie: ReittierVariantenKategorie.reitpferd,
    modifikationen: ReittierModifikationen(auTrab: 1),
    sfIds: <String>[
      'psf_gelaendehindernisse',
      'psf_schrecksicher',
      'psf_sprungsicherheit',
      'psf_eingefahren',
    ],
  ),
  ReittierAusbildungsvarianteDef(
    id: 'pvar_zirkuspferd',
    name: 'Zirkuspferd',
    kategorie: ReittierVariantenKategorie.schaupferd,
    sfIds: <String>[
      'psf_schrecksicher',
      'psf_hinlegen',
      'psf_kniefall',
      'psf_sprungsicherheit',
      'psf_steigen',
      'psf_zaehlen',
      'psf_eingefahren',
    ],
  ),
];

/// Ausbildungsvariante zu [id]; `null` für unbekannte IDs.
ReittierAusbildungsvarianteDef? reittierVariante(String id) {
  for (final variante in kReittierVarianten) {
    if (variante.id == id) {
      return variante;
    }
  }
  return null;
}

/// Gesamter Katalog als JSON, wie ihn der Spiegel unter `assets/` enthält.
Map<String, dynamic> reittierAusbildungsKatalogJson() => <String, dynamic>{
  'quelle': 'Zoo-Botanica Aventurica S. 32–40',
  'stufenschritte': kReittierStufenschritte
      .map((s) => s.toJson())
      .toList(growable: false),
  'reitenModifikatoren': kReittierReitenModifikatoren
      .map((m) => m.toJson())
      .toList(growable: false),
  'varianten': kReittierVarianten
      .map((v) => v.toJson())
      .toList(growable: false),
  'sonderfertigkeiten': kPferdeSonderfertigkeiten
      .map((sf) => sf.toJson())
      .toList(growable: false),
  'unarten': kPferdeUnarten.map((u) => u.toJson()).toList(growable: false),
};
