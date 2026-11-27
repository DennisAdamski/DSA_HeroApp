part of 'syncing_hero_repository.dart';

/// Beobachtung der Online-Dokumente und Wiederanlauf nach Fehlern (SYNC-12).
///
/// Ohne [SyncingHeroRepository.wiederholung] verhält sich alles wie zuvor:
/// ein Listener-Fehler steht nur im Status, und erst `syncNow` gleicht ab.
extension _SyncWiederholungAblauf on SyncingHeroRepository {
  /// Startet die Listener, die gerade nicht laufen.
  void _starteBeobachtung() {
    if (_geschlossen || !_beobachten) return;
    final mitNeustart = wiederholung != null;
    _heroSubscription ??= remote.watchHeroes().listen(
      (records) {
        _beobachtungsVersuch = 0;
        unawaited(_applyRemoteHeroRecords(records));
      },
      onError: (Object error, StackTrace stackTrace) {
        _handleRemoteStreamError(error, stackTrace);
        if (!mitNeustart) return;
        unawaited(_heroSubscription?.cancel());
        _heroSubscription = null;
        _planeBeobachtungsNeustart();
      },
      onDone: () {
        if (!mitNeustart) return;
        _heroSubscription = null;
        _planeBeobachtungsNeustart();
      },
    );
    final stateGateway = _stateRemote;
    if (stateGateway == null) return;
    _stateSubscription ??= stateGateway.watchHeroStates().listen(
      (records) {
        _beobachtungsVersuch = 0;
        unawaited(_applyRemoteStateRecords(records));
      },
      onError: (Object error, StackTrace stackTrace) {
        _handleRemoteStreamError(error, stackTrace);
        if (!mitNeustart) return;
        unawaited(_stateSubscription?.cancel());
        _stateSubscription = null;
        _planeBeobachtungsNeustart();
      },
      onDone: () {
        if (!mitNeustart) return;
        _stateSubscription = null;
        _planeBeobachtungsNeustart();
      },
    );
  }

  /// Ob ein Listener nach einem Fehler beendet ist und neu starten muss.
  bool get _beobachtungUnterbrochen =>
      _beobachten &&
      (_heroSubscription == null ||
          (_stateRemote != null && _stateSubscription == null));

  // Ein Firestore-Listener liefert nach einem Fehler nichts mehr. Ohne
  // Neustart kämen Änderungen anderer Geräte erst mit dem nächsten
  // manuellen Abgleich an.
  void _planeBeobachtungsNeustart() {
    final folge = wiederholung;
    if (_geschlossen || folge == null || _beobachtungsTimer != null) return;
    final warten = SyncWiederholung.wartezeit(
      folge.beobachtungNach,
      _beobachtungsVersuch,
    );
    if (warten == null) return;
    _beobachtungsVersuch++;
    _beobachtungsTimer = Timer(warten, () {
      _beobachtungsTimer = null;
      _starteBeobachtung();
    });
  }

  /// Plant nach einem vorübergehenden Fehler einen erneuten Abgleich.
  ///
  /// Läuft gerade ein Abgleich, plant dessen Ende neu; ein bereits geplanter
  /// Versuch bleibt der einzige.
  void _planeWiederholung(SyncStatusSnapshot status) {
    final folge = wiederholung;
    final fehler = status.lastFailure;
    if (_geschlossen ||
        folge == null ||
        fehler == null ||
        status.isSyncing ||
        _wiederholungsTimer != null ||
        !SyncWiederholung.istVoruebergehend(fehler.kind)) {
      return;
    }
    final warten = SyncWiederholung.wartezeit(
      folge.abgleichNach,
      _wiederholungsVersuch,
    );
    if (warten == null) return;
    _wiederholungsVersuch++;
    _wiederholungsTimer = Timer(warten, () {
      _wiederholungsTimer = null;
      if (_geschlossen || _status.isSyncing) return;
      unawaited(syncNow());
    });
  }

  /// Ein vollständiger Abgleich ist gelungen: neue Fehler beginnen die
  /// Wartefolge von vorn.
  void _wiederholungAbgeschlossen() {
    _wiederholungsTimer?.cancel();
    _wiederholungsTimer = null;
    _wiederholungsVersuch = 0;
  }

  void _beendeWiederholung() {
    _geschlossen = true;
    _wiederholungsTimer?.cancel();
    _wiederholungsTimer = null;
    _beobachtungsTimer?.cancel();
    _beobachtungsTimer = null;
  }
}
