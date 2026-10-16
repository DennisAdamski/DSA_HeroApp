import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';

/// Übernimmt einen mitgelieferten Starthelden in [repository].
///
/// Ein neuer Held wird mit seinem Zustand geschrieben; ein vorhandener bleibt
/// unangetastet. Fehlt einem vorhandenen Helden der Zustand — ein früherer
/// Start brach zwischen Bogen und Zustand ab —, wird nur dieser nachgetragen
/// (ARCH-06). Beide Zustände tragen einen Änderungsstempel aus [uhr].
Future<void> uebernimmStartheld(
  HeroRepository repository,
  HeroSheet held,
  HeroState zustand, {
  required bool existiert,
  required DateTime Function() uhr,
}) async {
  if (existiert) {
    if (await repository.loadHeroState(held.id) != null) {
      return;
    }
  } else {
    await repository.saveHero(held);
  }
  await repository.saveHeroState(
    held.id,
    zustand.copyWith(lastModified: uhr().toUtc()),
  );
}

class StartupHeroImporter {
  const StartupHeroImporter({this.assetsPrefix = 'assets/heroes/'});

  final String assetsPrefix;

  Future<void> importFromAssets(HeroRepository repository) async {
    final assetPaths = await _discoverHeroAssetPaths();
    if (assetPaths.isEmpty) {
      return;
    }

    final existingIds = (await repository.listHeroes())
        .map((hero) => hero.id)
        .toSet();

    for (final path in assetPaths) {
      try {
        final payload = await rootBundle.loadString(path);
        final parsed = _parseHeroPayload(path, payload);
        if (parsed == null) {
          continue;
        }
        await uebernimmStartheld(
          repository,
          parsed.hero,
          parsed.state,
          existiert: existingIds.contains(parsed.hero.id),
          uhr: DateTime.now,
        );
        existingIds.add(parsed.hero.id);
      } on Exception catch (error) {
        debugPrint(
          'StartupHeroImporter: "$path" konnte nicht importiert werden: $error',
        );
      }
    }
  }

  Future<List<String>> _discoverHeroAssetPaths() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    final paths = <String>[];
    for (final path in assets) {
      if (!path.startsWith(assetsPrefix)) {
        continue;
      }
      if (!path.toLowerCase().endsWith('.json')) {
        continue;
      }
      paths.add(path);
    }
    paths.sort();
    return paths;
  }

  _ParsedHero? _parseHeroPayload(String assetPath, String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      throw FormatException('Top-level JSON muss ein Objekt sein.', assetPath);
    }
    final map = decoded.cast<String, dynamic>();

    if (map['kind'] == HeroTransferBundle.kind) {
      final bundle = HeroTransferBundle.fromJson(map);
      return _ParsedHero(hero: bundle.hero, state: bundle.state);
    }

    final hero = HeroSheet.fromJson(map);
    return _ParsedHero(hero: hero, state: const HeroState.empty());
  }
}

class _ParsedHero {
  const _ParsedHero({required this.hero, required this.state});

  final HeroSheet hero;
  final HeroState state;
}
