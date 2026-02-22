import 'hero_transfer_file_gateway_stub.dart'
    if (dart.library.html) 'hero_transfer_file_gateway_web.dart'
    if (dart.library.io) 'hero_transfer_file_gateway_io.dart';

enum HeroTransferExportResult { canceled, savedToFile, downloaded, shared }

class HeroTransferExportOutcome {
  const HeroTransferExportOutcome({required this.result, this.location});

  final HeroTransferExportResult result;
  final String? location;
}

abstract class HeroTransferFileGateway {
  Future<String?> pickImportJson();

  Future<HeroTransferExportOutcome> exportJson({
    required String fileNameBase,
    required String jsonPayload,
  });
}

HeroTransferFileGateway createHeroTransferFileGateway() {
  return createHeroTransferFileGatewayImpl();
}
