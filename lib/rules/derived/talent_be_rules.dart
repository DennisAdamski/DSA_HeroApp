int computeTalentEbe({required int baseBe, required String talentBeRule}) {
  final normalizedBase = baseBe < 0 ? 0 : baseBe;
  final compactRule = talentBeRule.trim().toLowerCase().replaceAll(
    RegExp(r'\s+'),
    '',
  );
  if (compactRule.isEmpty || compactRule == '-') {
    return 0;
  }

  if (compactRule.startsWith('x')) {
    final factorRaw = compactRule.substring(1);
    final factor = int.tryParse(factorRaw);
    if (factor == null || factor < 0) {
      return 0;
    }
    final reduction = normalizedBase * factor;
    return _clampNonPositive(-reduction);
  }

  final numeric = int.tryParse(compactRule);
  if (numeric == null || numeric >= 0) {
    return 0;
  }
  final offset = -numeric;
  final reduction = normalizedBase - offset;
  final effectiveReduction = reduction < 0 ? 0 : reduction;
  return _clampNonPositive(-effectiveReduction);
}

int _clampNonPositive(int value) => value > 0 ? 0 : value;
