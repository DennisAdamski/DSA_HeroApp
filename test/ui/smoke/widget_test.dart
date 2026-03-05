import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/main.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    final fakeRepository = FakeRepository.empty();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(fakeRepository)],
        child: const DsaApp(),
      ),
    );

    expect(find.text('DSA Helden'), findsOneWidget);
  });
}
