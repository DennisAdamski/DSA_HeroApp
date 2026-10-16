/// Wer ein Talent einsetzen darf und worauf er ausweichen kann.
///
/// Quelle: Wege des Schwerts S. 16 f. (Basis- und Spezial-Talente) und die
/// Zeile „Ersatzweise verwendbare Fertigkeiten“ jedes Talents (S. 18–40),
/// Basisregelwerk S. 113 („Ableiten auf verwandte Fertigkeit“). Die Tabelle
/// ergänzt die Katalogeinträge in `talente.json`, ohne sie anzufassen; ein
/// Test gleicht sie mit dem echten Katalog ab.
///
/// * **Basis-Talente** darf jeder Held proben, auch mit TaW 0 oder negativem
///   TaW und ohne Eintrag auf dem Bogen.
/// * **Spezial-Talente** darf nur proben, wer sie aktiviert hat (TaW
///   mindestens 0); andernfalls bleibt nur das Ausweichen auf ein verwandtes
///   Talent.
/// * Beim Ausweichen sinkt der TaW des Ersatztalents um den **Zuschlag**; die
///   Probe läuft auf dessen Eigenschaften. Die Zuschläge sind Richtwerte des
///   Buchs, der Meister legt sie fest. Gaben sind weder Basis- noch
///   Spezial-Talente und stehen ohne Ersatz in der Tabelle.
library;

/// Ein Talent, auf das ausgewichen werden darf.
class TalentErsatzDef {
  /// Verweist auf das Ersatztalent [talentId] mit dem Richtwert [zuschlag].
  const TalentErsatzDef(this.talentId, this.zuschlag, {this.bedingung});

  /// Katalog-ID des Ersatztalents.
  final String talentId;

  /// Abzug vom TaW des Ersatztalents; `null`, wenn das Buch keinen Wert
  /// nennt und der Meister ihn bestimmt.
  final int? zuschlag;

  /// Einschränkung, etwa „nur mit der Spezialisierung Bauchreden“.
  final String? bedingung;
}

/// Nutzungsregel eines Talents.
class TalentNutzungDef {
  /// Basis-Talent ([basis]) mit den möglichen Ausweichtalenten [ersatz].
  const TalentNutzungDef({required this.basis, this.ersatz = const []});

  /// Jeder Held darf darauf proben.
  final bool basis;

  /// Talente, auf die der Meister ausweichen lassen kann.
  final List<TalentErsatzDef> ersatz;
}

/// Empfohlener Mindestzuschlag, wenn der Meister statt einer Talentprobe
/// eine Eigenschaftsprobe verlangt (Basisregelwerk S. 113).
const int kEigenschaftsprobeErsatzZuschlag = 7;

/// Nutzungsregel des Talents [talentId]; `null` für unbekannte Talente
/// (etwa eigene Katalogeinträge).
TalentNutzungDef? talentNutzungFuer(String talentId) =>
    kTalentNutzung[talentId];

/// Nutzungsregeln aller Nicht-Kampf-Talente des Basiskatalogs, nach Talent-ID.
const Map<String, TalentNutzungDef> kTalentNutzung = <String, TalentNutzungDef>{
  'tal_empathie': TalentNutzungDef(basis: false),
  'tal_gefahreninstinkt': TalentNutzungDef(basis: false),
  'tal_geraeuschhexerei': TalentNutzungDef(basis: false),
  'tal_kraefteschub': TalentNutzungDef(basis: false),
  'tal_talentschub': TalentNutzungDef(basis: false),
  'tal_magiegespuer': TalentNutzungDef(basis: false),
  'tal_prophezeien': TalentNutzungDef(basis: false),
  'tal_tierempathie': TalentNutzungDef(basis: false),
  'tal_zwergennase': TalentNutzungDef(basis: false),
  'tal_athletik': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_koerperbeherrschung', 5),
      TalentErsatzDef('tal_akrobatik', 10),
    ],
  ),
  'tal_klettern': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_akrobatik', 5),
      TalentErsatzDef('tal_athletik', 5),
      TalentErsatzDef('tal_koerperbeherrschung', 10),
    ],
  ),
  'tal_koerperbeherrschung': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_akrobatik', 5),
      TalentErsatzDef('tal_athletik', 10),
    ],
  ),
  'tal_schleichen': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_koerperbeherrschung', 10),
      TalentErsatzDef('tal_sich_verstecken', 10),
    ],
  ),
  'tal_schwimmen': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_athletik', 10)],
  ),
  'tal_selbstbeherrschung': TalentNutzungDef(basis: true),
  'tal_sich_verstecken': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_schleichen', 10),
      TalentErsatzDef('tal_koerperbeherrschung', 15),
    ],
  ),
  'tal_singen': TalentNutzungDef(basis: true),
  'tal_sinnesschaerfe': TalentNutzungDef(basis: true),
  'tal_tanzen': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_akrobatik', 5),
      TalentErsatzDef('tal_koerperbeherrschung', 5),
    ],
  ),
  'tal_zechen': TalentNutzungDef(basis: true),
  'tal_akrobatik': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_koerperbeherrschung', 5),
      TalentErsatzDef('tal_athletik', 10),
    ],
  ),
  'tal_fliegen': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_akrobatik', 10)],
  ),
  'tal_gaukeleien': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_falschspiel', 10),
      TalentErsatzDef('tal_taschendiebstahl', 10),
    ],
  ),
  'tal_reiten': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_koerperbeherrschung', 10),
      TalentErsatzDef('tal_akrobatik', 15),
    ],
  ),
  'tal_skifahren': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_athletik', 10),
      TalentErsatzDef('tal_koerperbeherrschung', 15),
    ],
  ),
  'tal_stimmen_imitieren': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_gaukeleien',
        5,
        bedingung: 'nur mit der Spezialisierung Bauchreden',
      ),
    ],
  ),
  'tal_taschendiebstahl': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_gaukeleien',
        10,
        bedingung: 'nur mit der Spezialisierung Taschenspielereien',
      ),
    ],
  ),
  'tal_goetter_kulte': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_geschichtswissen', 10, bedingung: 'eventuell'),
      TalentErsatzDef('tal_sagen_legenden', 10, bedingung: 'eventuell'),
    ],
  ),
  'tal_rechnen': TalentNutzungDef(basis: true),
  'tal_sagen_legenden': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_geschichtswissen',
        10,
        bedingung: 'je nach Spezialthema, eventuell',
      ),
      TalentErsatzDef(
        'tal_goetter_kulte',
        10,
        bedingung: 'je nach Spezialthema, eventuell',
      ),
    ],
  ),
  'tal_anatomie': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_heilkunde_wunden', 5),
      TalentErsatzDef('tal_heilkunde_krankheiten', 10),
    ],
  ),
  'tal_baukunst': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_zimmermann', 10),
      TalentErsatzDef('tal_maurer', 10),
      TalentErsatzDef('tal_steinmetz', 10),
    ],
  ),
  'tal_brett_kartenspiel': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_kriegskunst',
        10,
        bedingung: 'unter Umständen, bei Strategie',
      ),
      TalentErsatzDef('tal_rechnen', 10, bedingung: 'unter Umständen'),
    ],
  ),
  'tal_geographie': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_sagen_legenden', 10)],
  ),
  'tal_geschichtswissen': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_sagen_legenden', 10, bedingung: 'je nach Thema'),
    ],
  ),
  'tal_gesteinskunde': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_steinmetz',
        5,
        bedingung: 'je nach Gestein und Umständen',
      ),
      TalentErsatzDef(
        'tal_bergbau',
        10,
        bedingung: 'je nach Gestein und Umständen',
      ),
      TalentErsatzDef(
        'tal_baukunst',
        10,
        bedingung: 'je nach Gestein und Umständen',
      ),
      TalentErsatzDef(
        'tal_steinschneider_juwelier',
        10,
        bedingung: 'je nach Gestein und Umständen',
      ),
      TalentErsatzDef(
        'tal_huettenkunde',
        10,
        bedingung: 'je nach Gestein und Umständen',
      ),
    ],
  ),
  'tal_heraldik': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_etikette', 10)],
  ),
  'tal_huettenkunde': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_alchemie', 10),
      TalentErsatzDef('tal_metallguss', 10),
      TalentErsatzDef('tal_grobschmied', 15),
    ],
  ),
  'tal_kriegskunst': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_brett_kartenspiel',
        10,
        bedingung: 'bei strategischen Entscheidungen, bisweilen',
      ),
      TalentErsatzDef(
        'tal_rechnen',
        null,
        bedingung: 'in bestimmten Situationen, Zuschlag vom Meister',
      ),
      TalentErsatzDef(
        'tal_menschenkenntnis',
        null,
        bedingung: 'in bestimmten Situationen, Zuschlag vom Meister',
      ),
      TalentErsatzDef(
        'tal_tierkunde',
        null,
        bedingung: 'beim Kampf gegen Monstren, Zuschlag vom Meister',
      ),
    ],
  ),
  'tal_kryptographie': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_rechnen', 10),
      TalentErsatzDef('tal_sprachenkunde', 10),
    ],
  ),
  'tal_magiekunde': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_sagen_legenden',
        10,
        bedingung:
            'in den Bereichen Dämonologie, Elementarismus und Zauberpraxis',
      ),
      TalentErsatzDef(
        'tal_goetter_kulte',
        10,
        bedingung: 'im Bereich Sphärologie',
      ),
    ],
  ),
  'tal_mechanik': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_feinmechanik', 10)],
  ),
  'tal_pflanzenkunde': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_wildnisleben', 10)],
  ),
  'tal_philosophie': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_goetter_kulte', 10),
      TalentErsatzDef('tal_magiekunde', 10),
      TalentErsatzDef('tal_geschichtswissen', 15),
      TalentErsatzDef('tal_sagen_legenden', 15),
    ],
  ),
  'tal_rechtskunde': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_etikette', 10),
      TalentErsatzDef('tal_staatskunst', 10),
    ],
  ),
  'tal_schaetzen': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_feinmechanik',
        5,
        bedingung: 'nur mit der Spezialisierung Goldschmied',
      ),
      TalentErsatzDef('tal_handel', 5),
      TalentErsatzDef('tal_steinschneider_juwelier', 5),
    ],
  ),
  'tal_sprachenkunde': TalentNutzungDef(basis: false),
  'tal_staatskunst': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_hauswirtschaft', 10),
      TalentErsatzDef('tal_rechtskunde', 10, bedingung: 'Staatsrecht'),
    ],
  ),
  'tal_sternkunde': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_prophezeien', 5, bedingung: 'Gabe, Astrologie'),
    ],
  ),
  'tal_tierkunde': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_reiten', 10, bedingung: 'je nach Wesen'),
      TalentErsatzDef('tal_viehzucht', 10, bedingung: 'je nach Wesen'),
      TalentErsatzDef('tal_wildnisleben', 10, bedingung: 'je nach Wesen'),
    ],
  ),
  'tal_menschenkenntnis': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_heilkunde_seele', 5)],
  ),
  'tal_ueberreden': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_ueberzeugen', 10)],
  ),
  'tal_betoeren': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_ueberreden', 10, bedingung: 'je nach Situation'),
      TalentErsatzDef('tal_ueberzeugen', 10, bedingung: 'je nach Situation'),
    ],
  ),
  'tal_etikette': TalentNutzungDef(basis: false),
  'tal_gassenwissen': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_menschenkenntnis', 10)],
  ),
  'tal_lehren': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_ueberzeugen', 10)],
  ),
  'tal_schauspielerei': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_ueberreden', 10)],
  ),
  'tal_schriftlicher_ausdruck': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_ueberzeugen',
        5,
        bedingung: 'nur mit der Spezialisierung schriftliche Rhetorik',
      ),
    ],
  ),
  'tal_sich_verkleiden': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_schauspielerei', 10)],
  ),
  'tal_ueberzeugen': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_ueberreden', 10)],
  ),
  'tal_faehrtensuchen': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_sinnesschaerfe', 10)],
  ),
  'tal_orientierung': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_sternkunde', 10)],
  ),
  'tal_wildnisleben': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_tierkunde', 10, bedingung: 'je nach Situation'),
      TalentErsatzDef('tal_pflanzenkunde', 10, bedingung: 'je nach Situation'),
    ],
  ),
  'tal_fallenstellen': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_wildnisleben', 10)],
  ),
  'tal_fesseln_entfesseln': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_seefahrt', 10),
      TalentErsatzDef('tal_seiler', 10),
      TalentErsatzDef(
        'tal_akrobatik',
        5,
        bedingung: 'zum Entfesseln, nur mit der Spezialisierung Winden',
      ),
      TalentErsatzDef(
        'tal_gaukeleien',
        10,
        bedingung: 'zum Entfesseln, nur bei passender Spezialisierung',
      ),
      TalentErsatzDef('tal_taschendiebstahl', 10, bedingung: 'zum Entfesseln'),
    ],
  ),
  'tal_fischen_angeln': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_wildnisleben', 10)],
  ),
  'tal_wettervorhersage': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_wildnisleben', 10)],
  ),
  'tal_heilkunde_wunden': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_anatomie', 10)],
  ),
  'tal_holzbearbeitung': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_zimmermann', 5)],
  ),
  'tal_kochen': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_alchemie',
        10,
        bedingung: 'eventuell, wenn Kochen (Tränke) gefordert',
      ),
      TalentErsatzDef('tal_fleischer', 10),
      TalentErsatzDef('tal_fischen_angeln', 10),
      TalentErsatzDef('tal_wildnisleben', 10),
    ],
  ),
  'tal_lederarbeiten': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_gerber_kuerschner', 10),
      TalentErsatzDef('tal_schneidern', 10),
    ],
  ),
  'tal_malen_zeichnen': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_kartographie', 10, bedingung: 'teilweise'),
      TalentErsatzDef('tal_steinmetz', 10, bedingung: 'teilweise, Bildhauer'),
      TalentErsatzDef('tal_taetowieren', 5, bedingung: 'teilweise'),
    ],
  ),
  'tal_schneidern': TalentNutzungDef(
    basis: true,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_lederarbeiten', 10),
      TalentErsatzDef('tal_webkunst', 10),
    ],
  ),
  'tal_abrichten': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_reiten', 10, bedingung: 'je nach Wesen'),
      TalentErsatzDef('tal_tierkunde', 10, bedingung: 'je nach Wesen'),
      TalentErsatzDef('tal_viehzucht', 10, bedingung: 'je nach Wesen'),
    ],
  ),
  'tal_ackerbau': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_viehzucht', 10, bedingung: 'unter Umständen'),
      TalentErsatzDef('tal_pflanzenkunde', 10, bedingung: 'unter Umständen'),
    ],
  ),
  'tal_alchemie': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_kochen', 10, bedingung: 'Tränke'),
      TalentErsatzDef('tal_pflanzenkunde', 10),
    ],
  ),
  'tal_bergbau': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_baukunst', 10, bedingung: 'je nachdem'),
      TalentErsatzDef('tal_gesteinskunde', 10, bedingung: 'je nachdem'),
      TalentErsatzDef('tal_maurer', 10, bedingung: 'je nachdem'),
      TalentErsatzDef('tal_steinmetz', 10, bedingung: 'je nachdem'),
    ],
  ),
  'tal_bogenbau': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_holzbearbeitung', 10),
      TalentErsatzDef('tal_grobschmied', 15, bedingung: 'bei Armbrüsten'),
      TalentErsatzDef('tal_feinmechanik', 10, bedingung: 'bei Armbrüsten'),
    ],
  ),
  'tal_boote_fahren': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_seefahrt', 5)],
  ),
  'tal_brauer': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_alchemie', 10)],
  ),
  'tal_drucker': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_mechanik', 10),
      TalentErsatzDef('tal_alchemie', 10, bedingung: 'unter Umständen'),
      TalentErsatzDef('tal_stoffe_faerben', 10, bedingung: 'unter Umständen'),
      TalentErsatzDef('tal_metallguss', 15, bedingung: 'unter Umständen'),
    ],
  ),
  'tal_fahrzeug_lenken': TalentNutzungDef(basis: false),
  'tal_falschspiel': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_gaukeleien', 10, bedingung: 'Taschenspielereien'),
    ],
  ),
  'tal_feinmechanik': TalentNutzungDef(basis: false),
  'tal_feuersteinbearbeitung': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_steinmetz', 10)],
  ),
  'tal_fleischer': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_anatomie', 10, bedingung: 'unter Umständen'),
      TalentErsatzDef('tal_fischen_angeln', 10, bedingung: 'unter Umständen'),
      TalentErsatzDef('tal_kochen', 10, bedingung: 'unter Umständen'),
      TalentErsatzDef('tal_tierkunde', 10, bedingung: 'unter Umständen'),
      TalentErsatzDef('tal_viehzucht', 10, bedingung: 'unter Umständen'),
      TalentErsatzDef(
        'tal_gerber_kuerschner',
        10,
        bedingung: 'unter Umständen, Trophäen',
      ),
    ],
  ),
  'tal_gerber_kuerschner': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_alchemie', 10),
      TalentErsatzDef('tal_fleischer', 10),
    ],
  ),
  'tal_glaskunst': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_steinschneider_juwelier',
        10,
        bedingung: 'eventuell',
      ),
    ],
  ),
  'tal_grobschmied': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_metallguss', 15)],
  ),
  'tal_handel': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_hauswirtschaft', 10),
      TalentErsatzDef('tal_geographie', 15),
      TalentErsatzDef('tal_schaetzen', 15),
    ],
  ),
  'tal_hauswirtschaft': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_rechnen', 10, bedingung: 'Buchführung'),
    ],
  ),
  'tal_heilkunde_gift': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_alchemie', 5, bedingung: 'Gifte'),
      TalentErsatzDef('tal_heilkunde_krankheiten', 10),
      TalentErsatzDef('tal_kochen', 10, bedingung: 'Tränke'),
    ],
  ),
  'tal_heilkunde_krankheiten': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_heilkunde_gift', 10)],
  ),
  'tal_heilkunde_seele': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_menschenkenntnis', 10),
      TalentErsatzDef('tal_ueberzeugen', 10),
    ],
  ),
  'tal_instrumentenbauer': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef(
        'tal_holzbearbeitung',
        10,
        bedingung: 'je nach Situation',
      ),
      TalentErsatzDef('tal_feinmechanik', 10, bedingung: 'je nach Situation'),
    ],
  ),
  'tal_kartographie': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_orientierung', 10, bedingung: 'unter Umständen'),
      TalentErsatzDef('tal_sternkunde', 10, bedingung: 'unter Umständen'),
    ],
  ),
  'tal_kristallzucht': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_alchemie', 15)],
  ),
  'tal_maurer': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_baukunst', 10)],
  ),
  'tal_metallguss': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_huettenkunde', 10),
      TalentErsatzDef('tal_grobschmied', 10),
    ],
  ),
  'tal_musizieren': TalentNutzungDef(basis: false),
  'tal_schloesser_knacken': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_feinmechanik', 5)],
  ),
  'tal_schnaps_brennen': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_alchemie', 5),
      TalentErsatzDef('tal_brauer', 10),
      TalentErsatzDef('tal_winzer', 10),
    ],
  ),
  'tal_seefahrt': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_boote_fahren', 10)],
  ),
  'tal_seiler': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_fesseln_entfesseln', 10, bedingung: 'Taue spleißen'),
    ],
  ),
  'tal_steinmetz': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_baukunst', 10, bedingung: 'eventuell'),
      TalentErsatzDef('tal_bergbau', 10, bedingung: 'eventuell'),
      TalentErsatzDef('tal_malen_zeichnen', 10, bedingung: 'eventuell'),
      TalentErsatzDef('tal_maurer', 10, bedingung: 'eventuell'),
    ],
  ),
  'tal_steinschneider_juwelier': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_feinmechanik', 10),
      TalentErsatzDef('tal_kristallzucht', 10),
    ],
  ),
  'tal_stellmacher': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_zimmermann', 10)],
  ),
  'tal_stoffe_faerben': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_alchemie', 10),
      TalentErsatzDef(
        'tal_drucker',
        10,
        bedingung: 'eventuell, für Stoffdruck',
      ),
    ],
  ),
  'tal_taetowieren': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_malen_zeichnen', 10)],
  ),
  'tal_toepfern': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[
      TalentErsatzDef('tal_maurer', 10, bedingung: 'eventuell'),
      TalentErsatzDef('tal_steinmetz', 10, bedingung: 'eventuell'),
    ],
  ),
  'tal_viehzucht': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_tierkunde', 10)],
  ),
  'tal_webkunst': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_schneidern', 10)],
  ),
  'tal_winzer': TalentNutzungDef(basis: false),
  'tal_zimmermann': TalentNutzungDef(
    basis: false,
    ersatz: <TalentErsatzDef>[TalentErsatzDef('tal_holzbearbeitung', 10)],
  ),
};
