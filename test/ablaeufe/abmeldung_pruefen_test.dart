import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/abmeldung_pruefen.dart';
import 'package:dsa_heldenverwaltung/domain/sync_controller.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';

class _Controller extends AppSyncController {
  _Controller(this.status);

  final SyncStatusSnapshot status;
  final List<String> aufrufe = <String>[];

  @override
  SyncStatusSnapshot get currentStatus => status;

  @override
  Stream<SyncStatusSnapshot> watchStatus() => const Stream.empty();

  @override
  Future<void> syncNow() async => aufrufe.add('sync');

  @override
  Future<void> warteAufUebertragungen() async => aufrufe.add('warten');

  @override
  Future<void> resolveConflict(
    String conflictId,
    SyncResolutionChoice resolution,
  ) async {}

  @override
  SyncObjectDiff? conflictDiff(String conflictId) => null;
}

void main() {
  test('ohne Controller ist alles gesichert', () async {
    expect((await pruefeVorAbmeldung(null)).istGesichert, isTrue);
  });

  test('gleicht ab, wartet auf Uploads und meldet gesichert', () async {
    final controller = _Controller(const SyncStatusSnapshot());
    final befund = await pruefeVorAbmeldung(controller);
    expect(befund.istGesichert, isTrue);
    expect(controller.aufrufe, <String>['sync', 'warten']);
  });

  test('ausstehende Vorgaenge und Fehler gelten als ungesichert', () async {
    final vorgaenge = await pruefeVorAbmeldung(
      _Controller(const SyncStatusSnapshot(ausstehendeVorgaenge: 2)),
    );
    expect(vorgaenge.istGesichert, isFalse);
    expect(vorgaenge.ausstehendeVorgaenge, 2);

    final fehler = await pruefeVorAbmeldung(
      _Controller(
        SyncStatusSnapshot(
          lastFailure: SyncFailure.fromError(
            StateError('offline'),
            occurredAt: DateTime.utc(2026),
          ),
        ),
      ),
    );
    expect(fehler.istGesichert, isFalse);
    expect(fehler.syncFehler, isNotNull);
  });
}
