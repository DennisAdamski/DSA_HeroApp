/// Dieses Enum beschreibt die Kosten, die für das steigern eines Wertes von N nach N+x benötigt.
library;

enum LearnCost {
  z(
    costs: [1,1,1,2,4,5,6,8,9,11,12,14,15,17,19,20,22,24,25,27,29,31,32,34,36,38,40,42,43,45,48],
    initialStepCost: 5
    ),
  a(
    costs: [1,2,3,4,6,7,8,10,11,13,14,16,17,19,21,22,24,26,27,29,31,33,34,36,38,40,42,44,45,47,50],
    initialStepCost: 5
    ),
  b(
    costs: [2,4,6,8,11,14,17,19,22,25,28,32,35,38,41,45,48,51,55,58,62,65,69,73,76,80,84,87,91,95,100],
    initialStepCost: 10
  ),
  c(
    costs: [2,6,9,13,17,21,25,29,34,38,43,47,51,55,60,65,70,75,80,85,95,100,105,110,115,120,125,130,135,140,150],
    initialStepCost: 15
    ),
  d(
    costs: [3,7,12,17,22,27,33,39,45,50,55,65,70,75,85,90,95,105,110,115,125,130,140,145,150,160,165,170,180,190,200],
    initialStepCost: 20
    ),
  e(
    costs: [4,9,15,21,28,34,41,48,55,65,70,80,85,95,105,110,120,130,135,145,155,165,170,180,190,200,210,220,230,240,250],
    initialStepCost: 25
    ),
  f(
    costs: [6,14,22,32,41,50,60,75,85,95,105,120,130,140,155,165,180,195,210,220,230,250,260,270,290,300,310,330,340,350,375],
    initialStepCost: 40
    ),
  g(
    costs: [8,18,30,42,55,70,85,95,110,125,140,160,175,190,210,220,240,260,270,290,310,330,340,360,380,400,420,440,460,480,500],
    initialStepCost: 50
    ),
  h(
    costs: [16,35,60,85,110,140,165,195,220,250,280,320,350,380,410,450,480,510,550,580,620,650,690,720,760,800,830,870,910,950,1000],
    initialStepCost: 100
    );

  const LearnCost({required this.costs, required this.initialStepCost});
  final List<int> costs;
  final int initialStepCost;

  int costForStep(int level) {
        if (level < 0) return initialStepCost;
    if (level >= costs.length) {
      return costs.last;
    }
    return costs[level];
  }
/// Berechnet die Kosten für das Erlernen von Level [fromLevel] bis [toLevel].
/// Wenn [withActivationCost] true ist, werden die Aktivierungskosten für das erste Level (0) mit einbezogen. Dies ist besonders wichtig, wenn negative Levels involviert sind, da diese immer die Aktivierungskosten erfordern.
  int costForRange({required int fromLevel, required int toLevel, bool withActivationCost = false}) { 
    if (fromLevel > toLevel) {
      throw ArgumentError('fromLevel must be <= toLevel');
    }
    if (fromLevel < 0) {
      withActivationCost = true; // Aktivierungskosten müssen immer berücksichtigt werden, wenn negative Levels involviert sind.
    } 

    var sum = 0;
    for (var level = fromLevel; level < toLevel; level++) {
      if (level == 0 && withActivationCost) {
        sum += initialStepCost;
      }
      sum += costForStep(level);
    }


    return sum;
  }
}

extension LearnCostNavigation on LearnCost {
  /// Gibt die nächste Komplexität zurück (z -> a -> b -> ... -> h) oder den
  /// letzten Wert, wenn clamp=true und wir über das Ende hinaus gehen.
  LearnCost next({bool wrap = false, bool clamp = true}) {
    return plusSteps(1, wrap: wrap, clamp: clamp);
  }

  /// Gibt die vorherige Komplexität zurück (h -> g -> ... -> a -> z) oder den
  /// ersten Wert, wenn clamp=true und wir unter 0 gehen.
  LearnCost previous({bool wrap = false, bool clamp = true}) {
    return plusSteps(-1, wrap: wrap, clamp: clamp);
  }

  /// Verschiebt die Komplexität um [modifier] Schritte.
  ///
  /// Beispiel: `LearnCost.a.byModifier(-1)` -> `LearnCost.z`; `LearnCost.b.byModifier(3)` -> `LearnCost.e`.
  LearnCost byModifier(int modifier, {bool wrap = false, bool clamp = true}) {
    return plusSteps(modifier, wrap: wrap, clamp: clamp);
  }

  LearnCost plusSteps(int steps, {bool wrap = false, bool clamp = true}) {
    final values = LearnCost.values;
    final nextIndex = index + steps;

    if (wrap) {
      final wrapped = nextIndex % values.length;
      return values[wrapped < 0 ? wrapped + values.length : wrapped];
    }

    if (clamp) {
      if (nextIndex < 0) return values.first;
      if (nextIndex >= values.length) return values.last;
    }

    if (nextIndex < 0 || nextIndex >= values.length) {
      throw RangeError.range(nextIndex, 0, values.length - 1, 'steps');
    }

    return values[nextIndex];
  }
}
