import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_fernkampf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ladezustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

/// Geschossbestand einer geführten Fernkampfwaffe mit Wahl und Aufheben.
class GefechtGeschosse extends StatelessWidget {
  /// Zeigt alle Geschosse von [waffe]; das aktive ist markiert.
  const GefechtGeschosse({
    super.key,
    required this.waffe,
    required this.gesperrt,
    required this.onWaehlen,
    required this.onAufheben,
  });

  /// Angezeigte Waffe; Bedienungen reichen sie unverändert weiter.
  final MainWeaponSlot waffe;

  /// Sperrt Wahl und Aufheben, etwa während einer laufenden Handlung.
  final bool gesperrt;

  /// Wählt das Geschoss an der Position als aktives Geschoss.
  final ValueChanged<int> onWaehlen;

  /// Öffnet das Aufheben für das Geschoss an der Position.
  final ValueChanged<int> onAufheben;

  @override
  Widget build(BuildContext context) {
    final profil = waffe.rangedProfile;
    final geschosse = profil.projectiles;
    final aktiv = profil.selectedProjectileIndex;
    final legende = Theme.of(context).textTheme.bodySmall;
    return Padding(
      key: ValueKey('gefecht-geschosse-${waffe.id}'),
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Geschosse · ${waffe.name}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (geschosse.isEmpty)
            Text(
              'Keine Geschosse hinterlegt; in der Verwaltung anlegen.',
              style: legende,
            ),
          for (var i = 0; i < geschosse.length; i++)
            _zeile(context, geschosse[i], i, i == aktiv, legende),
        ],
      ),
    );
  }

  Widget _zeile(
    BuildContext context,
    RangedProjectile g,
    int i,
    bool aktiv,
    TextStyle? legende,
  ) {
    final mods = [
      if (g.atMod != 0) 'AT ${_vorzeichen(g.atMod)}',
      if (g.tpMod != 0) 'TP ${_vorzeichen(g.tpMod)}',
      if (g.iniMod != 0) 'INI ${_vorzeichen(g.iniMod)}',
    ];
    final name = g.name.trim().isEmpty ? 'Geschoss ${i + 1}' : g.name.trim();
    return Row(
      key: ValueKey('gefecht-geschoss-${waffe.id}-$i'),
      children: [
        IconButton(
          tooltip: aktiv ? 'Aktives Geschoss' : '$name verwenden',
          onPressed: gesperrt || aktiv ? null : () => onWaehlen(i),
          icon: Icon(
            aktiv ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name),
              if (mods.isNotEmpty) Text(mods.join(' · '), style: legende),
            ],
          ),
        ),
        Text(
          '${g.count} Stück',
          key: ValueKey('gefecht-geschoss-anzahl-${waffe.id}-$i'),
          style: g.count <= 0
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : null,
        ),
        const SizedBox(width: 4),
        TextButton(
          key: ValueKey('gefecht-geschoss-aufheben-${waffe.id}-$i'),
          onPressed: gesperrt ? null : () => onAufheben(i),
          child: const Text('Aufheben'),
        ),
      ],
    );
  }

  static String _vorzeichen(int w) => w > 0 ? '+$w' : '$w';
}

/// Fragt die Zahl aufgehobener Geschosse ab und bucht sie auf den Bestand.
///
/// Ein bekannter Ladezustand der Waffe bleibt erhalten, weil sich nur der
/// Bestand ändert. Fehler beim Speichern meldet die Brücke selbst.
Future<void> zeigeGefechtsGeschosseAufheben({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
  required MainWeaponSlot waffe,
  required int geschossIndex,
}) async {
  final geschoss = waffe.rangedProfile.projectiles.elementAtOrNull(
    geschossIndex,
  );
  if (geschoss == null) return;
  final anzahl = await showDialog<int>(
    context: context,
    builder: (_) => GefechtAufhebedialog(geschoss: geschoss),
  );
  if (anzahl == null || !context.mounted) return;
  await _schreibe(
    ref: ref,
    heroId: heroId,
    waffe: waffe,
    schreiben: (aenderung) => bestand.gefechtsAusruestung(
      context: context,
      ref: ref,
      heroId: heroId,
      aenderung: aenderung,
    ),
    aenderung: (config) => nimmGefechtsGeschosseAuf(
      config,
      waffe,
      geschoss,
      anzahl,
      geschossIndex: geschossIndex,
    ),
  );
}

/// Macht das Geschoss an [geschossIndex] zum aktiven Geschoss von [waffe].
Future<void> waehleGefechtsGeschoss({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
  required MainWeaponSlot waffe,
  required int geschossIndex,
}) async {
  final geschoss = waffe.rangedProfile.projectiles.elementAtOrNull(
    geschossIndex,
  );
  if (geschoss == null) return;
  await _schreibe(
    ref: ref,
    heroId: heroId,
    waffe: waffe,
    schreiben: (aenderung) => bestand.gefechtsAusruestung(
      context: context,
      ref: ref,
      heroId: heroId,
      aenderung: aenderung,
    ),
    aenderung: (config) =>
        mitGeschossWahl(config, waffe, geschoss, geschossIndex: geschossIndex),
  );
}

// Laufende Handlungen binden das Waffenprofil; dann wird nichts geschrieben.
Future<void> _schreibe({
  required WidgetRef ref,
  required String heroId,
  required MainWeaponSlot waffe,
  required Future<bool> Function(CombatConfig Function(CombatConfig)) schreiben,
  required CombatConfig Function(CombatConfig) aenderung,
}) async {
  final s = ref.read(gefechtMitInitiativeProvider(heroId));
  if (s?.handlung != null) {
    throw StateError('Laufende Handlung zuerst abschließen.');
  }
  final c = ref.read(gefechtProvider(heroId).notifier);
  final id = UniqueKey().toString();
  if (s != null && !c.reservieren(id)) return;
  try {
    MainWeaponSlot? vorher;
    MainWeaponSlot? nachher;
    final ok = await schreiben((config) {
      vorher = config.weaponSlots.where((w) => w.id == waffe.id).firstOrNull;
      final neu = aenderung(config);
      nachher = neu.weaponSlots.where((w) => w.id == waffe.id).firstOrNull;
      return neu;
    });
    c.abbrechen(id);
    final aktuell = ref.read(gefechtMitInitiativeProvider(heroId));
    if (!ok || aktuell == null || vorher == null || nachher == null) return;
    c.setzen(
      uebertrageGefechtsLadestand(aktuell, vorher: vorher!, nachher: nachher!),
    );
  } finally {
    c.abbrechen(id);
  }
}

/// Abfrage, wie viele Geschosse wieder aufgenommen werden.
class GefechtAufhebedialog extends StatefulWidget {
  /// Beginnt bei einem Geschoss; der Dialog schließt sich selbst.
  const GefechtAufhebedialog({super.key, required this.geschoss});

  /// Geschoss, dessen Bestand wächst.
  final RangedProjectile geschoss;

  @override
  State<GefechtAufhebedialog> createState() => _AufhebedialogState();
}

class _AufhebedialogState extends State<GefechtAufhebedialog> {
  final _feld = TextEditingController(text: '1');

  int get _hoechstens =>
      (kGeschossHoechstbestand - widget.geschoss.count).clamp(0, 9999);

  int? get _anzahl {
    final n = int.tryParse(_feld.text.trim());
    return n == null || n < 1 || n > _hoechstens ? null : n;
  }

  void _schritt(int delta) {
    final n = (int.tryParse(_feld.text.trim()) ?? 0) + delta;
    setState(() {
      _feld.text = '${n.clamp(1, _hoechstens < 1 ? 1 : _hoechstens)}';
    });
  }

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.geschoss;
    final anzahl = _anzahl;
    return AlertDialog(
      title: const Text('Geschosse aufheben'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${g.name.trim().isEmpty ? 'Geschoss' : g.name} · '
            'Bestand ${g.count}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Eins weniger',
                onPressed: () => _schritt(-1),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: TextField(
                  key: const ValueKey('gefecht-aufheben-anzahl'),
                  controller: _feld,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Anzahl'),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (_anzahl != null) Navigator.pop(context, _anzahl);
                  },
                ),
              ),
              IconButton(
                tooltip: 'Eins mehr',
                onPressed: () => _schritt(1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (anzahl != null) ...[
            const SizedBox(height: 8),
            Text('Danach ${g.count + anzahl} Stück.'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey('gefecht-aufheben-bestaetigen'),
          onPressed: anzahl == null
              ? null
              : () => Navigator.pop(context, anzahl),
          child: const Text('Aufheben'),
        ),
      ],
    );
  }
}

/// Geschosslisten aller geführten Fernkampfwaffen samt Schreibwegen.
class GefechtGeschossbereich extends ConsumerWidget {
  /// Bedienungen laufen über [onAktion], den Guard der Gefechtsansicht.
  const GefechtGeschossbereich({
    super.key,
    required this.werte,
    required this.heroId,
    required this.bruecke,
    required this.gesperrt,
    required this.onAktion,
  });

  /// Aktuelle Spielwerte, aus denen die geführten Waffen stammen.
  final HeroComputedSnapshot werte;

  /// Held, dessen Ausrüstung geschrieben wird.
  final String heroId;

  /// Brücke für frische Ausrüstungsänderungen; erst beim Bedienen aufgelöst.
  final KartoGefechtsAdapter Function() bruecke;

  /// Sperrt alle Bedienungen.
  final bool gesperrt;

  /// Re-Entrancy-Guard der Ansicht.
  final Future<void> Function(Future<void> Function()) onAktion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final profil in gefechtsKampfmittelprofile(werte))
          if (profil.waffe?.isRanged == true)
            GefechtGeschosse(
              waffe: profil.waffe!,
              gesperrt: gesperrt,
              onWaehlen: (i) => onAktion(
                () => waehleGefechtsGeschoss(
                  context: context,
                  ref: ref,
                  heroId: heroId,
                  bestand: bruecke(),
                  waffe: profil.waffe!,
                  geschossIndex: i,
                ),
              ),
              onAufheben: (i) => onAktion(
                () => zeigeGefechtsGeschosseAufheben(
                  context: context,
                  ref: ref,
                  heroId: heroId,
                  bestand: bruecke(),
                  waffe: profil.waffe!,
                  geschossIndex: i,
                ),
              ),
            ),
      ],
    );
  }
}
