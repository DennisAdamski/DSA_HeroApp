import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';

/// Repository-Abstraktion (wird beim App-Start ueberschrieben).
///
/// Wirft [UnimplementedError] wenn nicht beim Start uebersteuert.
final heroRepositoryProvider = Provider<HeroRepository>((ref) {
  throw UnimplementedError(
    'HeroRepository muss beim App-Start uebersteuert werden.',
  );
});

/// Codec fuer Transfer-JSON (Import/Export).
final heroTransferCodecProvider = Provider<HeroTransferCodec>((ref) {
  return const HeroTransferCodec();
});

/// Plattformabhaengiger Dateigateway fuer Transferdateien.
final heroTransferFileGatewayProvider = Provider<HeroTransferFileGateway>((
  ref,
) {
  return createHeroTransferFileGateway();
});

/// ID des aktuell in der Heldenliste ausgewaehlten Helden (oder `null`).
final selectedHeroIdProvider = StateProvider<String?>((ref) => null);
