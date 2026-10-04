import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_angriff_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_laden_rules_test.dart' as fixture;
import '../ui2/shell/karto_test_support.dart';

// Ungleiche, nichtnullige Distanzanteile entlarven die bisher verdeckte Vorschauübernahme.
HeroComputedSnapshot _snapshot(
  bool neben, {
  bool unbekannt = false,
  int preview = 0,
}) {
  final basis = fixture.ladeSnapshot(nebenhand: neben);
  final waffen = basis.hero.combatConfig.weaponSlots.map((w) {
    if (!w.isRanged) return w;
    return w.copyWith(
      talentId: 'tal_armbrust',
      tpFlat: 4,
      rangedProfile: w.rangedProfile.copyWith(
        selectedDistanceIndex: preview,
        projectiles: const [
          RangedProjectile(id: 'p1', name: 'Bolzen', count: 5, tpMod: 3),
        ],
        distanceBands: [
          RangedDistanceBand(label: unbekannt ? 'Unbekannt' : '5', tpMod: 7),
          const RangedDistanceBand(label: '10', tpMod: 2),
          const RangedDistanceBand(label: '20', tpMod: -1),
          const RangedDistanceBand(label: '40', tpMod: -3),
          const RangedDistanceBand(label: '80', tpMod: -5),
        ],
      ),
    );
  }).toList();
  return buildHeroComputedSnapshot(
    hero: basis.hero.copyWith(
      talents: {'tal_armbrust': const HeroTalentEntry(talentValue: 16)},
      combatConfig: basis.hero.combatConfig.copyWith(weapons: waffen),
    ),
    state: const HeroState.empty(),
    catalog: testCatalog,
    epicAdvantagesActive: false,
  );
}

void main() {
  for (final neben in [false, true]) {
    for (final unbekannt in [false, true]) {
      test(
        'I3 Hand=$neben unbekannt=$unbekannt bindet echte Entfernung statt Vorschau',
        () {
          final snap = _snapshot(neben, unbekannt: unbekannt);
          final wahl = GefechtsKampfmittelwahl(
            neben
                ? GefechtsKampfmittelArt.nebenwaffe
                : GefechtsKampfmittelArt.hauptwaffe,
            'a',
          );
          final a = GefechtAuftrag(
            aktion: Gefechtsaktion.angriff,
            titel: 'FK',
            zuschlag: 0,
            dk: null,
            dauer: 1,
            kosten: 1,
            fernkampfansage: 4,
            zielwert: unbekannt ? 20 : null,
            kampfmittel: wahl,
            kontext: const Gefechtskontext(
              kontakt: 'Ork',
              geladen: true,
              entfernung: 60,
              situationsZuschlag: 0,
            ),
          );
          Gefechtspruefung p;
          if (unbekannt) {
            // Schutz im Ergebnisbinder, auch wenn ein Aufrufer bereits eine Buchung meldet.
            p = Gefechtspruefung(
              aktion: Gefechtsaktion.angriff,
              status: Gefechtsfreigabe.bereit,
              kampfmittel: wahl,
              gruende: const [],
              zielwert: 20,
            );
          } else {
            var s = beginneGefechtsZielen(
              const Gefechtszustand(iniWurf: 6),
              snap,
              testCatalog,
              a,
            );
            s = bezahleGefechtsVorbereitung(s, snap);
            s = naechsteGefechtsrunde(s).copyWith(ohneHandlung: true);
            p = pruefeGefechtAuftrag(s, snap, testCatalog, a);
            expect(p.ausfuehrbar, true, reason: p.gruende.join('; '));
          }
          final e = gefechtsAngriffsergebnisNachBuchung(
            auftragId: 'shot',
            buchungErfolgreich: true,
            erfolg: true,
            snapshot: snap,
            katalog: testCatalog,
            auftrag: a,
            pruefung: p,
          )!;
          expect(e.tpBonus, 2);
          if (unbekannt) {
            expect(e.schadensfolge, GefechtsSchadensfolge.manuell);
            expect(gefechtsSchadenFuerAngriff(e), isNull);
            expect(e.hinweis, contains('Entfernung'));
          } else {
            final vorher = neben
                ? snap.combatPreviewStats.offhandPreview!.damageDiceSpec!
                : snap.combatPreviewStats.damageDiceSpec;
            final request = gefechtsSchadenFuerAngriff(e)!;
            expect(request.diceSpec.modifier, vorher.modifier - 7 - 5 + 2);
            expect(request.diceSpec.count, vorher.count);
            expect(request.diceSpec.sides, vorher.sides);
            final neu = _snapshot(neben, preview: 1);
            final allgemein = neben
                ? neu.combatPreviewStats.offhandPreview!.damageDiceSpec!
                : neu.combatPreviewStats.damageDiceSpec;
            expect(allgemein.modifier, vorher.modifier - 7 + 2);
            expect(
              gefechtsSchadenFuerAngriff(e)!.diceSpec.modifier,
              request.diceSpec.modifier,
            );
            expect(e.kampfmittel.id, wahl.id);
            expect(e.kampfmittel.art, wahl.art);
          }
        },
      );
    }
  }
}
