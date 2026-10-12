import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';

/// Herkunft und sozialer Hintergrund eines Helden.
class HeroBackground {
  /// Schluessel, die [fromJson] aus dem flachen Helden-JSON liest.
  static const Set<String> jsonSchluessel = <String>{
    'rasse',
    'rasseModText',
    'kultur',
    'kulturModText',
    'profession',
    'professionModText',
    'familieHerkunftHintergrund',
    'stand',
    'titel',
    'sozialstatus',
    'herkunftsModifikatoren',
  };

  const HeroBackground({
    this.rasse = '',
    this.rasseModText = '',
    this.kultur = '',
    this.kulturModText = '',
    this.profession = '',
    this.professionModText = '',
    this.familieHerkunftHintergrund = '',
    this.stand = '',
    this.titel = '',
    this.sozialstatus = 0,
    this.herkunftsModifikatoren,
  });

  final String rasse;
  final String rasseModText;
  final String kultur;
  final String kulturModText;
  final String profession;
  final String professionModText;
  final String familieHerkunftHintergrund;
  final String stand;
  final String titel;
  final int sozialstatus;

  /// Strukturierte Herkunftsmodifikatoren (ARCH-02); `null`, solange der
  /// Held noch nicht migriert wurde. Im JSON nur bei Belegung, damit
  /// Bestandshelden ihren Inhalts-Hash behalten.
  final HeroHerkunftsModifikatoren? herkunftsModifikatoren;

  HeroBackground copyWith({
    String? rasse,
    String? rasseModText,
    String? kultur,
    String? kulturModText,
    String? profession,
    String? professionModText,
    String? familieHerkunftHintergrund,
    String? stand,
    String? titel,
    int? sozialstatus,
    Object? herkunftsModifikatoren = _unveraendert,
  }) {
    return HeroBackground(
      rasse: rasse ?? this.rasse,
      rasseModText: rasseModText ?? this.rasseModText,
      kultur: kultur ?? this.kultur,
      kulturModText: kulturModText ?? this.kulturModText,
      profession: profession ?? this.profession,
      professionModText: professionModText ?? this.professionModText,
      familieHerkunftHintergrund:
          familieHerkunftHintergrund ?? this.familieHerkunftHintergrund,
      stand: stand ?? this.stand,
      titel: titel ?? this.titel,
      sozialstatus: sozialstatus ?? this.sozialstatus,
      herkunftsModifikatoren: identical(herkunftsModifikatoren, _unveraendert)
          ? this.herkunftsModifikatoren
          : herkunftsModifikatoren as HeroHerkunftsModifikatoren?,
    );
  }

  /// Serialisiert als flache Map (Felder auf Root-Ebene).
  Map<String, dynamic> toJson() => {
    'rasse': rasse,
    'rasseModText': rasseModText,
    'kultur': kultur,
    'kulturModText': kulturModText,
    'profession': profession,
    'professionModText': professionModText,
    'familieHerkunftHintergrund': familieHerkunftHintergrund,
    'stand': stand,
    'titel': titel,
    'sozialstatus': sozialstatus,
    if (herkunftsModifikatoren != null)
      'herkunftsModifikatoren': herkunftsModifikatoren!.toJson(),
  };

  /// Liest aus einer flachen Map (Felder auf Root-Ebene).
  static HeroBackground fromJson(Map<String, dynamic> json) {
    return HeroBackground(
      rasse: (json['rasse'] as String?) ?? '',
      rasseModText: (json['rasseModText'] as String?) ?? '',
      kultur: (json['kultur'] as String?) ?? '',
      kulturModText: (json['kulturModText'] as String?) ?? '',
      profession: (json['profession'] as String?) ?? '',
      professionModText: (json['professionModText'] as String?) ?? '',
      familieHerkunftHintergrund:
          (json['familieHerkunftHintergrund'] as String?) ?? '',
      stand: (json['stand'] as String?) ?? '',
      titel: (json['titel'] as String?) ?? '',
      sozialstatus: (json['sozialstatus'] as num?)?.toInt() ?? 0,
      herkunftsModifikatoren: json['herkunftsModifikatoren'] == null
          ? null
          : HeroHerkunftsModifikatoren.fromJson(json['herkunftsModifikatoren']),
    );
  }
}

const Object _unveraendert = Object();
