/// Globale, heldenunabhaengige App-Einstellungen.
class AppSettings {
  const AppSettings({
    this.debugModus = false,
    this.dunkelModus = false,
  });

  final bool debugModus;
  final bool dunkelModus;

  AppSettings copyWith({bool? debugModus, bool? dunkelModus}) {
    return AppSettings(
      debugModus: debugModus ?? this.debugModus,
      dunkelModus: dunkelModus ?? this.dunkelModus,
    );
  }

  Map<String, dynamic> toJson() => {
    'debugModus': debugModus,
    'dunkelModus': dunkelModus,
  };

  static AppSettings fromJson(Map<String, dynamic> json) {
    return AppSettings(
      debugModus: json['debugModus'] as bool? ?? false,
      dunkelModus: json['dunkelModus'] as bool? ?? false,
    );
  }
}
