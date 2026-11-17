import 'dart:typed_data';

import 'package:dsa_heldenverwaltung/data/avatar_gesicht/avatar_gesichtserkennung.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht_cache.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht_service.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';

/// [AvatarGesichtserkennung] mit festem Ergebnis fuer Widget-Tests.
///
/// Die echte Erkennung rechnet in einem Isolate, das im Fake-Async von
/// `testWidgets` nie fertig wird; die Anzeige bliebe im Ladezustand.
class FesteAvatarGesichtserkennung implements AvatarGesichtserkennung {
  const FesteAvatarGesichtserkennung({
    this.befund = const AvatarGesichtsbefund(bildBreite: 1, bildHoehe: 1),
  });

  final AvatarGesichtsbefund befund;

  @override
  Future<AvatarGesichtsbefund> erkenne(Uint8List bildBytes) async => befund;
}

/// Service mit fester Erkennung und In-Memory-Cache, zum Ueberschreiben von
/// `avatarGesichtServiceProvider`.
AvatarGesichtService festerAvatarGesichtService({
  AvatarGesichtsbefund befund = const AvatarGesichtsbefund(
    bildBreite: 1,
    bildHoehe: 1,
  ),
}) {
  final cache = InMemoryAvatarGesichtCache();
  return AvatarGesichtService(
    erkennung: FesteAvatarGesichtserkennung(befund: befund),
    cacheFuer: (_) => cache,
  );
}
