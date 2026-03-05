/// Strukturierte magische Sonderfertigkeit (Name + optionale Notiz).
class MagicSpecialAbility {
  const MagicSpecialAbility({
    required this.name,
    this.note = '',
  });

  final String name;
  final String note;

  MagicSpecialAbility copyWith({
    String? name,
    String? note,
  }) {
    return MagicSpecialAbility(
      name: name ?? this.name,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'note': note,
    };
  }

  static MagicSpecialAbility fromJson(Map<String, dynamic> json) {
    return MagicSpecialAbility(
      name: (json['name'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
    );
  }
}
