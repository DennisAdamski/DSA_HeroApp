import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/held_importieren.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/vorgaenge_wiederaufnehmen.dart';
import 'package:dsa_heldenverwaltung/data/vorgangsjournal.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

// Ein Absturz wird als Schritt simuliert, der nie fertig wird: Der Import
// läuft nicht abgewartet bis dorthin, danach nimmt ein neues Repository auf
// demselben Speicher (gleiche Listen) den Vorgang wieder auf — wie nach
// einem Neustart.

const _attribute = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 12,
  kk: 12,
);

const _bildA = AvatarGalleryEntry(id: 'a', fileName: 'alt_a.png');
const _bildB = AvatarGalleryEntry(id: 'b', fileName: 'alt_b.png');

HeroSheet _held({
  String id = 'alt',
  String name = 'Alrik',
  List<AvatarGalleryEntry> galerie = const <AvatarGalleryEntry>[],
}) {
  return HeroSheet(
    id: id,
    name: name,
    level: 1,
    attributes: _attribute,
    appearance: HeroAppearance(avatarGallery: galerie),
  );
}

const _zustand = HeroState(
  currentLep: 21,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 30,
);

final _importZeit = DateTime.utc(2026, 10, 7, 12);
final _neustartZeit = DateTime.utc(2026, 10, 7, 13);

Map<String, dynamic> _galeriebild(AvatarGalleryEntry eintrag, String bytes) {
  return {...eintrag.toJson(), 'base64': base64Encode(utf8.encode(bytes))};
}

HeroTransferBundle _bundle(HeroSheet held) => HeroTransferBundle(
  exportedAt: _importZeit,
  hero: held,
  state: _zustand,
  galleryImages: [_galeriebild(_bildA, 'A'), _galeriebild(_bildB, 'B')],
);

/// Repository, das an gewählten Stellen hängen bleibt.
class _HaengendesRepo extends FakeRepository {
  _HaengendesRepo(List<HeroSheet> helden, Map<String, HeroState> zustaende)
    : super(heroes: helden, states: zustaende);

  bool haengtBeimZustand = false;

  @override
  Future<void> saveHeroState(String heroId, HeroState state) {
    if (haengtBeimZustand) {
      return Completer<void>().future;
    }
    return super.saveHeroState(heroId, state);
  }
}

/// Bildablage, die beim Bild [haengtBei] hängen bleibt.
class _Ablage {
  final Map<String, String> dateien = <String, String>{};
  final List<String> geloescht = <String>[];
  String? haengtBei;
  int loeschfehler = 0;

  Future<String> galerie({
    required String heroId,
    required String entryId,
    required List<int> bytes,
  }) {
    if (entryId == haengtBei) {
      return Completer<String>().future;
    }
    final name = '${heroId}_$entryId.png';
    dateien[name] = utf8.decode(bytes);
    return Future<String>.value(name);
  }

  Future<void> loesche(String name) async {
    if (loeschfehler > 0) {
      loeschfehler--;
      throw Exception('Cloud nicht erreichbar');
    }
    geloescht.add(name);
    dateien.remove(name);
  }
}

enum _Speichern { normal, haengtDavor, haengtDanach }

class _Geraet {
  _Geraet({List<HeroSheet> helden = const <HeroSheet>[]})
    : helden = List<HeroSheet>.of(helden) {
    vorher = _HaengendesRepo(this.helden, zustaende);
  }

  final List<HeroSheet> helden;
  final Map<String, HeroState> zustaende = <String, HeroState>{};
  final SpeicherVorgangsjournal journal = SpeicherVorgangsjournal();
  final _Ablage ablage = _Ablage();
  late final _HaengendesRepo vorher;
  _Speichern speichern = _Speichern.normal;

  /// Startet den Import und lässt ihn bis zum hängenden Schritt laufen.
  Future<void> importiereBisZumAbsturz(
    HeroTransferBundle bundle, {
    required bool neuAnlegen,
  }) async {
    final ablauf = HeldImportieren(
      repository: vorher,
      speichere: (held) async {
        if (speichern == _Speichern.haengtDavor) {
          await Completer<void>().future;
        }
        await vorher.saveHero(held);
        if (speichern == _Speichern.haengtDanach) {
          await Completer<void>().future;
        }
        return held;
      },
      uebernimmKatalog: (_) async {},
      speichereGaleriebild: ablage.galerie,
      speichereHauptbild: ({required heroId, required bytes}) async => '',
      loescheBild: ablage.loesche,
      journal: journal,
      neueId: () => 'neu',
      uhr: () => _importZeit,
      maxHelden: 5,
    );
    unawaited(ablauf.importiere(bundle, neuAnlegen: neuAnlegen));
    await pumpEventQueue();
  }

  /// Nimmt die offenen Vorgänge auf einem frischen Repository wieder auf.
  Future<WiederanlaufBericht> neustart() {
    return VorgaengeWiederaufnehmen(
      repository: FakeRepository(heroes: helden, states: zustaende),
      journal: journal,
      loescheBild: ablage.loesche,
      uhr: () => _neustartZeit,
    ).fuehreAus();
  }
}

void main() {
  test('Absturz beim zweiten Bild eines neuen Helden: das erste Bild wird '
      'gelöscht, es entsteht kein Held', () async {
    final geraet = _Geraet()..ablage.haengtBei = 'b';
    await geraet.importiereBisZumAbsturz(
      _bundle(_held(galerie: [_bildA, _bildB])),
      neuAnlegen: true,
    );
    expect(geraet.ablage.dateien.keys, ['neu_a.png']);
    expect(await geraet.journal.offene(), hasLength(1));

    final bericht = await geraet.neustart();

    expect(bericht.ausgeglichen, 1);
    expect(geraet.ablage.dateien, isEmpty);
    expect(geraet.helden, isEmpty);
    expect(geraet.zustaende, isEmpty);
    expect(await geraet.journal.offene(), isEmpty);
  });

  test(
    'Absturz vor dem Speichern des Helden: alle Bilder werden gelöscht',
    () async {
      final geraet = _Geraet()..speichern = _Speichern.haengtDavor;
      await geraet.importiereBisZumAbsturz(
        _bundle(_held(galerie: [_bildA, _bildB])),
        neuAnlegen: true,
      );

      await geraet.neustart();

      expect(geraet.ablage.geloescht, ['neu_a.png', 'neu_b.png']);
      expect(geraet.helden, isEmpty);
      expect(await geraet.journal.offene(), isEmpty);
    },
  );

  test('Held gespeichert, Vermerk fehlt: der geänderte Held zählt, der '
      'Zustand wird nachgetragen und die Bilder bleiben', () async {
    final geraet = _Geraet()..speichern = _Speichern.haengtDanach;
    await geraet.importiereBisZumAbsturz(
      _bundle(_held(galerie: [_bildA, _bildB])),
      neuAnlegen: true,
    );
    expect(
      (await geraet.journal.offene()).values.single['schritt'],
      'bilderAblegen',
    );

    final bericht = await geraet.neustart();

    expect(bericht.fortgesetzt, 1);
    expect(geraet.ablage.geloescht, isEmpty);
    expect(geraet.zustaende['neu']!.currentLep, 21);
    expect(await geraet.journal.offene(), isEmpty);
  });

  test('Absturz beim Zustand: er wird nachgetragen und gestempelt', () async {
    final geraet = _Geraet()..vorher.haengtBeimZustand = true;
    await geraet.importiereBisZumAbsturz(
      _bundle(_held(galerie: [_bildA, _bildB])),
      neuAnlegen: true,
    );
    expect(
      (await geraet.journal.offene()).values.single['schritt'],
      'heldGespeichert',
    );
    expect(geraet.zustaende, isEmpty);

    final bericht = await geraet.neustart();

    expect(bericht.fortgesetzt, 1);
    final zustand = geraet.zustaende['neu']!;
    expect(zustand.currentLep, 21);
    expect(zustand.currentAu, 30);
    expect(zustand.lastModified, _neustartZeit);
    expect(geraet.ablage.dateien.keys, ['neu_a.png', 'neu_b.png']);
  });

  test('überschreibender Import: Bilder, auf die der vorhandene Held '
      'verweist, bleiben stehen', () async {
    final geraet = _Geraet(
      helden: [
        _held(galerie: [_bildA]),
      ],
    )..speichern = _Speichern.haengtDavor;
    geraet.ablage.dateien['alt_a.png'] = 'alt';
    await geraet.importiereBisZumAbsturz(
      _bundle(_held(name: 'Import', galerie: [_bildA, _bildB])),
      neuAnlegen: false,
    );

    final bericht = await geraet.neustart();

    expect(bericht.ausgeglichen, 1);
    expect(geraet.ablage.geloescht, ['alt_b.png']);
    expect(geraet.ablage.dateien.keys, ['alt_a.png']);
    expect(geraet.helden.single.name, 'Alrik');
    expect(geraet.zustaende, isEmpty);
  });

  test('ein zweiter Wiederanlauf ändert nichts mehr', () async {
    final geraet = _Geraet()..vorher.haengtBeimZustand = true;
    await geraet.importiereBisZumAbsturz(_bundle(_held()), neuAnlegen: true);
    await geraet.neustart();
    final zustand = geraet.zustaende['neu'];

    final zweiter = await geraet.neustart();

    expect(zweiter.fortgesetzt + zweiter.ausgeglichen, 0);
    expect(identical(geraet.zustaende['neu'], zustand), isTrue);
  });

  test(
    'scheitert das Löschen, bleibt der Vorgang für den nächsten Lauf',
    () async {
      final geraet = _Geraet()..speichern = _Speichern.haengtDavor;
      await geraet.importiereBisZumAbsturz(
        _bundle(_held(galerie: [_bildA])),
        neuAnlegen: true,
      );
      geraet.ablage.loeschfehler = 1;

      final erster = await geraet.neustart();
      expect(erster.gescheitert, 1);
      expect(await geraet.journal.offene(), hasLength(1));

      final zweiter = await geraet.neustart();
      expect(zweiter.ausgeglichen, 1);
      expect(geraet.ablage.dateien, isEmpty);
      expect(await geraet.journal.offene(), isEmpty);
    },
  );

  test('Einträge unbekannter Art bleiben unangetastet', () async {
    final geraet = _Geraet();
    await geraet.journal.merke('fremd', {'art': 'kuenftigerVorgang'});
    await geraet.journal.merke('alt', {
      'art': 'heldImportieren',
      'heroId': 'x',
      'schritt': 'kuenftigerSchritt',
      'zustand': <String, Object?>{},
    });

    final bericht = await geraet.neustart();

    expect(bericht.unbekannt, 2);
    expect((await geraet.journal.offene()).keys, {'fremd', 'alt'});
  });
}
