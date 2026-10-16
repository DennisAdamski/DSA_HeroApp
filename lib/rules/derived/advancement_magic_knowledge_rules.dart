import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';

import 'advancement_options.dart';
import 'hero_begabung_rules.dart';
import 'learning_rules.dart';
import 'magic_acquisition_rules.dart';
import 'magic_status_rules.dart';
import 'tradition_rules.dart';

/// Erstellt Erwerbs- und Steigerungsziele ohne bestehende Ritualgruppen zu ändern.
List<AdvancementOption> buildMagicKnowledgeOptions(
  AdvancementContext context,
  AdvancementScope scope,
) {
  final result = <AdvancementOption>[];
  final representations = <String>{};
  for (final tradition in kTraditionen) {
    if (tradition.repraesentation.isNotEmpty &&
        representations.add(tradition.repraesentation)) {
      result.add(
        resolveMagicKnowledge(
          context,
          AdvancementKind.representation,
          tradition.repraesentation,
          {'traditionId': tradition.id},
        )!,
      );
    }
    if (tradition.ritualKnowledgeName.isNotEmpty) {
      result.add(
        resolveMagicKnowledge(
          context,
          AdvancementKind.ritualKnowledge,
          tradition.id,
          {'traditionId': tradition.id},
        )!,
      );
    }
  }
  for (final category in context.hero.ritualCategories) {
    if (category.knowledgeMode == HeroRitualKnowledgeMode.ownKnowledge &&
        category.ownKnowledge != null) {
      result.add(
        resolveMagicKnowledge(
          context,
          AdvancementKind.ritualKnowledge,
          'category:${category.id}',
          const {},
        )!,
      );
    }
  }
  return result
      .where(
        (option) => switch (scope) {
          AdvancementScope.all => true,
          AdvancementScope.active => option.isOwned,
          AdvancementScope.inactive => !option.isOwned,
        },
      )
      .toList();
}

/// Löst einen Nachweis erneut gegen den aktuellen Vorschauhelden auf.
AdvancementOption? resolveMagicKnowledge(
  AdvancementContext context,
  AdvancementKind kind,
  String targetId,
  Map<String, String> options,
) {
  if (kind == AdvancementKind.representation) {
    final tradition = kTraditionen
        .where(
          (t) =>
              t.repraesentation == targetId &&
              (options['traditionId'] == null ||
                  t.id == options['traditionId']),
        )
        .firstOrNull;
    if (tradition == null) return null;
    final owned = context.hero.representationen.contains(targetId);
    final status =
        detectMagicStatus(context.hero, context.catalog) ??
        options['magicStatus'];
    final existing = context.hero.representationen.toSet();
    final base = isValidMagicStatus(status) && status != 'quarter'
        ? repraesentationApCost(
            anzahlVorhanden: existing.length,
            istHalbzauberer: status == 'half',
          )
        : null;
    final cost = _isRecording(options)
        ? 0
        : existing.isEmpty
        ? null
        : base == null
        ? null
        : (base * representationDiscount(existing, targetId)).round();
    return AdvancementOption(
      kind: kind,
      targetId: targetId,
      label: '${tradition.name} ($targetId)',
      isOwned: owned,
      apCost: cost,
      unavailableReason: owned ? 'Bereits erworben' : null,
      options: {
        ...options,
        'traditionId': tradition.id,
        'magicStatus': ?status,
        'permanentKL': '${context.permanentAttributes.kl}',
        'permanentIN': '${context.permanentAttributes.inn}',
      },
    );
  }
  final categoryId = targetId.startsWith('category:')
      ? targetId.substring(9)
      : null;
  final category = context.hero.ritualCategories
      .where((c) => c.id == categoryId)
      .firstOrNull;
  final tradition = kTraditionen.where((t) => t.id == targetId).firstOrNull;
  if (categoryId != null &&
      (category?.knowledgeMode != HeroRitualKnowledgeMode.ownKnowledge ||
          category?.ownKnowledge == null)) {
    return null;
  }
  if (categoryId == null &&
      (tradition == null || tradition.ritualKnowledgeName.isEmpty)) {
    return null;
  }
  final knowledge =
      category?.ownKnowledge ?? context.hero.ritualKnowledge[targetId];
  final basis =
      knowledge?.learningComplexity ?? tradition!.ritualLearningComplexity;
  final foreign =
      tradition != null &&
      tradition.repraesentation.isNotEmpty &&
      !context.hero.representationen.contains(tradition.repraesentation);
  final status =
      detectMagicStatus(context.hero, context.catalog) ??
      options['magicStatus'];
  final penalized = increaseLernkomplexitaet(
    basisKomplexitaet: basis,
    increaseSteps: foreign ? 2 : 0,
  );
  final synthetic =
      category ??
      HeroRitualCategory(
        id: targetId,
        name: tradition!.name,
        knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
        ownKnowledge: knowledge,
        rituals: [
          for (final c in context.hero.ritualCategories)
            if (c.traditionId == targetId) ...c.rituals,
        ],
      );
  final befund = context.begabungen.ritualkenntnis(synthetic);
  final complexity = effektiveRitualkenntnisKomplexitaet(
    basisKomplexitaet: penalized,
    befund: befund,
  );
  final attrs = context.permanentAttributes;
  final maximum = computeTalentMaxValue(
    effectiveAttributes: attrs,
    attributeNames: const ['MU', 'KL', 'IN'],
    gifted: befund.begabungen.isNotEmpty,
  );
  final target = int.tryParse(options['targetValue'] ?? '');
  final learnCost = learnCostFromKomplexitaet(complexity);
  int? raiseCost;
  if (knowledge != null &&
      target != null &&
      target > knowledge.value &&
      learnCost != null) {
    raiseCost = berechneSteigerungskosten(
      vonWert: knowledge.value,
      aufWert: target,
      effektiveKomplexitaet: learnCost,
    ).apKosten;
    if (options['learningMethod'] == 'teacher') {
      raiseCost = apMitLehrmeister(raiseCost);
    }
  }
  return AdvancementOption(
    kind: kind,
    targetId: targetId,
    label: knowledge?.name ?? tradition!.ritualKnowledgeName,
    currentValue: knowledge?.value ?? -1,
    maxValue: maximum,
    isOwned: knowledge != null,
    learnCost: learnCost,
    apCost: knowledge == null
        ? _isRecording(options)
              ? 0
              : kRitualkenntnisFremdeTraditionAp
        : raiseCost,
    complexityHint: 'Lernkomplexität $complexity',
    options: {
      ...options,
      'magicStatus': ?status,
      'foreignRitualKnowledge': '$foreign',
      if (tradition != null) 'traditionId': tradition.id,
      'learningComplexity': basis,
    },
  );
}

/// Wendet die gerichteten Traditionsrabatte aus WdH S. 290 an.
double representationDiscount(Set<String> existing, String target) {
  if (target == 'Srl' && existing.contains('Mag')) return .5;
  if ((target == 'Bor' && existing.contains('Mag')) ||
      (target == 'Mag' && existing.contains('Srl')) ||
      (target == 'Dru' && existing.contains('Geo')) ||
      (target == 'Geo' && existing.contains('Dru'))) {
    return .75;
  }
  return 1;
}

/// Prüft harte Duplikatgrenzen sowie bestätigte Ausbildung und Abweichungen.
void validateMagicKnowledgeEntry(
  HeroSheet hero,
  HeroAdvancementEntry entry,
  AdvancementOption option,
) {
  final options = entry.options;
  if (entry.apCost < 0 || entry.apCost > hero.apAvailable) {
    throw StateError('Nicht genügend AP oder ungültige AP-Kosten.');
  }
  final override =
      options['meisterentscheid'] == 'true' &&
      options['meisterentscheidReason']?.trim().isNotEmpty == true;
  void require(bool valid, String message) {
    if (!valid && !override) throw StateError(message);
  }

  if (entry.seSpent != 0) {
    throw StateError('Kenntnisse verwenden keine Sondererfahrungen.');
  }
  final source = options['source'] ?? 'acquisition';
  if (!const {'creation', 'existing', 'acquisition'}.contains(source)) {
    throw StateError('Unbekannter Erwerbsgrund.');
  }
  int? expected = option.apCost;
  if (entry.kind == AdvancementKind.representation) {
    if (option.isOwned) throw StateError('Repräsentation bereits erworben.');
    require(
      isValidMagicStatus(option.options['magicStatus']),
      'Zaubererstatus muss ausdrücklich geklärt werden.',
    );
    if (entry.fromValue != null || entry.toValue != null) {
      throw StateError('Repräsentationen verwenden keine numerischen Werte.');
    }
    if (!_isRecording(options)) {
      final status = option.options['magicStatus'];
      // Ein bekannter Status wurde beim Optionsaufbau bereits in Kosten umgesetzt.
      require(
        option.apCost != null || isValidMagicStatus(status),
        'Zaubererstatus oder Erwerbsfall muss ausdrücklich geklärt werden.',
      );
      final count = hero.representationen.toSet().length;
      require(
        count > 0,
        'Erste Repräsentation erfordert einen Meisterentscheid.',
      );
      require(!hero.isEpisch, 'Im epischen Status ist kein Neuerwerb erlaubt.');
      final kl =
          int.tryParse(option.options['permanentKL'] ?? '') ??
          hero.attributes.kl;
      final inn =
          int.tryParse(option.options['permanentIN'] ?? '') ??
          hero.attributes.inn;
      require(
        count == 1 ? kl >= 15 && inn >= 15 : kl >= 18,
        'Eigenschaftsvoraussetzungen der weiteren Repräsentation fehlen.',
      );
      final points = hero.spells.values
          .where(
            (s) =>
                s.learnedRepresentation == entry.targetId &&
                (s.spellValue ?? 0) > 0,
          )
          .fold<int>(0, (sum, s) => sum + s.spellValue!);
      require(points >= 50, '50 ZfP in der Zielrepräsentation fehlen.');
      require(
        options['teacherConfirmed'] == 'true' &&
            options['trainingYearConfirmed'] == 'true',
        'Lehrmeister und mindestens ein Jahr Ausbildung bestätigen.',
      );
    }
  } else {
    if (entry.fromValue != option.currentValue || entry.toValue == null) {
      throw StateError('Ausgangswert der Ritualkenntnis hat sich geändert.');
    }
    if (option.currentValue < 0) {
      final start = _isRecording(options)
          ? int.tryParse(options['startValue'] ?? '3')
          : 3;
      if (entry.toValue != start || start == null || start < 0) {
        throw StateError(
          'Aktivierung muss den bestätigten Start-RkW übernehmen.',
        );
      }
      if (!_isRecording(options)) {
        if (option.options['foreignRitualKnowledge'] == 'true') {
          require(
            const {'full', 'half'}.contains(option.options['magicStatus']),
            'Fremde Ritualkenntnis erfordert Voll-/Halbzaubererstatus oder Meisterentscheid.',
          );
        }
        require(
          options['permissionConfirmed'] == 'true',
          'Meistererlaubnis bestätigen.',
        );
      }
    } else {
      if (entry.toValue! <= option.currentValue) {
        throw StateError('Eine Steigerung muss den RkW erhöhen.');
      }
      require(
        entry.toValue! > option.currentValue &&
            entry.toValue! <= option.maxValue,
        'RkW liegt außerhalb der erlaubten Steigerung.',
      );
      require(
        options['teacherConfirmed'] == 'true' ||
            options['bookConfirmed'] == 'true',
        'Lehrmeister oder geeignetes Buch bestätigen.',
      );
      expected = berechneSteigerungskosten(
        vonWert: option.currentValue,
        aufWert: entry.toValue!,
        effektiveKomplexitaet: option.learnCost!,
      ).apKosten;
      if (options['learningMethod'] == 'teacher') {
        require(
          options['teacherConfirmed'] == 'true',
          'Lehrmeisterrabatt erfordert einen bestätigten Lehrmeister.',
        );
        expected = apMitLehrmeister(expected);
      }
    }
  }
  if (_isRecording(options) && !option.isOwned && entry.apCost != 0) {
    throw StateError('Kostenfreie Erfassung darf keine AP buchen.');
  }
  if (expected == null || entry.apCost != expected) {
    if (!override ||
        int.tryParse(options['customApCost'] ?? '') != entry.apCost) {
      throw StateError(
        'Abweichende Kosten brauchen einen dokumentierten Meisterentscheid.',
      );
    }
  }
}

/// Ergänzt oder steigert Kenntnisse und erhält alle fachfremden Bestandsdaten.
HeroSheet applyMagicKnowledgeEntry(HeroSheet hero, HeroAdvancementEntry entry) {
  if (entry.kind == AdvancementKind.representation) {
    final tradition = kTraditionen.firstWhere(
      (t) =>
          t.repraesentation == entry.targetId &&
          (entry.options['traditionId'] == null ||
              t.id == entry.options['traditionId']),
    );
    return hero.copyWith(
      representationen: [...hero.representationen, entry.targetId],
      repraesentationsTraditionen: {
        ...hero.repraesentationsTraditionen,
        entry.targetId: tradition.id,
      },
    );
  }
  if (entry.targetId.startsWith('category:')) {
    final id = entry.targetId.substring(9);
    return hero.copyWith(
      ritualCategories: [
        for (final c in hero.ritualCategories)
          if (c.id == id)
            c.copyWith(
              ownKnowledge: c.ownKnowledge!.copyWith(value: entry.toValue),
            )
          else
            c,
      ],
    );
  }
  final tradition = kTraditionen.firstWhere((t) => t.id == entry.targetId);
  final old =
      hero.ritualKnowledge[entry.targetId] ??
      HeroRitualKnowledge(
        name: tradition.ritualKnowledgeName,
        learningComplexity: tradition.ritualLearningComplexity,
      );
  return hero.copyWith(
    ritualKnowledge: {
      ...hero.ritualKnowledge,
      entry.targetId: old.copyWith(value: entry.toValue),
    },
  );
}

// Erfassungsgründe werden im Nachweis aufbewahrt; sie sind kein AP-Rabatt.
bool _isRecording(Map<String, String> options) =>
    options['source'] == 'creation' || options['source'] == 'existing';
