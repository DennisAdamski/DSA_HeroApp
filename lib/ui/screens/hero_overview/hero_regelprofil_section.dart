import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_vergleich.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/rules/derived/regelprofil_vorschau_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_vorschau_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

/// Titel eines Pakets aus der Manifestkopie im Profil; ersatzweise die ID.
String regelprofilPaketTitel(HeroRegelProfilPaket paket) {
  final titel = paket.manifest['title'];
  return titel is String && titel.trim().isNotEmpty ? titel : paket.paketId;
}

/// Regelprofil des Helden in der Übersicht (ARCH-04).
///
/// Ohne Profil folgt der Held den globalen Hausregeln; die Karte bietet an,
/// diesen Stand festzuhalten. Mit Profil nennt sie die festgehaltenen Pakete
/// und zeigt, ob ein Paketupdate ansteht. Die Karte rechnet nichts: Vergleich
/// und Vorschau kommen aus `regelProfilVorschauProvider`, geschrieben wird nur
/// durch ausdrückliche Übernahme.
class HeroRegelprofilSection extends ConsumerWidget {
  /// Erstellt die Karte für [heroId].
  const HeroRegelprofilSection({super.key, required this.heroId});

  /// Held, dessen Regelprofil angezeigt wird.
  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroByIdProvider(heroId));
    if (hero == null) return const SizedBox.shrink();
    final profil = ref.watch(heroRegelProfilProvider(heroId));
    final theme = Theme.of(context);
    final leise = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final Widget inhalt;
    if (hero.regelProfil != null && profil == null) {
      inhalt = Text(
        'Das Regelprofil stammt von einer neueren App-Version und wird hier '
        'nicht verändert.',
        key: const ValueKey<String>('regelprofil-unverstanden'),
        style: leise,
      );
    } else if (profil == null) {
      inhalt = _OhneProfil(heroId: heroId);
    } else {
      inhalt = _MitProfil(heroId: heroId, profil: profil);
    }
    return CodexSectionCard(
      key: const ValueKey<String>('hero-regelprofil'),
      title: 'Regelprofil',
      child: ZustandFehlerBereich(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const ZustandFehlerAnzeige(), inhalt],
        ),
      ),
    );
  }
}

class _OhneProfil extends ConsumerWidget {
  const _OhneProfil({required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final global = ref.watch(globalesRegelProfilProvider).valueOrNull;
    final aufloesung = global == null
        ? null
        : ref.watch(regelProfilAufloesungProvider(global)).valueOrNull;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dieser Held folgt den globalen Hausregeln. Ändert sich dort ein '
          'Paket, ändern sich seine Werte mit.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey<String>('regelprofil-festhalten'),
          onPressed: global == null || aufloesung == null
              ? null
              : () => _festhalten(context, ref, global, aufloesung),
          icon: const Icon(Icons.push_pin_outlined),
          label: const Text('Aktuellen Regelstand festhalten'),
        ),
      ],
    );
  }

  Future<void> _festhalten(
    BuildContext context,
    WidgetRef ref,
    HeroRegelProfil profil,
    RegelProfilAufloesung aufloesung,
  ) async {
    final ja = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regelstand festhalten?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Der Held rechnet danach mit diesen Hausregelpaketen und '
                'ihrem heutigen Stand, auch wenn sich die Einstellungen oder '
                'die Pakete der App später ändern:',
              ),
              const SizedBox(height: 8),
              if (profil.pakete.isEmpty)
                const Text('• keine Hausregelpakete aktiv')
              else
                for (final p in profil.pakete)
                  Text('• ${regelprofilPaketTitel(p)}'),
              const SizedBox(height: 12),
              const Text(
                'Der Held wird dabei gespeichert und beim Konto-Sync als '
                'geändert gemeldet. Neue Paketstände kannst du später in einer '
                'Vorschau prüfen und bewusst übernehmen.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey<String>('regelprofil-abbrechen'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const ValueKey<String>('regelprofil-festhalten-bestaetigen'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Festhalten'),
          ),
        ],
      ),
    );
    if (ja != true || !context.mounted) return;
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: heroId,
      was: 'Regelprofil',
      aenderung: (held) => uebernehmeRegelProfil(held, von: null, auf: profil),
      validationCatalog: aufloesung.katalog,
    );
    if (gespeichert == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Regelstand festgehalten')));
  }
}

class _MitProfil extends ConsumerWidget {
  const _MitProfil({required this.heroId, required this.profil});

  final String heroId;
  final HeroRegelProfil profil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final leise = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final vorschau = ref.watch(regelProfilVorschauProvider(heroId));
    final paketKatalog = ref.watch(houseRulePackCatalogProvider).valueOrNull;
    final hatKandidaten =
        paketKatalog != null &&
        zusatzPaketKandidaten(
          profil: profil,
          aktuellerPaketKatalog: paketKatalog,
        ).isNotEmpty;
    final Widget status = vorschau.when(
      loading: () => Text('Prüfe Paketstand …', style: leise),
      error: (fehler, _) => Text(
        'Paketstand nicht prüfbar: $fehler',
        key: const ValueKey<String>('regelprofil-fehler'),
        style: TextStyle(color: theme.colorScheme.error),
      ),
      data: (v) {
        if (v == null || v.istLeer) {
          return Text(
            'Aktuell: Der Held rechnet mit dem heutigen Paketstand.',
            key: const ValueKey<String>('regelprofil-aktuell'),
            style: theme.textTheme.bodyMedium,
          );
        }
        final betroffen = v.betroffeneErworbene.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ein Paketupdate steht an: ${v.vergleich.eintraege.length} '
              'geänderte Katalogeinträge, ${v.werte.length} geänderte Werte'
              '${betroffen > 0 ? ', $betroffen erworbene Fähigkeiten betroffen' : ''}.',
              key: const ValueKey<String>('regelprofil-update'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const ValueKey<String>('regelprofil-vorschau'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => RegelprofilVorschauDialog(heroId: heroId),
              ),
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Vorschau ansehen'),
            ),
          ],
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Festgehaltene Pakete (Katalog ${profil.catalogVersion}):',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        if (profil.pakete.isEmpty)
          Text('• keine Hausregelpakete', style: theme.textTheme.bodyMedium)
        else
          for (final p in profil.pakete)
            Text(
              '• ${regelprofilPaketTitel(p)}',
              style: theme.textTheme.bodyMedium,
            ),
        const SizedBox(height: 8),
        status,
        if (hatKandidaten) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey<String>('regelprofil-pakete'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RegelprofilVorschauDialog(heroId: heroId),
            ),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Zusätzliche Pakete wählen'),
          ),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          key: const ValueKey<String>('regelprofil-loesen'),
          onPressed: () => _loesen(context, ref),
          icon: const Icon(Icons.link),
          label: const Text('Wieder den globalen Hausregeln folgen'),
        ),
      ],
    );
  }

  Future<void> _loesen(BuildContext context, WidgetRef ref) async {
    final ja = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Festgehaltenen Regelstand lösen?'),
        content: const Text(
          'Der Held folgt danach wieder den globalen Hausregeln. Ändert sich '
          'dort ein Paket, ändern sich seine Werte mit. Das festgehaltene '
          'Profil wird entfernt; der Held wird dabei gespeichert und beim '
          'Konto-Sync als geändert gemeldet.',
        ),
        actions: [
          TextButton(
            key: const ValueKey<String>('regelprofil-loesen-abbrechen'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const ValueKey<String>('regelprofil-loesen-bestaetigen'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lösen'),
          ),
        ],
      ),
    );
    if (ja != true || !context.mounted) return;
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: heroId,
      was: 'Regelprofil',
      aenderung: (held) => setzeRegelProfilZurueck(held, von: profil),
      validationCatalog: ref.read(rulesCatalogProvider).valueOrNull,
    );
    if (gespeichert == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Der Held folgt wieder den globalen Regeln'),
      ),
    );
  }
}

/// Updatevorschau des Regelprofils mit ausdrücklicher Übernahme.
///
/// Zeigt Pakethinweise, geänderte Katalogeinträge, Freischaltungen, die
/// Auswirkung auf erworbene Fähigkeiten und die Werte vorher/nachher. Der
/// Held ändert sich erst mit „Übernehmen“; Fehler erscheinen im Dialog selbst.
class RegelprofilVorschauDialog extends ConsumerStatefulWidget {
  /// Erstellt den Dialog für [heroId].
  const RegelprofilVorschauDialog({super.key, required this.heroId});

  /// Held, dessen Profil aktualisiert werden soll.
  final String heroId;

  @override
  ConsumerState<RegelprofilVorschauDialog> createState() =>
      _RegelprofilVorschauDialogState();
}

class _RegelprofilVorschauDialogState
    extends ConsumerState<RegelprofilVorschauDialog> {
  bool _laeuft = false;

  // Zusätzlich gewählte Pakete; flüchtig, geschrieben wird erst mit „Übernehmen“.
  Set<String> _zusatz = const <String>{};

  void _waehle(
    HouseRulePackManifest paket,
    bool an,
    HeroRegelProfil profil,
    HouseRulePackCatalog katalog,
  ) {
    setState(() {
      _zusatz = an
          ? zusatzPaketeMitElternpaketen(
              gewaehlt: {..._zusatz, paket.id},
              profil: profil,
              aktuellerPaketKatalog: katalog,
            )
          : zusatzPaketAbwaehlen(
              gewaehlt: _zusatz,
              paketId: paket.id,
              aktuellerPaketKatalog: katalog,
            );
    });
  }

  Future<void> _uebernehmen(RegelProfilVorschau v) async {
    setState(() => _laeuft = true);
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Regelprofil',
      aenderung: (held) => uebernehmeRegelProfil(held, von: v.von, auf: v.auf),
      validationCatalog: v.vergleich.neu.katalog,
    );
    if (!mounted) return;
    setState(() => _laeuft = false);
    if (gespeichert != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vorschau = ref.watch(
      regelProfilVorschauMitZusatzProvider((
        heroId: widget.heroId,
        zusatz: zusatzPaketSchluessel(_zusatz),
      )),
    );
    final v = vorschau.valueOrNull;
    final profil = ref.watch(heroRegelProfilProvider(widget.heroId));
    final paketKatalog = ref.watch(houseRulePackCatalogProvider).valueOrNull;
    final kandidaten = profil == null || paketKatalog == null
        ? const <HouseRulePackManifest>[]
        : zusatzPaketKandidaten(
            profil: profil,
            aktuellerPaketKatalog: paketKatalog,
          );
    return ZustandFehlerBereich(
      child: AlertDialog(
        title: const Text('Regelprofil aktualisieren'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const ZustandFehlerAnzeige(),
                if (kandidaten.isNotEmpty &&
                    profil != null &&
                    paketKatalog != null)
                  _ZusatzPakete(
                    kandidaten: kandidaten,
                    gewaehlt: _zusatz,
                    onChanged: _laeuft
                        ? null
                        : (paket, an) =>
                              _waehle(paket, an, profil, paketKatalog),
                  ),
                if (v != null)
                  _VorschauInhalt(vorschau: v)
                else
                  Text(
                    vorschau.isLoading
                        ? 'Prüfe Paketstand …'
                        : 'Keine Änderungen vorhanden.',
                    key: const ValueKey<String>('regelprofil-dialog-status'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey<String>('regelprofil-schliessen'),
            onPressed: _laeuft ? null : () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
          if (v != null)
            FilledButton(
              key: const ValueKey<String>('regelprofil-uebernehmen'),
              onPressed: _laeuft || !v.uebernehmbar
                  ? null
                  : () => _uebernehmen(v),
              child: const Text('Übernehmen'),
            ),
        ],
      ),
    );
  }
}

class _ZusatzPakete extends StatelessWidget {
  const _ZusatzPakete({
    required this.kandidaten,
    required this.gewaehlt,
    required this.onChanged,
  });

  final List<HouseRulePackManifest> kandidaten;
  final Set<String> gewaehlt;
  final void Function(HouseRulePackManifest paket, bool an)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        key: const ValueKey<String>('regelprofil-zusatz'),
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: gewaehlt.isNotEmpty,
        title: Text(
          gewaehlt.isEmpty
              ? 'Zusätzliche Pakete'
              : 'Zusätzliche Pakete (${gewaehlt.length} gewählt)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: const Text(
          'Neue Pakete kommen nie von selbst hinzu. Die Auswahl wirkt erst '
          'mit „Übernehmen“.',
        ),
        children: [
          for (final paket in kandidaten)
            CheckboxListTile(
              key: ValueKey<String>('regelprofil-zusatz-${paket.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: gewaehlt.contains(paket.id),
              onChanged: onChanged == null
                  ? null
                  : (an) => onChanged!(paket, an ?? false),
              title: Text(paket.title),
              subtitle: paket.description.trim().isEmpty
                  ? null
                  : Text(paket.description),
            ),
        ],
      ),
    );
  }
}

class _VorschauInhalt extends StatelessWidget {
  const _VorschauInhalt({required this.vorschau});

  final RegelProfilVorschau vorschau;

  static String _wert(Object? wert) => wert == null ? '–' : '$wert';

  static String _auswirkung(ErworbenAuswirkung a) => switch (a) {
    ErworbenAuswirkung.nichtErworben => 'nicht erworben',
    ErworbenAuswirkung.unveraendert => 'bleibt erfüllt',
    ErworbenAuswirkung.neuOffen => 'Voraussetzung danach nicht mehr erfüllt',
    ErworbenAuswirkung.nichtMehrOffen => 'Voraussetzung danach erfüllt',
    ErworbenAuswirkung.entfallen => 'fällt aus dem Katalog weg',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titel = theme.textTheme.titleSmall;
    final leise = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final vergleich = vorschau.vergleich;
    final erworbene = vorschau.voraussetzungen
        .where((e) => e.erworben)
        .toList(growable: false);
    Widget abschnitt(String ueberschrift, List<Widget> kinder) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ueberschrift, style: titel),
          const SizedBox(height: 4),
          ...kinder,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Der Held rechnet noch mit dem festgehaltenen Stand. Erst „Übernehmen“ '
          'stellt ihn auf den aktuellen Paketstand um.',
          style: leise,
        ),
        const SizedBox(height: 12),
        if (vergleich.hinweise.isNotEmpty)
          abschnitt('Pakete', [
            for (final h in vergleich.hinweise) Text('• ${h.text}'),
          ]),
        if (erworbene.isNotEmpty)
          abschnitt('Erworbene Fähigkeiten', [
            for (final e in erworbene)
              Text(
                '• ${e.name}: ${_auswirkung(e.auswirkung)}',
                key: ValueKey<String>('regelprofil-erworben-${e.id}'),
                style:
                    e.auswirkung == ErworbenAuswirkung.neuOffen ||
                        e.auswirkung == ErworbenAuswirkung.entfallen
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
          ]),
        if (vorschau.werte.isNotEmpty)
          abschnitt('Werte', [
            for (final w in vorschau.werte)
              Text(
                '• ${w.titel}: ${w.vorher?.ergebnisText ?? '–'} → '
                '${w.nachher?.ergebnisText ?? '–'}',
              ),
          ]),
        if (vergleich.eintraege.isNotEmpty)
          abschnitt('Katalogeinträge', [
            for (final e in vergleich.eintraege)
              _EintragZeile(eintrag: e, vergleich: vergleich),
          ]),
        if (vergleich.sperren.isNotEmpty)
          abschnitt('Ein- und Ausblendungen', [
            for (final s in vergleich.sperren)
              Text(
                '• ${s.section.displayName}: ${s.name} '
                '${s.nachherSichtbar ? 'wird sichtbar' : 'wird ausgeblendet'}',
              ),
          ]),
        if (vorschau.werte.isEmpty &&
            vergleich.eintraege.isEmpty &&
            vergleich.sperren.isEmpty &&
            erworbene.isEmpty)
          const Text('Keine Auswirkung auf Werte oder Katalogeinträge.'),
      ],
    );
  }
}

class _EintragZeile extends StatelessWidget {
  const _EintragZeile({required this.eintrag, required this.vergleich});

  final EintragsAenderung eintrag;
  final RegelProfilVergleich vergleich;

  String _paket(String paketId) {
    if (paketId.isEmpty) return '';
    final neu = vergleich.neu.runtimeData.packCatalog.find(paketId)?.title;
    final alt = vergleich.alt.runtimeData.packCatalog.find(paketId)?.title;
    return ' (${neu ?? alt ?? paketId})';
  }

  @override
  Widget build(BuildContext context) {
    final art = switch (eintrag.art) {
      EintragsAenderungsart.neu => 'neu',
      EintragsAenderungsart.entfernt => 'entfällt',
      EintragsAenderungsart.geaendert => 'geändert',
    };
    final text = '${eintrag.section.displayName}: ${eintrag.name} · $art';
    if (eintrag.felder.isEmpty) return Text('• $text');
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      dense: true,
      title: Text(text),
      children: [
        for (final f in eintrag.felder)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                '${f.pfad}: ${_VorschauInhalt._wert(f.vorher)} → '
                '${_VorschauInhalt._wert(f.nachher)}${_paket(f.paketId)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}
