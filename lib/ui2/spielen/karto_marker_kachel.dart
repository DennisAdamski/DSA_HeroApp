import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_marker.dart';
import 'package:dsa_heldenverwaltung/rules/derived/zustandsmarker_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_held_schreiben.dart'
    show schreibFehlerText;
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Kachel „Zustandsmarker“ der Spielansicht (SPIEL-03).
///
/// Freie Marker wie „Betäubung“, „Furcht“ oder „Schmerz“ mit optionaler
/// Dauer in Runden. Sie sind eine Merkhilfe **ohne Regelwirkung**: kein Marker
/// ändert Werte oder Proben, und ein abgelaufener Marker bleibt stehen, bis
/// er entfernt wird. „Nächste Runde“ zählt die Dauer aller laufenden Marker
/// um eins herunter; einen persistenten Rundenzähler gibt es bewusst nicht
/// (das Gefecht führt seine Runden flüchtig).
///
/// Jede Änderung schreibt **frisch** den Laufzeitzustand
/// (`HeroActions.updateHeroState`) und ersetzt nur die Markerliste; die
/// Schritte rechnen vom gespeicherten Wert aus (`zustandsmarker_rules.dart`),
/// deshalb zählt auch ein schneller Doppelklick. Eine offene Planung sperrt
/// den Zustand nicht. Die Kachel rechnet nichts selbst.
class KartoMarkerKachel extends ConsumerStatefulWidget {
  /// Erstellt die Kachel für den Helden [heroId] mit den gespeicherten
  /// [marker]n.
  const KartoMarkerKachel({
    super.key,
    required this.heroId,
    required this.marker,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Gespeicherte Marker des Laufzeitzustands.
  final List<ZustandsMarker> marker;

  @override
  ConsumerState<KartoMarkerKachel> createState() => _KartoMarkerKachelState();
}

class _KartoMarkerKachelState extends ConsumerState<KartoMarkerKachel> {
  String? _fehler;

  Future<void> _schreibe(
    HeroState Function(HeroState aktuell) aenderung,
  ) async {
    setState(() => _fehler = null);
    try {
      await ref
          .read(heroActionsProvider)
          .updateHeroState(widget.heroId, aenderung);
    } catch (error) {
      if (mounted) setState(() => _fehler = schreibFehlerText(error));
    }
  }

  Future<void> _neu() async {
    final eingabe = await showDialog<_MarkerEingabe>(
      context: context,
      builder: (_) => const _MarkerDialog(),
    );
    if (eingabe == null) return;
    final id = const Uuid().v4();
    await _schreibe(
      (z) => mitMarkerHinzu(
        z,
        id: id,
        name: eingabe.name,
        dauer: eingabe.dauer,
        notiz: eingabe.notiz,
      ),
    );
  }

  Future<void> _aendern(ZustandsMarker marker) async {
    final eingabe = await showDialog<_MarkerEingabe>(
      context: context,
      builder: (_) => _MarkerDialog(marker: marker),
    );
    if (eingabe == null) return;
    await _schreibe(
      (z) => mitMarkerGeaendert(
        z,
        id: marker.id,
        name: eingabe.name,
        dauer: eingabe.dauer,
        notiz: eingabe.notiz,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final marker = widget.marker;
    final laufend = marker.where((m) => (m.rest ?? 0) > 0).length;
    final weit = KartoKachelSteuerung.istWeit(context);

    final zeilen = <Widget>[
      for (final m in marker)
        _MarkerZeile(
          key: ValueKey<String>('karto-marker-${m.id}'),
          marker: m,
          onAendern: () => _aendern(m),
          onSchritt: (delta) =>
              _schreibe((z) => mitMarkerSchritt(z, m.id, delta)),
          onEntfernen: () => _schreibe((z) => ohneMarker(z, m.id)),
        ),
    ];

    return KartoAbschnitt(
      titel: 'Zustandsmarker',
      symbol: Icons.push_pin_outlined,
      dicht: true,
      // Wrap statt Row: schmal und mit großer Schrift passen beide Knöpfe
      // nicht nebeneinander.
      aktion: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (laufend > 0)
            TextButton(
              key: const ValueKey<String>('karto-marker-runde'),
              onPressed: () => _schreibe(mitNaechsterMarkerRunde),
              child: const Text('Nächste Runde'),
            ),
          TextButton(
            key: const ValueKey<String>('karto-marker-neu'),
            onPressed: _neu,
            child: const Text('Neuer Marker'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (marker.isEmpty)
            Text(
              'Keine Marker. Betäubung, Furcht oder Schmerz lassen sich hier '
              'als Merkhilfe festhalten, optional mit Dauer in Runden.',
              key: const ValueKey<String>('karto-marker-leer'),
              style: texte.fliess.copyWith(color: karto.schriftLeise),
            )
          else if (weit)
            LayoutBuilder(
              builder: (context, constraints) {
                final breite = (constraints.maxWidth - Abstand.bahn) / 2;
                return Wrap(
                  spacing: Abstand.bahn,
                  children: [
                    for (final zeile in zeilen)
                      SizedBox(width: breite, child: zeile),
                  ],
                );
              },
            )
          else
            ...zeilen,
          if (marker.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Abstand.eng),
              child: Text(
                'Merkhilfe ohne Regelwirkung. Abgelaufene Marker bleiben '
                'stehen, bis du sie entfernst.',
                style: texte.etikett.copyWith(color: karto.schriftStumm),
              ),
            ),
          if (_fehler != null) ...[
            const SizedBox(height: Abstand.normal),
            Text(
              _fehler!,
              key: const ValueKey<String>('karto-marker-fehler'),
              style: texte.etikett.copyWith(color: karto.siegel),
            ),
          ],
        ],
      ),
    );
  }
}

/// Zeile eines Markers: Name und Notiz, Dauer mit − und +, Entfernen.
class _MarkerZeile extends StatelessWidget {
  const _MarkerZeile({
    super.key,
    required this.marker,
    required this.onAendern,
    required this.onSchritt,
    required this.onEntfernen,
  });

  final ZustandsMarker marker;
  final VoidCallback onAendern;
  final void Function(int delta) onSchritt;
  final VoidCallback onEntfernen;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final dauer = zustandsmarkerDauerText(marker);
    final abgelaufen = marker.istAbgelaufen;
    final id = marker.id;
    final name = Tooltip(
      message: '${marker.name} bearbeiten',
      child: InkWell(
        key: ValueKey<String>('karto-marker-$id-aendern'),
        onTap: onAendern,
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                marker.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: texte.fliess.copyWith(
                  color: abgelaufen ? karto.schriftStumm : karto.schrift,
                ),
              ),
              if (marker.notiz.isNotEmpty)
                Text(
                  marker.notiz,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: texte.etikett.copyWith(color: karto.schriftLeise),
                ),
            ],
          ),
        ),
      ),
    );
    final schritt = dauer == null
        ? null
        : _DauerSchritt(
            schluessel: 'karto-marker-$id',
            text: dauer,
            abgelaufen: abgelaufen,
            name: marker.name,
            onMinus: abgelaufen ? null : () => onSchritt(-1),
            onPlus: () => onSchritt(1),
          );
    final entfernen = Tooltip(
      message: '${marker.name} entfernen',
      child: InkWell(
        key: ValueKey<String>('karto-marker-$id-entfernen'),
        onTap: onEntfernen,
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.close, size: 18, color: karto.schriftLeise),
        ),
      ),
    );
    final skala = MediaQuery.textScalerOf(context).scale(16) / 16;
    return Padding(
      padding: const EdgeInsets.only(top: Abstand.eng),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Schmal oder mit großer Schrift bleibt dem Namen neben den Knöpfen
          // zu wenig Platz: Die Dauer rückt dann in eine eigene Zeile.
          final schrittBreite = dauer == null
              ? 0.0
              : 80 + (dauer.length * 9.0 * skala).clamp(64.0, 400.0);
          final eng = constraints.maxWidth - schrittBreite - 40 < 100;
          if (eng && schritt != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: name),
                    entfernen,
                  ],
                ),
                Align(alignment: Alignment.centerRight, child: schritt),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: name),
              ?schritt,
              entfernen,
            ],
          );
        },
      ),
    );
  }
}

/// − Dauer + für einen Marker.
class _DauerSchritt extends StatelessWidget {
  const _DauerSchritt({
    required this.schluessel,
    required this.text,
    required this.abgelaufen,
    required this.name,
    required this.onMinus,
    required this.onPlus,
  });

  final String schluessel;
  final String text;
  final bool abgelaufen;
  final String name;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Knopf(
          key: ValueKey<String>('$schluessel-minus'),
          zeichen: '−',
          tipp: '$name: 1 Runde weniger',
          onTap: onMinus,
        ),
        // Bei großer Schrift auf schmaler Kachel schrumpft der Text, statt die
        // Knöpfe aus der Zeile zu schieben.
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                key: ValueKey<String>('$schluessel-dauer'),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: texte.wert.copyWith(
                  color: abgelaufen ? karto.siegel : karto.schrift,
                ),
              ),
            ),
          ),
        ),
        _Knopf(
          key: ValueKey<String>('$schluessel-plus'),
          zeichen: '+',
          tipp: '$name: 1 Runde mehr',
          onTap: onPlus,
        ),
      ],
    );
  }
}

/// Tippziel von mindestens 40 × 40 dp; ohne [onTap] gedämpft und stumm.
class _Knopf extends StatelessWidget {
  const _Knopf({
    super.key,
    required this.zeichen,
    required this.tipp,
    required this.onTap,
  });

  final String zeichen;
  final String tipp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return Tooltip(
      message: tipp,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              zeichen,
              style: texte.wert.copyWith(
                color: onTap == null ? karto.schriftStumm : karto.schrift,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Eingabe des Dialogs: Name, optionale Dauer und Notiz.
class _MarkerEingabe {
  const _MarkerEingabe({required this.name, this.dauer, this.notiz = ''});

  final String name;
  final int? dauer;
  final String notiz;
}

/// Dialog zum Anlegen oder Ändern eines Markers.
///
/// Prüft nur die Eingabe (Name da, Dauer eine Zahl von 0 bis
/// [kZustandsmarkerDauerMax]); Kürzen und Speichern übernimmt die Regel.
class _MarkerDialog extends StatefulWidget {
  const _MarkerDialog({this.marker});

  /// Der zu ändernde Marker; ohne Angabe legt der Dialog einen neuen an.
  final ZustandsMarker? marker;

  @override
  State<_MarkerDialog> createState() => _MarkerDialogState();
}

class _MarkerDialogState extends State<_MarkerDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.marker?.name ?? '',
  );
  late final TextEditingController _dauer = TextEditingController(
    text: widget.marker?.rest?.toString() ?? '',
  );
  late final TextEditingController _notiz = TextEditingController(
    text: widget.marker?.notiz ?? '',
  );
  String? _nameFehler;
  String? _dauerFehler;

  @override
  void dispose() {
    _name.dispose();
    _dauer.dispose();
    _notiz.dispose();
    super.dispose();
  }

  void _uebernehmen() {
    final name = _name.text.trim();
    final dauerText = _dauer.text.trim();
    final dauer = dauerText.isEmpty ? null : int.tryParse(dauerText);
    final nameFehler = name.isEmpty ? 'Bitte einen Namen eingeben.' : null;
    final dauerFehler =
        dauerText.isNotEmpty &&
            (dauer == null || dauer < 0 || dauer > kZustandsmarkerDauerMax)
        ? 'Bitte eine Zahl von 0 bis $kZustandsmarkerDauerMax eingeben.'
        : null;
    if (nameFehler != null || dauerFehler != null) {
      setState(() {
        _nameFehler = nameFehler;
        _dauerFehler = dauerFehler;
      });
      return;
    }
    Navigator.of(
      context,
    ).pop(_MarkerEingabe(name: name, dauer: dauer, notiz: _notiz.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final neu = widget.marker == null;
    return AlertDialog(
      title: Text(neu ? 'Neuer Marker' : 'Marker ändern'),
      content: SizedBox(
        width: Breite.klein,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey<String>('karto-marker-name'),
                controller: _name,
                autofocus: true,
                maxLength: kZustandsmarkerNameMax,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: _nameFehler,
                  counterText: '',
                ),
                onChanged: (_) {
                  if (_nameFehler != null) setState(() => _nameFehler = null);
                },
                onSubmitted: (_) => _uebernehmen(),
              ),
              if (neu) ...[
                const SizedBox(height: Abstand.normal),
                Wrap(
                  spacing: Abstand.eng,
                  runSpacing: Abstand.eng,
                  children: [
                    for (final vorschlag in kZustandsmarkerVorschlaege)
                      ActionChip(
                        key: ValueKey<String>(
                          'karto-marker-vorschlag-$vorschlag',
                        ),
                        label: Text(vorschlag),
                        onPressed: () => setState(() {
                          _name.text = vorschlag;
                          _nameFehler = null;
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Abstand.normal),
              TextField(
                key: const ValueKey<String>('karto-marker-dauer'),
                controller: _dauer,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Dauer in Runden',
                  helperText: 'Leer lassen für einen Marker ohne Dauer.',
                  errorText: _dauerFehler,
                ),
                onChanged: (_) {
                  if (_dauerFehler != null) {
                    setState(() => _dauerFehler = null);
                  }
                },
                onSubmitted: (_) => _uebernehmen(),
              ),
              const SizedBox(height: Abstand.normal),
              TextField(
                key: const ValueKey<String>('karto-marker-notiz'),
                controller: _notiz,
                maxLength: kZustandsmarkerNotizMax,
                decoration: const InputDecoration(
                  labelText: 'Notiz (optional)',
                  counterText: '',
                ),
                onSubmitted: (_) => _uebernehmen(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-marker-speichern'),
          onPressed: _uebernehmen,
          child: Text(neu ? 'Hinzufügen' : 'Speichern'),
        ),
      ],
    );
  }
}
