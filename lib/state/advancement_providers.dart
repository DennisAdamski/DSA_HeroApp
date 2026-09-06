import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Ungespeicherte Steigerungsrunde mit fester Basis und geprüfter Vorschau.
class AdvancementSession {
  /// Verbindet die unveränderte Basis mit den Ergebnissen des Regel-Replays.
  AdvancementSession({
    required this.sessionId,
    required this.base,
    required this.catalog,
    required List<HeroAdvancementEntry> entries,
    required AdvancementReplay replay,
    this.isSaving = false,
  }) : entries = List.unmodifiable(entries),
       preview = replay.hero,
       errors = Map.unmodifiable(replay.errors),
       apReserved = replay.apReserved;

  /// Identifiziert ausschließlich diese noch nicht übernommene Runde.
  final String sessionId;

  /// Gespeicherter Held beim Start; enthält nur feste Historie.
  final HeroSheet base;

  /// Katalog, nach dem alle Einträge dieser Runde geprüft werden.
  final RulesCatalog catalog;

  /// Nur die Einträge dieser Runde dürfen entfernt werden.
  final List<HeroAdvancementEntry> entries;

  /// Vorschau mit allen aktuell gültigen Einträgen; niemals direkt persistiert.
  final HeroSheet preview;

  /// Ungültige Folgeeinträge bleiben mit ihrem Grund sichtbar.
  final Map<String, String> errors;

  /// Durch gültige geplante Einträge reservierte AP.
  final int apReserved;

  /// Verhindert doppelte Übernahmen und Änderungen während des Speicherns.
  final bool isSaving;

  /// Nur vollständige, gültige und noch nicht gespeicherte Runden sind buchbar.
  bool get canCommit => !isSaving && entries.isNotEmpty && errors.isEmpty;
}

/// Orchestriert Planung und einmalige Übernahme ohne Regelberechnungen im State.
class AdvancementSessionController extends Notifier<AdvancementSession?> {
  /// Bindet den Controller an genau einen Helden.
  AdvancementSessionController(this.heroId);

  /// Held, dessen gespeicherter Zustand bis zur Übernahme unverändert bleibt.
  final String heroId;

  @override
  AdvancementSession? build() {
    // Kontowechsel tauschen das Repository aus; die offene Runde gehoert zum
    // alten Profil und wird deshalb verworfen. Bewusst `listen` statt `watch`:
    // `watch` zieht den Provider in jedem Container ohne uebersteuertes
    // Repository selbst in den Fehlerzustand, obwohl Planen gar keines
    // braucht — gebraucht wird es erst beim Uebernehmen.
    ref.listen(heroRepositoryProvider, (previous, next) {
      if (previous != null && !identical(previous, next)) state = null;
    }, onError: (_, _) {});
    return null;
  }

  /// Startet eine leere Runde; eine vorhandene Runde wird nie überschrieben.
  void start({required HeroSheet hero, required RulesCatalog catalog}) {
    if (state != null || hero.id != heroId) {
      throw StateError('Die Steigerungsrunde kann nicht gestartet werden.');
    }
    state = AdvancementSession(
      sessionId: const Uuid().v4(),
      base: hero,
      catalog: catalog,
      entries: const [],
      replay: replayAdvancements(
        base: hero,
        entries: const [],
        catalog: catalog,
      ),
    );
  }

  /// Merkt eine geprüfte Änderung vor und sperrt fremde oder doppelte Einträge.
  void add(HeroAdvancementEntry entry) {
    final current = _editableSession();
    final duplicate =
        current.entries.any((item) => item.id == entry.id) ||
        current.base.advancementHistory.any((item) => item.id == entry.id);
    if (entry.sessionId != current.sessionId || duplicate) {
      throw StateError('Dieser Eintrag gehört nicht neu zu dieser Runde.');
    }
    final entries = [...current.entries, entry];
    final replay = _replay(current, entries);
    final error = replay.errors[entry.id];
    if (error != null) throw StateError(error);
    state = _updated(current, entries, replay);
  }

  /// Entfernt nur einen laufenden Eintrag und prüft alle Folgeeinträge erneut.
  void remove(String entryId) {
    final current = _editableSession();
    if (!current.entries.any((entry) => entry.id == entryId)) {
      throw StateError(
        'Übernommene Steigerungen können nicht entfernt werden.',
      );
    }
    final entries = current.entries
        .where((entry) => entry.id != entryId)
        .toList();
    state = _updated(current, entries, _replay(current, entries));
  }

  /// Verwirft ausschließlich den ungespeicherten Entwurf.
  void discard() {
    _editableSession();
    state = null;
  }

  /// Speichert Werte, AP, SE und feste Historie gemeinsam nach Konfliktprüfung.
  ///
  /// Bei einem Fehler bleibt die Runde vollständig erhalten. Ein mittlerweile
  /// geänderter Held wird nicht mit der alten Sitzungsbasis überschrieben.
  Future<void> commit() async {
    final current = _editableSession();
    if (!current.canCommit) {
      throw StateError('Bitte prüfe zuerst die geplanten Steigerungen.');
    }
    final replay = _replay(current, current.entries);
    state = _updated(current, current.entries, replay, isSaving: true);
    try {
      final repo = ref.read(heroRepositoryProvider);
      final latest = await repo.loadHeroById(heroId);
      if (!ref.mounted || state?.sessionId != current.sessionId) {
        throw StateError('Die Steigerungsrunde wurde inzwischen geschlossen.');
      }
      final expectedHash = heroContentHash(current.base);
      if (latest == null || heroContentHash(latest) != expectedHash) {
        throw StateError(
          'Der Held wurde inzwischen geändert. Bitte verwirf diese Runde '
          'und plane mit dem aktuellen Helden erneut.',
        );
      }
      final updated = commitAdvancements(
        base: current.base,
        entries: current.entries,
        catalog: current.catalog,
      );
      await ref
          .read(heroActionsProvider)
          .saveHero(
            updated,
            expectedContentHash: expectedHash,
            validationCatalog: current.catalog,
          );
      if (ref.mounted && state?.sessionId == current.sessionId) state = null;
    } catch (_) {
      if (ref.mounted && state?.sessionId == current.sessionId) {
        state = _updated(current, current.entries, replay);
      }
      rethrow;
    }
  }

  // Auch zurückkehrende Dialog-Callbacks müssen die Speichersperre beachten.
  AdvancementSession _editableSession() {
    final current = state;
    if (current == null || current.isSaving) {
      throw StateError('Die Steigerungsrunde ist gerade nicht bearbeitbar.');
    }
    return current;
  }

  // Jede Änderung wird von derselben Basis aus regelkonform neu aufgebaut.
  AdvancementReplay _replay(
    AdvancementSession current,
    List<HeroAdvancementEntry> entries,
  ) => replayAdvancements(
    base: current.base,
    entries: entries,
    catalog: current.catalog,
  );

  // Metadaten bleiben bei immutable Aktualisierungen derselben Runde erhalten.
  AdvancementSession _updated(
    AdvancementSession current,
    List<HeroAdvancementEntry> entries,
    AdvancementReplay replay, {
    bool isSaving = false,
  }) => AdvancementSession(
    sessionId: current.sessionId,
    base: current.base,
    catalog: current.catalog,
    entries: entries,
    replay: replay,
    isSaving: isSaving,
  );
}

/// Flüchtige Steigerungsrunde je Held mit ausschließlich ungespeicherten Daten.
final advancementSessionProvider =
    NotifierProvider.family<
      AdvancementSessionController,
      AdvancementSession?,
      String
    >(AdvancementSessionController.new);

/// Optionsliste der laufenden Runde je Umfang.
///
/// Die Berechnung hängt nur an der Sitzung, nicht am Suchtext — ohne diese
/// Zwischenstufe liefe der gesamte Katalogaufbau bei jedem Tastenanschlag neu.
/// Absichtlich ein Provider und kein Widget-State: Katalogliste und
/// Erwerbsblatt sind getrennte Widget-Bäume (das Blatt liegt im Overlay des
/// Root-Navigators) und leiten beide von derselben Sitzung ab.
final advancementOptionsProvider =
    Provider.family<
      List<AdvancementOption>,
      ({String heroId, AdvancementScope scope})
    >((ref, key) {
      final session = ref.watch(advancementSessionProvider(key.heroId));
      if (session == null) return const <AdvancementOption>[];
      return buildAdvancementOptions(
        hero: session.preview,
        catalog: session.catalog,
        scope: key.scope,
      );
    });
