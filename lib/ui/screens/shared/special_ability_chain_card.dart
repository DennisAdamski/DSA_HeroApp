import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/cost_text_parsing.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_chain_rules.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/requirement_checklist.dart';

/// Zeigt eine Stufenkette aufeinander aufbauender Sonderfertigkeiten als eine
/// Karte statt als lose Einzeleintraege.
///
/// Die Stufenreihe macht auf einen Blick sichtbar, wo der Held steht: erworbene
/// Stufen sind gefuellt, die naechste ist hervorgehoben, spaetere bleiben
/// blass. Darunter stehen nur die noch offenen Voraussetzungen der naechsten
/// Stufe — die bereits erfuellten kosten in der Uebersicht nur Platz und stehen
/// vollstaendig im Detaildialog.
class SpecialAbilityChainCard<T extends SpecialAbilityEntry>
    extends StatelessWidget {
  /// Erzeugt die Kettenkarte.
  const SpecialAbilityChainCard({
    super.key,
    required this.kette,
    required this.erworbeneStufe,
    required this.onErwerben,
    required this.onDetails,
    this.offeneVoraussetzungenDerNaechstenStufe =
        const <RequirementCheckResult>[],
  });

  /// Die dargestellte Kette.
  final SpecialAbilityChain<T> kette;

  /// Hoechste bereits erworbene Stufe; `0`, wenn noch keine.
  final int erworbeneStufe;

  /// Wird mit der zu erwerbenden Stufe aufgerufen.
  final ValueChanged<T> onErwerben;

  /// Oeffnet den Detaildialog einer Stufe.
  final ValueChanged<T> onDetails;

  /// Offene Voraussetzungen der naechsten Stufe.
  final List<RequirementCheckResult> offeneVoraussetzungenDerNaechstenStufe;

  /// Die naechste noch nicht erworbene Stufe.
  T? get _naechsteStufe => naechsteKettenstufe(kette, _erworbeneNamen);

  /// Rekonstruiert aus [erworbeneStufe] die Namen der erworbenen Stufen.
  ///
  /// Die Karte bekommt bewusst nur die Stufenzahl statt der Namensliste — das
  /// haelt die Schnittstelle klein, und die Zuordnung Stufe → Eintrag steht
  /// ohnehin in der Kette.
  List<String> get _erworbeneNamen => kette.stufen
      .where((def) => (def.kette?.stufe ?? 0) <= erworbeneStufe)
      .map((def) => def.name)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final naechste = _naechsteStufe;
    final gesperrt = offeneVoraussetzungenDerNaechstenStufe.isNotEmpty;

    return Card(
      key: ValueKey<String>('sf-chain-${kette.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    kette.label,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (erworbeneStufe > 0)
                  Text(
                    'Stufe ${_roemisch(erworbeneStufe)} von '
                    '${_roemisch(kette.stufen.length)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _StufenReihe<T>(
              kette: kette,
              erworbeneStufe: erworbeneStufe,
              naechsteStufe: naechste,
              gesperrt: gesperrt,
              onDetails: onDetails,
            ),
            if (naechste != null) ...[
              const SizedBox(height: 10),
              if (gesperrt) ...[
                RequirementChecklist(
                  ergebnisse: offeneVoraussetzungenDerNaechstenStufe,
                  titel: '',
                  dicht: true,
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: ValueKey<String>('sf-chain-acquire-${naechste.id}'),
                  onPressed: () => onErwerben(naechste),
                  icon: Icon(gesperrt ? Icons.lock_outline : Icons.add),
                  label: Text(
                    '${_kurzName(naechste)} erwerben'
                    '${_apSuffix(naechste)}',
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Alle Stufen erworben.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Die waagerechte Stufenreihe mit verbindenden Strichen.
class _StufenReihe<T extends SpecialAbilityEntry> extends StatelessWidget {
  const _StufenReihe({
    required this.kette,
    required this.erworbeneStufe,
    required this.naechsteStufe,
    required this.gesperrt,
    required this.onDetails,
  });

  final SpecialAbilityChain<T> kette;
  final int erworbeneStufe;
  final T? naechsteStufe;
  final bool gesperrt;
  final ValueChanged<T> onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kinder = <Widget>[];
    for (var index = 0; index < kette.stufen.length; index++) {
      final def = kette.stufen[index];
      final stufe = def.kette?.stufe ?? index + 1;
      final erworben = stufe <= erworbeneStufe;
      final istNaechste = naechsteStufe?.id == def.id;
      if (index > 0) {
        kinder.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: 16,
              child: Divider(
                thickness: 2,
                color: erworben
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
          ),
        );
      }
      kinder.add(
        _StufenMarke(
          label: _roemisch(stufe),
          tooltip: '${def.name}${_apSuffix(def)}',
          erworben: erworben,
          istNaechste: istNaechste,
          gesperrt: istNaechste && gesperrt,
          onTap: () => onDetails(def),
        ),
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: kinder,
    );
  }
}

/// Ein einzelner Stufenpunkt.
class _StufenMarke extends StatelessWidget {
  const _StufenMarke({
    required this.label,
    required this.tooltip,
    required this.erworben,
    required this.istNaechste,
    required this.gesperrt,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool erworben;
  final bool istNaechste;
  final bool gesperrt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color hintergrund;
    final Color rand;
    final Color schrift;
    if (erworben) {
      hintergrund = colorScheme.primary;
      rand = colorScheme.primary;
      schrift = colorScheme.onPrimary;
    } else if (istNaechste) {
      hintergrund = colorScheme.surface;
      rand = gesperrt ? colorScheme.error : colorScheme.primary;
      schrift = gesperrt ? colorScheme.error : colorScheme.primary;
    } else {
      hintergrund = colorScheme.surface;
      rand = colorScheme.outlineVariant;
      schrift = colorScheme.onSurfaceVariant;
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hintergrund,
            shape: BoxShape.circle,
            border: Border.all(color: rand, width: 2),
          ),
          child: gesperrt
              ? Icon(Icons.lock_outline, size: 16, color: schrift)
              : Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: schrift,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Kuerzt den Stufennamen um das Ketten-Label: aus `Eiserner Wille II` wird
/// innerhalb der Karte `Stufe II`.
String _kurzName(SpecialAbilityEntry def) {
  final stufe = def.kette?.stufe;
  if (stufe == null) {
    return def.name;
  }
  return 'Stufe ${_roemisch(stufe)}';
}

/// `  ·  200 AP`, sofern sich aus dem Kostentext ein Betrag lesen laesst.
String _apSuffix(SpecialAbilityEntry def) {
  final ap = parseLeadingApAmount(def.kosten);
  return ap == null ? '' : ' · $ap AP';
}

const List<String> _roemischeZahlen = <String>[
  '',
  'I',
  'II',
  'III',
  'IV',
  'V',
  'VI',
  'VII',
];

String _roemisch(int wert) => wert > 0 && wert < _roemischeZahlen.length
    ? _roemischeZahlen[wert]
    : '$wert';
