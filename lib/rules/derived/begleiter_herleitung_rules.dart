/// Wirksame Werte eines Begleiters als [Herleitung]en (ARCH-04, Paket D).
///
/// Dieselben Bausteine wie `begleiter_wirkwert_rules.dart`, nur als Schritte
/// angeordnet: Grundwert, gekaufte Steigerung, Reittier-Ausbildung und
/// Tierausbildung eines Vertrauten. Die Summen sind die wirksamen Werte, die
/// Kampfprofil und Begleiter-Tab verwenden.
library;

import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_wirkwert_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/companion_steigerung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vertrauten_ausbildung_rules.dart';

/// Schrittnamen, damit Tests und Anzeige nicht von Literalen abhängen.
const String kBegleiterSteigerungSchritt = 'Steigerung (AP)';
const String kBegleiterReittierSchritt = 'Reittier-Ausbildung';
const String kBegleiterTierausbildungSchritt = 'Tierausbildung';

/// Anzeigename und Schlüssel der hergeleiteten Eigenschaften und Kampfwerte.
const List<(String, String)> kBegleiterWerte = [
  ('MU', 'mu'),
  ('KL', 'kl'),
  ('IN', 'inn'),
  ('CH', 'ch'),
  ('FF', 'ff'),
  ('GE', 'ge'),
  ('KO', 'ko'),
  ('KK', 'kk'),
  ('INI', 'ini'),
  ('Loyalität', 'loyalitaet'),
];

/// Anzeigename und Schlüssel der Pools.
const List<(String, String)> kBegleiterPools = [
  ('LeP', 'lep'),
  ('AuP', 'aup'),
  ('AsP', 'asp'),
  ('MR', 'mr'),
];

/// AT und PA eines Angriffs des Begleiters.
class BegleiterAngriffHerleitung {
  /// Hält die Herleitungen; PA fehlt, wenn keine Parade möglich ist.
  const BegleiterAngriffHerleitung({
    required this.name,
    required this.at,
    required this.pa,
  });

  /// Anzeigename des Angriffs.
  final String name;

  /// Attacke; `null`, wenn der Angriff keine AT hat.
  final Herleitung? at;

  /// Parade; `null`, wenn keine Parade möglich ist.
  final Herleitung? pa;
}

/// Alle Herleitungen eines Begleiters.
class BegleiterHerleitungen {
  /// Hält Eigenschaften, Pools und Angriffe.
  const BegleiterHerleitungen({
    required this.id,
    required this.name,
    required this.werte,
    required this.pools,
    required this.angriffe,
  });

  /// Stabile Begleiter-ID.
  final String id;

  /// Anzeigename.
  final String name;

  /// Eigenschaften, INI und Loyalität nach Schlüssel (siehe [kBegleiterWerte]).
  final Map<String, Herleitung> werte;

  /// LeP, AuP, AsP und MR nach Schlüssel (siehe [kBegleiterPools]).
  final Map<String, Herleitung> pools;

  /// Angriffe in der Reihenfolge des Begleiters.
  final List<BegleiterAngriffHerleitung> angriffe;
}

HerleitungsSchritt _grund(String bezeichnung, int betrag, String quelle) =>
    HerleitungsSchritt(
      bezeichnung: bezeichnung,
      betrag: betrag,
      art: HerleitungsArt.grundwert,
      quelle: quelle,
    );

HerleitungsSchritt _steigerung(int betrag) => HerleitungsSchritt(
  bezeichnung: kBegleiterSteigerungSchritt,
  betrag: betrag,
  art: HerleitungsArt.zukauf,
);

HerleitungsSchritt _reittier(int betrag) => HerleitungsSchritt(
  bezeichnung: kBegleiterReittierSchritt,
  betrag: betrag,
  art: HerleitungsArt.modifikator,
  quelle: 'Ausbildung',
);

HerleitungsSchritt _tierausbildung(int betrag) => HerleitungsSchritt(
  bezeichnung: kBegleiterTierausbildungSchritt,
  betrag: betrag,
  art: HerleitungsArt.modifikator,
  quelle: 'Vertrauter',
);

/// Herleitung des Werts [schluessel] (Eigenschaft, INI, Loyalität); `null`,
/// wenn der Begleiter ihn nicht führt. Summe: `begleiterWirksamerWert`.
Herleitung? begleiterWertHerleitung(
  HeroCompanion c,
  String schluessel,
  String bezeichnung,
) {
  final basis = companionBasiswert(c, schluessel);
  if (basis == null) return null;
  final reittier = begleiterAusbildungsModifikationen(c);
  return Herleitung(
    bezeichnung: bezeichnung,
    schritte: [
      _grund('Grundwert', basis, 'Begleiter'),
      _steigerung(companionSteigerung(c, schluessel)),
      _reittier(switch (schluessel) {
        'kk' => reittier.kk,
        'loyalitaet' => reittier.lo,
        _ => 0,
      }),
      _tierausbildung(vertrautenAusbildungsModifikationen(c).wert(schluessel)),
    ],
  );
}

/// Herleitung eines Pools; `null` ohne Wert. Summe: `begleiterWirksamerPoolwert`.
Herleitung? begleiterPoolHerleitung(
  HeroCompanion c,
  String schluessel,
  String bezeichnung,
) {
  final start =
      companionPoolStartwert(c, schluessel) ??
      companionPoolBasiswert(c, schluessel);
  if (start == null) return null;
  return Herleitung(
    bezeichnung: bezeichnung,
    schritte: [
      _grund('Startwert', start, 'Begleiter'),
      _steigerung(companionSteigerung(c, schluessel)),
      _tierausbildung(vertrautenAusbildungsModifikationen(c).wert(schluessel)),
    ],
  );
}

/// Alle Herleitungen von [c].
BegleiterHerleitungen begleiterHerleitungen(HeroCompanion c) {
  final reittier = begleiterAusbildungsModifikationen(c);
  final vertraut = vertrautenAusbildungsModifikationen(c);
  final name = c.name.trim().isEmpty ? 'Unbenannter Begleiter' : c.name.trim();
  return BegleiterHerleitungen(
    id: c.id,
    name: name,
    werte: {
      for (final (label, key) in kBegleiterWerte)
        key: ?begleiterWertHerleitung(c, key, label),
    },
    pools: {
      for (final (label, key) in kBegleiterPools)
        key: ?begleiterPoolHerleitung(c, key, label),
    },
    angriffe: [
      for (final a in c.angriffe)
        BegleiterAngriffHerleitung(
          name: a.name.trim().isEmpty ? 'Angriff' : a.name.trim(),
          at: a.at == null
              ? null
              : Herleitung(
                  bezeichnung: 'AT',
                  schritte: [
                    _grund('Grundwert', a.at!, 'Angriff'),
                    _steigerung(a.steigerungAt),
                    _reittier(reittier.at),
                    _tierausbildung(vertraut.at),
                  ],
                ),
          pa: a.pa == null
              ? null
              : Herleitung(
                  bezeichnung: 'PA',
                  schritte: [
                    _grund('Grundwert', a.pa!, 'Angriff'),
                    _steigerung(a.steigerungPa),
                    _tierausbildung(vertraut.pa),
                  ],
                ),
        ),
    ],
  );
}
