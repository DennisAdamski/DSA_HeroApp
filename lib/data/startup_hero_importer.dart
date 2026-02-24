import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';

class StartupHeroImporter {
  const StartupHeroImporter({
    this.assetsPrefix = 'assets/heroes/',
    this.assetManifestPath = 'AssetManifest.json',
  });

  final String assetsPrefix;
  final String assetManifestPath;

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
        if (existingIds.contains(parsed.hero.id)) {
          continue;
        }

        await repository.saveHero(parsed.hero);
        await repository.saveHeroState(parsed.hero.id, parsed.state);
        existingIds.add(parsed.hero.id);
      } on Exception catch (error) {
        debugPrint(
          'StartupHeroImporter: "$path" konnte nicht importiert werden: $error',
        );
      }
    }
  }

  Future<List<String>> _discoverHeroAssetPaths() async {
    final manifestRaw = await rootBundle.loadString(assetManifestPath);
    final decoded = jsonDecode(manifestRaw);
    if (decoded is! Map) {
      return const <String>[];
    }

    final paths = <String>[];
    for (final entry in decoded.entries) {
      final path = entry.key.toString();
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
