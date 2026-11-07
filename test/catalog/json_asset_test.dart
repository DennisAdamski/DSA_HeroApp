import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/json_asset.dart';

void main() {
  test('ladeJsonAsset liest JSON mit und ohne führende BOM', () async {
    expect(await ladeJsonAsset('a', lader: (_) async => '[1, 2]'), [1, 2]);
    expect(await ladeJsonAsset('a', lader: (_) async => '\uFEFF{"k": true}'), {
      'k': true,
    });
  });

  test('kaputtes JSON bleibt eine FormatException', () async {
    await expectLater(
      ladeJsonAsset('a', lader: (_) async => '{'),
      throwsFormatException,
    );
  });
}
