part of 'schaden_dialog.dart';

// Aufbau des Schadenspanels. Die Rechnung kommt vollständig aus
// `schaden_rules.dart`; hier werden nur Eingaben gelesen und angezeigt.
extension _SchadenInhalt on _SchadenPanelState {
  Widget _buildInhalt(
    BuildContext context,
    HeroState state,
    HeroComputedSnapshot computed,
    TextEditingController rs,
  ) {
    final theme = Theme.of(context);
    final lebensenergie = _art == SchadensArt.lebensenergie;
    final tp = _zahl(_tp);
    final rsWert = (_zahl(rs) ?? 0) < 0 ? 0 : (_zahl(rs) ?? 0);
    final sp = tp == null || tp < 0
        ? null
        : berechneSchadenspunkte(tp: tp, rs: rsWert);
    final echteSp = sp == null ? null : echteSchadenspunkte(art: _art, sp: sp);
    final wsMod = _zahl(_wsMod) ?? 0;
    final vorschlag = echteSp == null
        ? null
        : schlageWundenVor(
            sp: echteSp,
            stufen: computed.wundschwellenStufen,
            angriffsModifikator: wsMod,
          );
    final zone = _zone;
    final wundZustand = state.wpiZustand;
    final frei = zone == null ? 0 : freieWundplaetze(wundZustand, zone);
    final vorgeschlagen = vorschlag?.wunden ?? 0;
    final int wunden = (_wundenUeberschrieben ?? vorgeschlagen).clamp(0, frei);
    final bisherige = zone == null ? 0 : wundZustand.wundenInZone(zone);
    final zusatzwuerfe = zone == null
        ? const <SchadensZusatzwurf>[]
        : schadensZusatzwuerfe(
            zone: zone,
            bisherigeWunden: bisherige,
            neueWunden: wunden,
          );
    final situation = '${zone?.name}:$bisherige:$wunden';
    final zusatzFelder = <TextEditingController>[
      for (final wurf in zusatzwuerfe) _zusatzFeld(situation, wurf.label),
    ];

    var zusatzSchaden = 0;
    var kopfIni = 0;
    var zusatzVollstaendig = true;
    for (var i = 0; i < zusatzwuerfe.length; i++) {
      final wert = _zahl(zusatzFelder[i]);
      if (wert == null || wert < 0) {
        zusatzVollstaendig = false;
        continue;
      }
      switch (zusatzwuerfe[i].wirkung) {
        case TrefferzonenZusatzwirkung.schaden:
          zusatzSchaden += wert;
        case TrefferzonenZusatzwirkung.iniMalus:
          kopfIni += wert;
      }
    }

    final buchung = sp == null || !zusatzVollstaendig
        ? null
        : SchadensBuchung(
            art: _art,
            tp: tp!,
            rs: rsWert,
            zone: zone,
            wunden: wunden,
            zusatzSchaden: zusatzSchaden,
            kopfIniWurf: kopfIni,
            angriffsModifikator: wsMod,
          );
    final vorschau = buchung == null
        ? null
        : wendeSchadenAn(state, buchung).zustand;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<SchadensArt>(
          key: const ValueKey<String>('schaden-art'),
          segments: const [
            ButtonSegment<SchadensArt>(
              value: SchadensArt.lebensenergie,
              label: Text('Lebensenergie'),
            ),
            ButtonSegment<SchadensArt>(
              value: SchadensArt.ausdauer,
              label: Text('Ausdauer (TP(A))'),
            ),
          ],
          selected: <SchadensArt>{_art},
          onSelectionChanged: _schreibt
              ? null
              : (auswahl) => _setzeArt(auswahl.single),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey<String>('schaden-tp'),
                controller: _tp,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: lebensenergie ? 'TP' : 'TP(A)',
                ),
                onChanged: (_) => _eingabeGeaendert(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const ValueKey<String>('schaden-rs'),
                controller: rs,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'RS',
                  helperText: 'Rüstung: ${computed.combatPreviewStats.rsTotal}',
                ),
                onChanged: (_) => _eingabeGeaendert(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          sp == null
              ? 'TP eintragen'
              : lebensenergie
              ? '$sp SP'
              : '$sp SP(A) · $echteSp SP auf LeP',
          key: const ValueKey<String>('schaden-sp'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _zonenZeile(context, zone),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey<String>('schaden-ws-mod'),
          controller: _wsMod,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[-−0-9]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Wundschwelle des Angriffs',
            helperText: 'z. B. Armbrustbolzen −2, waffenlos +2',
          ),
          onChanged: (_) => _eingabeGeaendert(),
        ),
        if (vorschlag != null) ...[
          const SizedBox(height: 8),
          Text(
            'Schwellen ${vorschlag.schwellen.join(' / ')} · $echteSp SP → '
            'Vorschlag: ${_wundenText(vorschlag.wunden)}',
            key: const ValueKey<String>('schaden-vorschlag'),
          ),
        ],
        if (zone == null && vorgeschlagen > 0)
          _hinweis(
            theme,
            'schaden-zone-fehlt',
            'Für Wunden eine Trefferzone wählen.',
          ),
        if (zone != null && vorgeschlagen > frei)
          _hinweis(
            theme,
            'schaden-zone-voll',
            '${wundZoneLabel[zone]} hat nur noch Platz für '
                '${_wundenText(frei)}; weitere verfallen.',
          ),
        const SizedBox(height: 8),
        _wundenZeile(theme, wunden, frei),
        for (var i = 0; i < zusatzwuerfe.length; i++)
          _zusatzZeile(i, zusatzwuerfe[i], zusatzFelder[i]),
        const SizedBox(height: 12),
        if (vorschau != null)
          Text(
            lebensenergie
                ? 'LeP ${state.currentLep} → ${vorschau.currentLep}'
                : 'AuP ${state.currentAu} → ${vorschau.currentAu} · '
                      'LeP ${state.currentLep} → ${vorschau.currentLep}',
            key: const ValueKey<String>('schaden-vorschau'),
            style: theme.textTheme.titleMedium,
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const ValueKey<String>('schaden-uebernehmen'),
            onPressed: buchung == null || _schreibt
                ? null
                : () => _uebernehme(buchung),
            child: const Text('Übernehmen'),
          ),
        ),
        if (_fehler != null) ...[
          const SizedBox(height: 8),
          Text(
            _fehler!,
            key: const ValueKey<String>('schaden-fehler'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _zonenZeile(BuildContext context, WundZone? zone) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          // Neuer Schlüssel je Zone: das Formularfeld übernimmt seinen
          // Anfangswert sonst nicht, wenn der W20 die Zone setzt.
          child: KeyedSubtree(
            key: ValueKey<String>('schaden-zone-${zone?.name}'),
            child: DropdownButtonFormField<WundZone?>(
              key: const ValueKey<String>('schaden-zone'),
              initialValue: zone,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Trefferzone'),
              items: [
                const DropdownMenuItem<WundZone?>(
                  value: null,
                  child: Text('Keine Zone'),
                ),
                for (final eintrag in WundZone.values)
                  DropdownMenuItem<WundZone?>(
                    value: eintrag,
                    child: Text(wundZoneLabel[eintrag]!),
                  ),
              ],
              onChanged: _schreibt ? null : _zoneGewaehlt,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: TextField(
            key: const ValueKey<String>('schaden-w20'),
            controller: _w20,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'W20',
              suffixIcon: IconButton(
                key: const ValueKey<String>('schaden-w20-wuerfeln'),
                tooltip: 'Trefferzone würfeln',
                icon: const Icon(Icons.casino_outlined),
                onPressed: _schreibt ? null : _wuerfleZone,
              ),
            ),
            onChanged: _w20Geaendert,
          ),
        ),
      ],
    );
  }

  Widget _wundenZeile(ThemeData theme, int wunden, int frei) {
    return Row(
      children: [
        const Expanded(child: Text('Neue Wunden')),
        IconButton(
          key: const ValueKey<String>('schaden-wunden-minus'),
          tooltip: 'Eine Wunde weniger',
          onPressed: wunden > 0 && !_schreibt
              ? () => _setzeWunden(wunden - 1)
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(
          '$wunden',
          key: const ValueKey<String>('schaden-wunden'),
          style: theme.textTheme.titleMedium,
        ),
        IconButton(
          key: const ValueKey<String>('schaden-wunden-plus'),
          tooltip: 'Eine Wunde mehr',
          onPressed: wunden < frei && !_schreibt
              ? () => _setzeWunden(wunden + 1)
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Widget _zusatzZeile(
    int index,
    SchadensZusatzwurf wurf,
    TextEditingController feld,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Text('${wurf.label} (${wurf.diceSpec.label})')),
          SizedBox(
            width: 72,
            child: TextField(
              key: ValueKey<String>('schaden-zusatz-$index'),
              controller: feld,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => _neuZeichnen(),
            ),
          ),
          IconButton(
            key: ValueKey<String>('schaden-zusatz-$index-wuerfeln'),
            tooltip: '${wurf.diceSpec.label} würfeln',
            icon: const Icon(Icons.casino_outlined),
            onPressed: _schreibt ? null : () => _wuerfleZusatz(feld, wurf),
          ),
        ],
      ),
    );
  }

  Widget _hinweis(ThemeData theme, String schluessel, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        key: ValueKey<String>(schluessel),
        style: TextStyle(color: theme.colorScheme.error),
      ),
    );
  }

  String _wundenText(int anzahl) => anzahl == 1 ? '1 Wunde' : '$anzahl Wunden';
}
