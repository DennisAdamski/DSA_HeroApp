import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_proben_favorit.dart';
import 'package:dsa_heldenverwaltung/rules/derived/proben_favoriten_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/probe_quick_search.dart';

/// Die häufigen Proben des Helden als antippbare Liste (ARCH-01).
///
/// Ein Tipp würfelt die Probe über denselben Weg wie die Probensuche
/// ([showLoggedProbeDialog]); Ziel, Wert und Herleitung entstehen aus den
/// Kandidaten der Suche ([beobachteProbeKandidaten]), nie aus gespeicherten
/// Zahlen. Verwalten (Reihenfolge, Entfernen) schreibt frisch nur
/// `probenFavoriten` über [aendereHeldMitMeldung].
///
/// Favoriten, die sich nicht mehr auflösen lassen (Zauber verlernt, Talent
/// nicht im Katalog), bleiben gespeichert, erscheinen aber nur als Hinweis mit
/// der Möglichkeit, sie zu entfernen.
class ProbenFavoritenListe extends ConsumerWidget {
  /// Erzeugt die Liste für einen Helden.
  const ProbenFavoritenListe({super.key, required this.heroId});

  /// Held, dessen häufige Proben gezeigt werden.
  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroByIdProvider(heroId));
    final kandidaten = beobachteProbeKandidaten(ref, heroId);
    if (hero == null) return const SizedBox.shrink();
    final favoriten = hero.probenFavoriten;
    if (favoriten.isEmpty) {
      return const _Hinweis(
        text:
            'Noch keine häufigen Proben. Markiere in der Probensuche eine '
            'Probe mit dem Stern, dann liegt sie hier bereit.',
      );
    }
    if (kandidaten == null) {
      return const _Hinweis(text: 'Proben werden geladen …');
    }

    final nachId = <String, ProbeQuickSearchCandidate>{
      for (final kandidat in kandidaten)
        if (kandidat.favorit != null) kandidat.favorit!.id: kandidat,
    };
    final sichtbar = <({int stelle, ProbeQuickSearchCandidate kandidat})>[
      for (var i = 0; i < favoriten.length; i++)
        if (nachId[favoriten[i].id] != null)
          (stelle: i, kandidat: nachId[favoriten[i].id]!),
    ];
    final fehlend = <String>{
      for (final favorit in favoriten)
        if (!nachId.containsKey(favorit.id)) favorit.id,
    };

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sichtbar.length; i++)
            _ProbenZeile(
              kandidat: sichtbar[i].kandidat,
              onWuerfeln: () => showLoggedProbeDialog(
                context: context,
                ref: ref,
                heroId: heroId,
                request: sichtbar[i].kandidat.buildRequest(),
              ),
              onNachVorn: i == 0
                  ? null
                  : () => _verschiebe(
                      context,
                      ref,
                      sichtbar[i].kandidat.favorit!.id,
                      sichtbar[i - 1].stelle - sichtbar[i].stelle,
                    ),
              onNachHinten: i == sichtbar.length - 1
                  ? null
                  : () => _verschiebe(
                      context,
                      ref,
                      sichtbar[i].kandidat.favorit!.id,
                      sichtbar[i + 1].stelle - sichtbar[i].stelle,
                    ),
              onEntfernen: () => _aendere(
                context,
                ref,
                (liste) => entferneProbenFavoriten(liste, {
                  sichtbar[i].kandidat.favorit!.id,
                }),
              ),
            ),
          if (fehlend.isNotEmpty)
            _NichtVerfuegbar(
              anzahl: fehlend.length,
              onEntfernen: () => _aendere(
                context,
                ref,
                (liste) => entferneProbenFavoriten(liste, fehlend),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _verschiebe(
    BuildContext context,
    WidgetRef ref,
    String id,
    int schritte,
  ) => _aendere(
    context,
    ref,
    (liste) => verschiebeProbenFavorit(liste, id, schritte),
  );

  // Frisch geladen, nur das eigene Feld geändert (ARCH-05).
  Future<void> _aendere(
    BuildContext context,
    WidgetRef ref,
    List<HeroProbenFavorit> Function(List<HeroProbenFavorit>) aenderung,
  ) async {
    await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: heroId,
      was: 'Häufige Proben',
      aenderung: (aktuell) =>
          aktuell.copyWith(probenFavoriten: aenderung(aktuell.probenFavoriten)),
    );
  }
}

enum _Aktion { nachVorn, nachHinten, entfernen }

class _ProbenZeile extends StatelessWidget {
  const _ProbenZeile({
    required this.kandidat,
    required this.onWuerfeln,
    required this.onNachVorn,
    required this.onNachHinten,
    required this.onEntfernen,
  });

  final ProbeQuickSearchCandidate kandidat;
  final VoidCallback onWuerfeln;
  final VoidCallback? onNachVorn;
  final VoidCallback? onNachHinten;
  final VoidCallback onEntfernen;

  @override
  Widget build(BuildContext context) {
    final id = kandidat.favorit!.id;
    return ListTile(
      key: ValueKey('proben-favorit-$id'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.casino_outlined, size: 20),
      title: Text(kandidat.name),
      subtitle: Text(kandidat.detail),
      onTap: onWuerfeln,
      trailing: PopupMenuButton<_Aktion>(
        key: ValueKey('proben-favorit-menue-$id'),
        tooltip: 'Häufige Probe verwalten',
        onSelected: (aktion) => switch (aktion) {
          _Aktion.nachVorn => onNachVorn?.call(),
          _Aktion.nachHinten => onNachHinten?.call(),
          _Aktion.entfernen => onEntfernen(),
        },
        itemBuilder: (_) => <PopupMenuEntry<_Aktion>>[
          PopupMenuItem(
            value: _Aktion.nachVorn,
            enabled: onNachVorn != null,
            child: const Text('Nach vorn'),
          ),
          PopupMenuItem(
            value: _Aktion.nachHinten,
            enabled: onNachHinten != null,
            child: const Text('Nach hinten'),
          ),
          const PopupMenuItem(
            value: _Aktion.entfernen,
            child: Text('Entfernen'),
          ),
        ],
      ),
    );
  }
}

class _NichtVerfuegbar extends StatelessWidget {
  const _NichtVerfuegbar({required this.anzahl, required this.onEntfernen});

  final int anzahl;
  final VoidCallback onEntfernen;

  @override
  Widget build(BuildContext context) {
    final text = anzahl == 1
        ? 'Eine häufige Probe ist derzeit nicht verfügbar.'
        : '$anzahl häufige Proben sind derzeit nicht verfügbar.';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
          TextButton(
            key: const ValueKey('proben-favoriten-aufraeumen'),
            onPressed: onEntfernen,
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
  }
}

class _Hinweis extends StatelessWidget {
  const _Hinweis({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}
