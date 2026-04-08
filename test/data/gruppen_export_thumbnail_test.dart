import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/gruppen_snapshot_codec.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/gruppen_snapshot.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import '../test_support/avatar_test_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildGruppenExportJson stores a compact avatar thumbnail', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'gruppen_export_thumbnail_test',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final sourceBytes = await createNoisyPngBytes();
    final sourceBase64 = base64Encode(sourceBytes);
    final avatarStorage = const AvatarFileStorage();
    await avatarStorage.saveAvatar(
      heroStoragePath: tempDir.path,
      heroId: 'h1',
      pngBytes: sourceBytes,
    );

    final repo = FakeRepository(
      heroes: [
        const HeroSheet(
          id: 'h1',
          name: 'Alrik',
          level: 3,
          attributes: Attributes(
            mu: 12,
            kl: 11,
            inn: 10,
            ch: 9,
            ff: 8,
            ge: 7,
            ko: 6,
            kk: 5,
          ),
          appearance: HeroAppearance(avatarFileName: 'h1.png'),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        heroStorageLocationProvider.overrideWith(
          (ref) async => HeroStorageLocation(
            defaultPath: tempDir.path,
            effectivePath: tempDir.path,
            configuredPath: tempDir.path,
            customPathSupported: true,
            usesCustomPath: true,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final actions = container.read(heroActionsProvider);
    final rawJson = await actions.buildGruppenExportJson(
      gruppenName: 'Testgruppe',
      heroIds: const <String>['h1'],
    );
    final snapshot = const GruppenSnapshotCodec().decode(rawJson);

    final thumbnailBase64 = snapshot.helden.single.avatarThumbnailBase64;
    expect(thumbnailBase64, isNotNull);
    expect(thumbnailBase64, isNot(sourceBase64));
    expect(
      thumbnailBase64!.length,
      lessThanOrEqualTo(HeldVisitenkarte.avatarThumbnailBase64MaxLength),
    );
  });
}
