import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_patzer.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_patzer_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_patzer_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

/// Nach tatsächlicher Buchung aufrufen, ausschließlich für Nahkampf zu Fuß.
void starteGefechtsPatzer({
  required WidgetRef ref,
  required String heroId,
  required String auftragId,
  required ProbeResult result,
  required GefechtsKampfmittelwahl? kampfmittel,
}) {
  if (!istGefechtsPatzerkandidat(result)) return;
  final s = ref.read(gefechtPatzerProvider(heroId));
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  final profil = kampfmittel == null || snapshot == null
      ? null
      : gefechtsBruchprofil(snapshot.hero.combatConfig, kampfmittel);
  if (s.verarbeiteteAuftraege.contains(auftragId)) return;
  if (s.patzer != null && !s.patzer!.erledigt) {
    throw StateError('Vorherigen Patzer zuerst abschließen.');
  }
  ref
      .read(gefechtPatzerProvider(heroId).notifier)
      .setzen(
        s.copyWith(
          patzer: GefechtsPatzerauftrag(
            id: auftragId,
            original: result,
            kampfmittel: kampfmittel,
            profil: profil,
          ),
          verarbeiteteAuftraege: {...s.verarbeiteteAuftraege, auftragId},
        ),
      );
}

/// Geführte tatsächliche Patzer und ausdrücklich festgestellte Bruchtestanlässe.
class GefechtPatzer extends ConsumerStatefulWidget {
  /// Alle Bedienungen verwenden den übergeordneten Gefechts-Guard.
  const GefechtPatzer({
    super.key,
    required this.heroId,
    required this.bestand,
    required this.gesperrt,
    required this.onAktion,
  });
  final String heroId;

  /// Löst die Gefechtsbrücke erst beim Bedienen auf; die Anzeige braucht sie nicht.
  final KartoGefechtsAdapter Function() bestand;
  final bool gesperrt;
  final Future<void> Function(Future<void> Function()) onAktion;
  @override
  ConsumerState<GefechtPatzer> createState() => _GefechtPatzerState();
}

class _GefechtPatzerState extends ConsumerState<GefechtPatzer> {
  bool _busy = false;
  String? _fehler;
  GefechtsPatzerstand get _stand =>
      ref.read(gefechtPatzerProvider(widget.heroId));
  void _setzen(GefechtsPatzerstand s) =>
      ref.read(gefechtPatzerProvider(widget.heroId).notifier).setzen(s);

  // Lokale Sperre schützt auch bei einem versehentlich mehrfach gerufenen Guard.
  Future<void> _run(Future<void> Function() aktion) async {
    if (_busy || widget.gesperrt) return;
    setState(() {
      _busy = true;
      _fehler = null;
    });
    try {
      await widget.onAktion(aktion);
    } catch (e) {
      if (mounted) setState(() => _fehler = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gefechtPatzerProvider(widget.heroId));
    final sitzung = ref.watch(gefechtProvider(widget.heroId));
    final p = s.patzer;
    final b = s.bruch;
    final sperre = widget.gesperrt || _busy || sitzung == null;
    final offen =
        p != null && !p.erledigt ||
        b != null && !b.erledigt ||
        s.gesperrteMittel.isNotEmpty ||
        s.verloreneMittel.isNotEmpty ||
        _fehler != null;
    // Ohne offene Folge bleibt nur der Einstieg sichtbar; die Erklärung steht
    // im Bruchtestdialog, damit die Ansicht nicht dauerhaft wächst.
    if (!offen) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const ValueKey('gefecht-bruchtest'),
          onPressed: sperre ? null : () => _run(_bruchAnlass),
          child: const Text('Bruchtest'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patzer und Bruchtests'),
            if (p != null && !p.erledigt) ...[
              Text('${p.original.request.title}: tatsächlich gewürfelte 20'),
              if (p.kontrolle == null)
                TextButton(
                  onPressed: sperre ? null : () => _run(_kontrolle),
                  child: const Text('Patzer-Kontrollwurf'),
                ),
              if (p.kontrolle != null &&
                  !p.kontrolle!.success &&
                  p.tabelle == null)
                TextButton(
                  onPressed: sperre ? null : () => _run(_tabelle),
                  child: const Text('Patzertabelle · 2W6'),
                ),
              if (p.tabelle != null) ...[
                Text(
                  'Tabellenwurf ${p.tabelle} · alle restlichen Rundenaktionen verloren',
                ),
                TextButton(
                  onPressed: sperre ? null : () => _run(_patzerAbschluss),
                  child: const Text('Patzerfolgen übernehmen'),
                ),
                if (p.profil != null)
                  TextButton(
                    onPressed: sperre
                        ? null
                        : () => _run(_patzerNeuBestaetigen),
                    child: const Text('Patzer-Waffenprofil erneut bestätigen'),
                  ),
              ],
            ],
            if (b != null && !b.erledigt) ...[
              Text(
                '${b.profil.name} · BF ${b.profil.bf} · '
                '${b.kritisch ? "kritischer Treffer" : "festgestellter Bruchtestanlass"}',
              ),
              if (b.wurf == null)
                TextButton(
                  onPressed: sperre ? null : () => _run(_bruchWurf),
                  child: const Text('Bruchtest · 2W6'),
                ),
              if (b.wurf != null) ...[
                Text(
                  'Bruchtestwurf ${b.wurf} bleibt für Wiederholung gespeichert',
                ),
                TextButton(
                  onPressed: sperre ? null : () => _run(_bruchAbschluss),
                  child: const Text('Bruchtestergebnis übernehmen'),
                ),
                TextButton(
                  onPressed: sperre ? null : () => _run(_neuBestaetigen),
                  child: const Text('Aktuelles BF-/Waffenprofil bestätigen'),
                ),
              ],
            ],
            if (s.gesperrteMittel.isNotEmpty)
              for (final e in s.gesperrteMittel.entries)
                Text('${e.key}: ${e.value}'),
            if (_fehler != null) Text(_fehler!),
            for (final key in s.verloreneMittel)
              TextButton(
                onPressed: sperre || s.verloreneRunde == sitzung.runde
                    ? null
                    : () => _run(() => _wiederaufnahme(key)),
                child: Text('Verlorenes Kampfmittel wieder aufgenommen · $key'),
              ),
            TextButton(
              onPressed:
                  sperre || p != null && !p.erledigt || b != null && !b.erledigt
                  ? null
                  : () => _run(_bruchAnlass),
              child: const Text('Bruchtest'),
            ),
            const Text(
              'Nahkampf zu Fuß. Eigentreffer, Wunden und Umgebungsfolgen '
              'werden mit konkreten Tischangaben übernommen; keine automatische Waffenlöschung.',
            ),
          ],
        ),
      ),
    );
  }

  // Callback und Rückgabe dürfen denselben Wurf nicht zweimal buchen.
  Future<void> _wuerfeln(
    ResolvedProbeRequest request,
    void Function(ProbeResult) buchen,
  ) async {
    var gebucht = false;
    void einmal(ProbeResult r) {
      if (gebucht) return;
      gebucht = true;
      buchen(r);
    }

    final r = await widget.bestand().gefechtsProbe(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      request: request,
      onResolved: einmal,
    );
    if (r != null) einmal(r);
  }

  // Erst misslungene Kontrolle bestätigt den Patzer und den Aktionsverlust.
  Future<void> _kontrolle() async {
    final p = _stand.patzer;
    if (p == null || p.kontrolle != null || p.erledigt) return;
    await _wuerfeln(gefechtsPatzerKontrollprobe(p.original), (r) {
      final aktuell = _stand;
      if (aktuell.patzer?.id != p.id || aktuell.patzer!.kontrolle != null) {
        return;
      }
      final s = ref.read(gefechtProvider(widget.heroId));
      final snap = ref.read(heroComputedProvider(widget.heroId)).asData?.value;
      if (s == null || snap == null) throw StateError('Gefechtsstand fehlt.');
      if (!r.success) {
        final k = ref.read(rulesCatalogProvider).asData?.value;
        final w = gefechtswerteFuer(snap, katalog: k);
        ref
            .read(gefechtProvider(widget.heroId).notifier)
            .setzen(
              verbraucheGefechtsPatzer(
                s,
                w,
                const GefechtsPatzerfolge(
                  titel: 'Bestätigter Patzer',
                  iniVerlust: 0,
                ),
              ),
            );
      }
      _setzen(
        aktuell.copyWith(
          patzer: p.copyWith(kontrolle: r, erledigt: r.success),
          verloreneRunde: r.success ? aktuell.verloreneRunde : s.runde,
        ),
      );
    });
  }

  ResolvedProbeRequest _w6(String titel) => ResolvedProbeRequest(
    type: ProbeType.genericRoll,
    title: titel,
    subtitle: 'Nahkampf · WdS 84/85',
    ruleHint: 'Zwei W6 ohne zusätzliche Modifikatoren.',
    diceSpec: const DiceSpec(count: 2, sides: 6),
    targets: const [],
  );

  Future<void> _tabelle() async {
    final p = _stand.patzer;
    if (p == null || p.kontrolle?.success != false || p.tabelle != null) return;
    await _wuerfeln(_w6('Patzertabelle'), (r) {
      if (_stand.patzer?.id == p.id && _stand.patzer!.tabelle == null) {
        _setzen(
          _stand.copyWith(
            patzer: p.copyWith(tabelle: gefechtsPatzerW6Summe(r)),
          ),
        );
      }
    });
  }

  Future<void> _bruchWurf() async {
    final b = _stand.bruch;
    if (b == null || b.wurf != null || b.erledigt) return;
    await _wuerfeln(_w6('Bruchtest'), (r) {
      if (identical(_stand.bruch, b)) {
        _setzen(
          _stand.copyWith(bruch: b.copyWith(wurf: gefechtsPatzerW6Summe(r))),
        );
      }
    });
  }

  Future<void> _bruchAbschluss() async {
    final b = _stand.bruch;
    if (b == null || b.wurf == null || b.erledigt) return;
    final ergebnis = werteGefechtsBruchtest(
      b.profil.bf,
      b.wurf!,
      kritisch: b.kritisch,
    );
    final ok = await widget.bestand().gefechtsAusruestung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      aenderung: (c) => schreibeGefechtsBruchfaktor(c, b.profil, ergebnis.bf),
    );
    if (!ok) {
      throw StateError('Speichern fehlgeschlagen; der Wurf bleibt erhalten.');
    }
    if (!identical(_stand.bruch, b)) return;
    _setzen(
      _stand.copyWith(
        bruch: b.copyWith(erledigt: true),
        gesperrteMittel: {
          ..._stand.gesperrteMittel,
          if (ergebnis.zerbrochen)
            gefechtsMittelSchluessel(b.profil.wahl):
                '${b.profil.name} zerbrochen',
        },
      ),
    );
  }

  Future<void> _neuBestaetigen() async {
    final b = _stand.bruch;
    final snap = ref.read(heroComputedProvider(widget.heroId)).asData?.value;
    if (b == null || snap == null) return;
    final p = gefechtsBruchprofil(snap.hero.combatConfig, b.profil.wahl);
    if (p == null) throw StateError('Gewählter Inventareintrag fehlt.');
    final bestaetigt = await _frage(
      'Aktuellen Stand bestätigen',
      '${p.name}: BF ${p.bf}. Vorhandener Wurf ${b.wurf} wird mit diesem Profil '
          'ausgewertet. Unzerstörbarkeit und Sondermaterial sind am Tisch zu klären.',
    );
    if (bestaetigt) _setzen(_stand.copyWith(bruch: b.copyWith(profil: p)));
  }

  // Spieler bestätigt den tatsächlichen Anlass und das konkrete betroffene Mittel.
  Future<void> _bruchAnlass() async {
    final p = await _mittelWaehlen();
    if (p == null || !mounted) return;
    final kritisch = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tatsächlicher Bruchtestanlass'),
        content: Text(
          '${p.name}, BF ${p.bf}. Welche Belastung wurde am Tisch '
          'festgestellt? Bei Abwehr zunächst der Verteidiger; nur bei intakter '
          'Verteidigerwaffe anschließend der Angreifer. Sondermaterial/Unzerstörbarkeit manuell klären. '
          'Eigentreffer, Wunden und Umgebungsfolgen werden mit konkreten '
          'Tischangaben übernommen; keine automatische Waffenlöschung.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kritischer Treffer abgewehrt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ansage ≥10 / Schildspalter / Waffe zerbrechen'),
          ),
        ],
      ),
    );
    if (kritisch != null) {
      _setzen(
        _stand.copyWith(
          bruch: GefechtsBruchauftrag(profil: p, kritisch: kritisch),
        ),
      );
    }
  }

  Future<GefechtsBruchprofil?> _mittelWaehlen() async {
    final snap = ref.read(heroComputedProvider(widget.heroId)).asData?.value;
    if (snap == null) return null;
    final c = snap.hero.combatConfig;
    final mittel = <GefechtsKampfmittelwahl>[
      for (final w in c.weaponSlots)
        if (w.id.isNotEmpty && w.name.isNotEmpty)
          GefechtsKampfmittelwahl(GefechtsKampfmittelArt.hauptwaffe, w.id),
      for (final w in c.offhandEquipment)
        if (w.id.isNotEmpty && w.name.isNotEmpty)
          GefechtsKampfmittelwahl(
            w.type == OffhandEquipmentType.shield
                ? GefechtsKampfmittelArt.schild
                : GefechtsKampfmittelArt.parierwaffe,
            w.id,
          ),
    ];
    return showDialog<GefechtsBruchprofil>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Betroffenes Kampfmittel wählen'),
        children: [
          for (final w in mittel)
            if (gefechtsBruchprofil(c, w) case final p?)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p),
                child: Text('${p.name} · ${w.id} · BF ${p.bf}'),
              ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Future<bool> _frage(String titel, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(titel),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bestätigen'),
            ),
          ],
        ),
      ) ??
      false;

  // Situative Sonderfolgen werden ausdrücklich geklärt, nicht aus Namen geraten.
  Future<void> _patzerAbschluss() async {
    final p = _stand.patzer;
    final snap = ref.read(heroComputedProvider(widget.heroId)).asData?.value;
    if (p == null || p.tabelle == null || p.erledigt || snap == null) return;
    var profil = p.profil;
    var natuerlich = false;
    if (profil == null) {
      natuerlich = await _frage(
        'Natürliche Waffe?',
        'Wurde die Probe mit Faust oder Fuß ausgeführt? Bestätigen für natürliche '
            'Waffe; Abbrechen führt zur Auswahl des konkreten Waffen-/Schild-Eintrags.',
      );
      if (!natuerlich) profil = await _mittelWaehlen();
      if (!natuerlich && profil == null) return;
      if (profil != null) {
        _setzen(_stand.copyWith(patzer: p.copyWith(profil: profil)));
      }
    }
    var folge = gefechtsPatzerfolge(
      p.tabelle!,
      bf: profil?.bf ?? 0,
      natuerlich: natuerlich,
    );
    if (p.tabelle == 2 && !natuerlich && profil != null && profil.bf <= 0) {
      final unzerstoerbar = await _frage(
        'Unzerstörbare Waffe?',
        'Ist dieses konkrete Waffenprofil regeltechnisch wirklich unzerstörbar? '
            'Nur dann bleibt BF unverändert; ansonsten steigt BF um 2. '
            'Der Waffenverlust und INI −4 gelten weiterhin.',
      );
      folge = gefechtsPatzerfolge(
        p.tabelle!,
        bf: profil.bf,
        unzerstoerbar: unzerstoerbar,
      );
    }
    if (folge.sturz) {
      final abgewendet = await _frage(
        'Sturz durch GE-Probe abgewendet?',
        'Nur bei Standfest (+2), Balance (+0) oder Herausragender Balance (−4), '
            'jeweils zusätzlich BE: Ist diese konkrete GE-Probe am Tisch gelungen? '
            'Abbrechen übernimmt den Sturz.',
      );
      folge = gefechtsPatzerfolge(
        p.tabelle!,
        bf: profil?.bf ?? 0,
        natuerlich: natuerlich,
        sturzAbgewendet: abgewendet,
      );
    }
    if (folge.schadensFaktor > 0 &&
        !await _frage(
          'Eigentreffer abschließen',
          'Waffen-TP ohne KK- und Ansagebonus, Faktor ${folge.schadensFaktor}. '
              'Rüstung und Wunden hängen vom konkreten Treffer ab. Sind Schaden und '
              'gegebenenfalls Wunden am Tisch bestimmt und in der Heldenverwaltung erfasst?',
        )) {
      return;
    }
    if (!mounted) return;
    if (profil != null) {
      final gewaehlt = profil;
      final bf = gefechtsPatzerBruchfaktor(profil, folge);
      final ok = await widget.bestand().gefechtsAusruestung(
        context: context,
        ref: ref,
        heroId: widget.heroId,
        aenderung: (c) => schreibeGefechtsBruchfaktor(c, gewaehlt, bf),
      );
      if (!ok) {
        throw StateError('BF nicht gespeichert; Tabellenwurf bleibt erhalten.');
      }
    }
    final s = ref.read(gefechtProvider(widget.heroId));
    if (s == null || s.auftrag != null || _stand.patzer?.id != p.id) return;
    final k = ref.read(rulesCatalogProvider).asData?.value;
    final w = gefechtswerteFuer(snap, katalog: k);
    ref
        .read(gefechtProvider(widget.heroId).notifier)
        .setzen(verbraucheGefechtsPatzer(s, w, folge));
    _setzen(
      _stand.copyWith(
        patzer: p.copyWith(profil: profil, erledigt: true),
        verloreneMittel: {
          ..._stand.verloreneMittel,
          if (profil != null && folge.waffeVerloren)
            gefechtsMittelSchluessel(profil.wahl),
        },
        gesperrteMittel: {
          ..._stand.gesperrteMittel,
          if (profil != null && (folge.zerbrochen || folge.waffeVerloren))
            gefechtsMittelSchluessel(
              profil.wahl,
            ): '${profil.name} ${folge.zerbrochen ? "zerbrochen" : "verloren; Wiederaufnahme manuell klären"}',
        },
      ),
    );
  }

  // Neue Bestätigung ist ausdrücklich sichtbar; ein eingefrorener Wurf bleibt.
  Future<void> _patzerNeuBestaetigen() async {
    final p = _stand.patzer;
    final snap = ref.read(heroComputedProvider(widget.heroId)).asData?.value;
    if (p?.profil == null || snap == null) return;
    final frisch = gefechtsBruchprofil(snap.hero.combatConfig, p!.profil!.wahl);
    if (frisch == null) throw StateError('Betroffene Waffen-ID fehlt.');
    final ok = await _frage(
      'Patzer-Waffenprofil bestätigen',
      '${frisch.name}, BF ${frisch.bf}. Der unveränderte Tabellenwurf '
          '${p.tabelle} wird mit diesem bestätigten Profil abgeschlossen.',
    );
    if (ok) _setzen(_stand.copyWith(patzer: p.copyWith(profil: frisch)));
  }

  // Die gesonderte Position-/GE-Tischhandlung wird konkret bestätigt.
  Future<void> _wiederaufnahme(String key) async {
    final ok = await _frage(
      'Verlorene Waffe wieder aufnehmen',
      'Wurde in dieser Runde eine Aktion Position tatsächlich bezahlt und '
          'die erforderliche GE-Probe am Tisch bestanden? Nur diese konkrete '
          'Wiederaufnahme gibt $key frei. Zerbrochene Waffen bleiben gesperrt.',
    );
    if (ok) _setzen(bestaetigeGefechtsWiederaufnahme(_stand, key));
  }
}
