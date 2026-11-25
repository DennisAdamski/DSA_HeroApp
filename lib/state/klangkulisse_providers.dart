import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/freesound/freesound_client.dart';
import 'package:dsa_heldenverwaltung/data/freesound/freesound_oauth.dart';
import 'package:dsa_heldenverwaltung/data/freesound/freesound_zugang_ablage.dart';
import 'package:dsa_heldenverwaltung/data/freesound/klang_spieler.dart';
import 'package:dsa_heldenverwaltung/domain/klangstimmung.dart';

/// Ob die App Freesound abfragen und Klänge abspielen darf.
///
/// Ohne Override aus: Tests stellen so nie eine Netzanfrage und berühren
/// keinen Audiokanal. Die App schaltet es in `AppStartupGate._buildScope` ein.
final freesoundAktivProvider = Provider<bool>((ref) => false);

/// OAuth-Ablauf mit der Client-ID des Builds; `null`, wenn Freesound aus ist
/// oder der Build keine `FREESOUND_CLIENT_ID` mitbringt.
final freesoundOAuthProvider = Provider<FreesoundOAuth?>((ref) {
  if (!ref.watch(freesoundAktivProvider) || kFreesoundClientId.isEmpty) {
    return null;
  }
  final oauth = FreesoundOAuth(clientId: kFreesoundClientId);
  ref.onDispose(oauth.close);
  return oauth;
});

/// Ablage des Freesound-Zugangs (nur auf dem Gerät).
final freesoundZugangAblageProvider = Provider<FreesoundZugangAblage>(
  (ref) => ref.watch(freesoundAktivProvider)
      ? SichereFreesoundZugangAblage()
      : FluechtigeFreesoundZugangAblage(),
);

/// Der gespeicherte Freesound-Zugang, `null` ohne Anmeldung.
final freesoundZugangProvider =
    AsyncNotifierProvider<FreesoundZugangNotifier, FreesoundZugang?>(
      FreesoundZugangNotifier.new,
    );

/// Anmelden, Abmelden und Token-Erneuerung bei Freesound.
class FreesoundZugangNotifier extends AsyncNotifier<FreesoundZugang?> {
  FreesoundAnmeldung? _anmeldung;
  Future<String>? _erneuerung;

  FreesoundZugangAblage get _ablage => ref.read(freesoundZugangAblageProvider);

  @override
  Future<FreesoundZugang?> build() =>
      ref.watch(freesoundZugangAblageProvider).lies();

  FreesoundOAuth get _oauth =>
      ref.read(freesoundOAuthProvider) ??
      (throw const FreesoundFehler(
        FreesoundFehlerArt.anmeldung,
        'Freesound ist in diesem Build nicht eingerichtet.',
      ));

  /// Beginnt eine Anmeldung und liefert die Seite für den Browser.
  Uri anmeldungStarten() {
    final anmeldung = _anmeldung = _oauth.starte();
    return anmeldung.adresse;
  }

  /// Tauscht den eingefügten Code gegen einen Zugang und speichert ihn.
  Future<void> anmeldungAbschliessen(String eingabe) async {
    final anmeldung = _anmeldung;
    if (anmeldung == null) {
      throw const FreesoundFehler(
        FreesoundFehlerArt.anmeldung,
        'Bitte die Anmeldung zuerst starten.',
      );
    }
    final zugang = await _oauth.tausche(eingabe, anmeldung);
    _anmeldung = null;
    await _ablage.schreibe(zugang);
    state = AsyncData(zugang);
  }

  /// Vergisst den Zugang auf diesem Gerät.
  Future<void> abmelden() async {
    _anmeldung = null;
    await _ablage.schreibe(null);
    state = const AsyncData(null);
  }

  /// Gültiges Bearer-Token; erneuert bei nahem Ablauf oder auf Wunsch.
  ///
  /// Gleichzeitige Aufrufe teilen eine Erneuerung. Lehnt Freesound sie ab,
  /// ist die Nutzerin abgemeldet. Wirft einen [FreesoundFehler].
  Future<String> token({bool erneuern = false}) async {
    // Nicht auf `future` warten: ein Fehler beim Laden endete dort nie.
    final zugang = state.hasValue ? state.value : await _ablage.lies();
    if (zugang == null) {
      throw const FreesoundFehler(
        FreesoundFehlerArt.anmeldung,
        'Zuerst bei Freesound anmelden.',
      );
    }
    if (!erneuern && !zugang.laeuftAb(DateTime.now())) {
      return zugang.accessToken;
    }
    return _erneuerung ??= _erneuere(zugang.refreshToken)
        .whenComplete(() => _erneuerung = null);
  }

  Future<String> _erneuere(String refreshToken) async {
    try {
      final neu = await _oauth.erneuere(refreshToken);
      await _ablage.schreibe(neu);
      state = AsyncData(neu);
      return neu.accessToken;
    } on FreesoundFehler catch (fehler) {
      if (fehler.art == FreesoundFehlerArt.anmeldung) await abmelden();
      rethrow;
    }
  }
}

/// Client mit dem Zugang der Nutzerin, `null` ohne Anmeldung.
final freesoundClientProvider = Provider<FreesoundClient?>((ref) {
  final angemeldet = ref.watch(
    freesoundZugangProvider.select((z) => z.asData?.value != null),
  );
  if (!angemeldet) return null;
  final client = FreesoundClient(
    token: ref.read(freesoundZugangProvider.notifier).token,
  );
  ref.onDispose(client.close);
  return client;
});

/// Erzeugt Audiokanäle; stumm, solange Freesound aus ist.
final klangKanalFabrikProvider = Provider<KlangKanalFabrik>(
  (ref) => ref.watch(freesoundAktivProvider)
      ? AudioplayersKlangKanal.new
      : StummerKlangKanal.new,
);

/// Zustand einer Ambiente-Ebene.
class EbenenZustand {
  /// Erstellt den Zustand.
  const EbenenZustand({this.an = true, this.staerke = 0.6, this.klang});

  /// Ob die Ebene laufen soll.
  final bool an;

  /// Stärke von 0 bis 1.
  final double staerke;

  /// Laufender Klang, `null` solange gesucht wird oder aus.
  final FreesoundKlang? klang;

  EbenenZustand copyWith({
    bool? an,
    double? staerke,
    FreesoundKlang? Function()? klang,
  }) => EbenenZustand(
    an: an ?? this.an,
    staerke: staerke ?? this.staerke,
    klang: klang == null ? this.klang : klang(),
  );
}

/// Zustand des Klangpults.
class KlangpultZustand {
  /// Erstellt den Zustand.
  const KlangpultZustand({
    this.szeneId,
    this.ebenen = const <String, EbenenZustand>{},
    this.musiklage,
    this.musikKlang,
    this.musikStaerke = 0.4,
    this.gesamt = 0.8,
    this.effektQuellen = const <FreesoundKlang>[],
    this.laedt = 0,
    this.fehler,
  });

  /// Gewählte Szene.
  final String? szeneId;

  /// Ebenen der Szene nach Kennung.
  final Map<String, EbenenZustand> ebenen;

  /// Gewählte Musiklage, `null` ohne Musik.
  final Musiklage? musiklage;

  /// Laufende Musik.
  final FreesoundKlang? musikKlang;

  /// Stärke der Musik von 0 bis 1.
  final double musikStaerke;

  /// Gesamtlautstärke von 0 bis 1.
  final double gesamt;

  /// Zuletzt gespielte Einzeleffekte (für die Namensnennung).
  final List<FreesoundKlang> effektQuellen;

  /// Anzahl laufender Suchen.
  final int laedt;

  /// Meldung des letzten Fehlers.
  final String? fehler;

  /// Die gewählte Szene.
  Klangszene? get szene =>
      kKlangszenen.where((s) => s.id == szeneId).firstOrNull;

  /// Ob gerade etwas klingt.
  bool get laeuft =>
      musikKlang != null || ebenen.values.any((e) => e.an && e.klang != null);

  /// Alle Klänge, die eine Namensnennung brauchen.
  List<FreesoundKlang> get quellen => <FreesoundKlang>{
    ?musikKlang,
    for (final e in ebenen.values)
      if (e.an) ?e.klang,
    ...effektQuellen,
  }.toList();

  KlangpultZustand copyWith({
    String? Function()? szeneId,
    Map<String, EbenenZustand>? ebenen,
    Musiklage? Function()? musiklage,
    FreesoundKlang? Function()? musikKlang,
    double? musikStaerke,
    double? gesamt,
    List<FreesoundKlang>? effektQuellen,
    int? laedt,
    String? Function()? fehler,
  }) => KlangpultZustand(
    szeneId: szeneId == null ? this.szeneId : szeneId(),
    ebenen: ebenen ?? this.ebenen,
    musiklage: musiklage == null ? this.musiklage : musiklage(),
    musikKlang: musikKlang == null ? this.musikKlang : musikKlang(),
    musikStaerke: musikStaerke ?? this.musikStaerke,
    gesamt: gesamt ?? this.gesamt,
    effektQuellen: effektQuellen ?? this.effektQuellen,
    laedt: laedt ?? this.laedt,
    fehler: fehler == null ? this.fehler : fehler(),
  );
}

/// Geräteweites Klangpult: läuft weiter, wenn Route, Kachel oder Held wechseln.
final klangkulisseProvider =
    NotifierProvider<KlangpultNotifier, KlangpultZustand>(
      KlangpultNotifier.new,
    );

/// Dauer der Überblendung bei Szenen-, Lagen- und Klangwechsel.
const Duration kKlangBlende = Duration(milliseconds: 1500);

/// Sucht bei Freesound und mischt Ebenen, Musik und Effekte.
class KlangpultNotifier extends Notifier<KlangpultZustand> {
  @override
  KlangpultZustand build() {
    ref.onDispose(() => _allesAus(Duration.zero));
    // Abmelden lässt das Pult verstummen.
    ref.listen(freesoundZugangProvider.select((z) => z.asData?.value != null), (
      vorher,
      angemeldet,
    ) {
      if (vorher == true && !angemeldet) allesStopp();
    });
    return const KlangpultZustand();
  }

  final Map<String, KlangKanal> _ebenen = <String, KlangKanal>{};
  KlangKanal? _musik;
  final Map<String, List<FreesoundKlang>> _cache =
      <String, List<FreesoundKlang>>{};
  final Random _zufall = Random();

  // Zählen Szenen- und Musikwechsel, damit eine überholte Suche nichts startet.
  int _szenenNummer = 0;
  int _musikNummer = 0;

  KlangKanalFabrik get _fabrik => ref.read(klangKanalFabrikProvider);

  /// Wechselt zu [szene]: alte Ebenen blenden aus, neue ein; eine gewählte
  /// Musiklage folgt der neuen Szene.
  Future<void> szeneWaehlen(Klangszene szene) async {
    final nummer = ++_szenenNummer;
    _ebenenAus(kKlangBlende);
    state = state.copyWith(
      szeneId: () => szene.id,
      ebenen: {
        for (final e in szene.ambiente) e.id: EbenenZustand(staerke: e.staerke),
      },
      fehler: () => null,
    );
    final lage = state.musiklage;
    await Future.wait([
      for (final e in szene.ambiente) _starteEbene(e, nummer),
      if (lage != null) musik(lage),
    ]);
  }

  /// Schaltet die Ebene [id] der aktuellen Szene an oder aus.
  Future<void> ebeneUmschalten(String id) async {
    final ebene = _ebene(id);
    final zustand = state.ebenen[id];
    if (ebene == null || zustand == null) return;
    if (zustand.an) {
      unawaited(_ebenen.remove(id)?.blendeAus(kKlangBlende));
      _setzeEbene(id, zustand.copyWith(an: false, klang: () => null));
    } else {
      _setzeEbene(id, zustand.copyWith(an: true));
      await _starteEbene(ebene, _szenenNummer);
    }
  }

  /// Setzt die Stärke der Ebene [id].
  Future<void> ebenenStaerke(String id, double wert) async {
    final zustand = state.ebenen[id];
    if (zustand == null) return;
    _setzeEbene(id, zustand.copyWith(staerke: wert.clamp(0, 1).toDouble()));
    await _ebenen[id]?.setzeLautstaerke(
      state.gesamt * state.ebenen[id]!.staerke,
    );
  }

  /// Ersetzt den Klang der Ebene [id] durch den nächsten Treffer.
  Future<void> andererKlang(String id) async {
    final ebene = _ebene(id);
    final zustand = state.ebenen[id];
    if (ebene == null || zustand == null || !zustand.an) return;
    unawaited(_ebenen.remove(id)?.blendeAus(kKlangBlende));
    await _starteEbene(ebene, _szenenNummer, nach: zustand.klang);
  }

  /// Wechselt die Musik auf [lage]; `null` blendet sie aus.
  ///
  /// „Sieg“ spielt einmal ohne Schleife.
  Future<void> musik(Musiklage? lage) async {
    final nummer = ++_musikNummer;
    unawaited(_musik?.blendeAus(kKlangBlende));
    _musik = null;
    state = state.copyWith(musiklage: () => lage, musikKlang: () => null);
    if (lage == null) return;
    final anfrage = state.szene?.musikAnfrage(lage) ?? kMusikStandard[lage]!;
    final sieg = lage == Musiklage.sieg;
    final treffer = await _suche(
      anfrage,
      mindestSekunden: sieg ? 0 : 30,
      hoechstSekunden: sieg ? 20 : 0,
    );
    if (nummer != _musikNummer || treffer.isEmpty) return;
    final klang = treffer.first;
    final kanal = _musik = _fabrik();
    state = state.copyWith(musikKlang: () => klang);
    await _spiele(
      kanal,
      klang,
      state.gesamt * state.musikStaerke,
      schleife: !sieg,
    );
  }

  /// Setzt die Stärke der Musik.
  Future<void> musikStaerke(double wert) async {
    state = state.copyWith(musikStaerke: wert.clamp(0, 1).toDouble());
    await _musik?.setzeLautstaerke(state.gesamt * state.musikStaerke);
  }

  /// Spielt [effekt] einmal; ein zufälliger der besten Treffer sorgt für
  /// Abwechslung bei wiederholtem Antippen.
  Future<void> effekt(Klangeffekt effekt) async {
    final treffer = await _suche(
      effekt.anfrage,
      hoechstSekunden: effekt.hoechstSekunden,
    );
    if (treffer.isEmpty) return;
    final klang = treffer[_zufall.nextInt(min(5, treffer.length))];
    state = state.copyWith(
      effektQuellen: <FreesoundKlang>{
        klang,
        ...state.effektQuellen,
      }.take(8).toList(),
    );
    await _spiele(_fabrik(), klang, state.gesamt, schleife: false);
  }

  /// Setzt die Gesamtlautstärke und passt alle laufenden Kanäle an.
  Future<void> gesamtLautstaerke(double wert) async {
    state = state.copyWith(gesamt: wert.clamp(0, 1).toDouble());
    await Future.wait([
      for (final MapEntry(:key, :value) in _ebenen.entries)
        value.setzeLautstaerke(
          state.gesamt * (state.ebenen[key]?.staerke ?? 0),
        ),
      ?_musik?.setzeLautstaerke(state.gesamt * state.musikStaerke),
    ]);
  }

  /// Hält alles an und vergisst die Szene; Lautstärken bleiben.
  void allesStopp() {
    _allesAus(const Duration(milliseconds: 400));
    state = KlangpultZustand(
      gesamt: state.gesamt,
      musikStaerke: state.musikStaerke,
    );
  }

  void _allesAus(Duration dauer) {
    _szenenNummer++;
    _musikNummer++;
    _ebenenAus(dauer);
    unawaited(_musik?.blendeAus(dauer));
    _musik = null;
  }

  void _ebenenAus(Duration dauer) {
    for (final kanal in _ebenen.values) {
      unawaited(kanal.blendeAus(dauer));
    }
    _ebenen.clear();
  }

  Klangebene? _ebene(String id) =>
      state.szene?.ambiente.where((e) => e.id == id).firstOrNull;

  void _setzeEbene(String id, EbenenZustand zustand) {
    state = state.copyWith(ebenen: {...state.ebenen, id: zustand});
  }

  Future<void> _starteEbene(
    Klangebene ebene,
    int nummer, {
    FreesoundKlang? nach,
  }) async {
    final treffer = await _suche(
      ebene.anfrage,
      mindestSekunden: ebene.mindestSekunden,
    );
    final zustand = state.ebenen[ebene.id];
    // Überholt, inzwischen aus oder schon von einem zweiten Antippen gestartet.
    if (nummer != _szenenNummer ||
        zustand == null ||
        !zustand.an ||
        _ebenen.containsKey(ebene.id) ||
        treffer.isEmpty) {
      return;
    }
    final klang =
        treffer[(treffer.indexOf(nach ?? treffer.last) + 1) % treffer.length];
    final kanal = _ebenen[ebene.id] = _fabrik();
    _setzeEbene(ebene.id, zustand.copyWith(klang: () => klang));
    await _spiele(kanal, klang, state.gesamt * zustand.staerke);
  }

  Future<void> _spiele(
    KlangKanal kanal,
    FreesoundKlang klang,
    double lautstaerke, {
    bool schleife = true,
  }) async {
    try {
      await kanal.spiele(
        klang.vorschauUrl,
        lautstaerke: lautstaerke,
        schleife: schleife,
        einblenden: schleife ? kKlangBlende : Duration.zero,
      );
    } on Object {
      state = state.copyWith(
        fehler: () => '„${klang.name}“ ließ sich nicht abspielen.',
      );
    }
  }

  // Treffer bleiben für die Sitzung gemerkt: ein Szenenwechsel kostet so nur
  // beim ersten Mal Anfragen (Limit 60 je Minute, 2000 je Tag).
  Future<List<FreesoundKlang>> _suche(
    String anfrage, {
    double mindestSekunden = 0,
    double hoechstSekunden = 0,
  }) async {
    final schluessel = '$anfrage|$mindestSekunden|$hoechstSekunden';
    final gemerkt = _cache[schluessel];
    if (gemerkt != null) return gemerkt;
    final client = ref.read(freesoundClientProvider);
    if (client == null) {
      state = state.copyWith(fehler: () => 'Zuerst bei Freesound anmelden.');
      return const <FreesoundKlang>[];
    }
    state = state.copyWith(laedt: state.laedt + 1);
    try {
      final treffer = await client.suche(
        anfrage,
        mindestSekunden: mindestSekunden,
        hoechstSekunden: hoechstSekunden,
      );
      if (treffer.isNotEmpty) _cache[schluessel] = treffer;
      state = state.copyWith(
        laedt: state.laedt - 1,
        fehler: treffer.isEmpty
            ? () => 'Keine Klänge zu „$anfrage“ gefunden.'
            : null,
      );
      return treffer;
    } on FreesoundFehler catch (fehler) {
      state = state.copyWith(
        laedt: state.laedt - 1,
        fehler: () => fehler.meldung,
      );
      return const <FreesoundKlang>[];
    }
  }
}
