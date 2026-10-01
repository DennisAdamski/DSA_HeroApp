/* Gemeinsame Aktionsfreigaben und kompakter Takt für den flüchtigen Gefecht-Entwurf.
 * Diese Beispielsimulation wird nicht als Regelmodul in die Flutter-App übernommen. */
'use strict';

// Die Hausregel bindet INI-Boni an die erste tatsächlich genutzte Aktion.
function fixiereIniBoni() {
  const g = S.gefecht;
  if (!g || g.iniBoniFixiert) return;
  g.iniRundenbeginn = berechne(S.held, g).iniAktuell;
  g.iniBoniFixiert = true;
}

// Zusatzparaden bleiben ihrer Waffe vorbehalten und ersetzen keine reguläre Handlung.
function pruefeAktionskosten(verbrauch, art = null) {
  const { plan } = aktuellerPlan();
  const g = S.gefecht;
  const offen = plan.marken.filter((m) => !m.gesperrt && !g.verbraucht[m.id]);
  const passend = (m, typ) => m.art === typ && (!m.nur || m.nur === art);
  let marken = [];
  if (verbrauch === 'alle') {
    const genutzt = plan.marken.some((m) => m.art !== 'frei' && g.verbraucht[m.id]);
    if (genutzt) return { marken, grund: 'Bereits eine Kampfaktion genutzt: braucht alle Aktionen der Runde.' };
    marken = offen.filter((m) => m.art !== 'frei');
    const beide = ['a1', 'a2'].every((id) => marken.some((m) => m.id === id));
    if (!beide) return { marken: [], grund: 'Braucht beide regulären Aktionen der Runde.' };
    if (!marken.some((m) => m.art === 'angriff')) {
      return { marken: [], grund: 'Keine Angriffsaktion für das Manöver eingeplant.' };
    }
  } else if (verbrauch === 'angriff_und_abwehr') {
    const angriff = offen.find((m) => m.id === 'a1' && m.art === 'angriff');
    const abwehr = offen.find((m) => m.id === 'a2' && m.art === 'abwehr');
    if (!angriff || !abwehr) return { marken, grund: 'Braucht eine offene Angriffs- und Abwehraktion.' };
    marken = [angriff, abwehr];
  } else {
    const marke = offen.find((m) => passend(m, verbrauch));
    if (!marke) {
      const titel = { angriff: 'Angriffsaktion', abwehr: 'passende Abwehraktion', frei: 'Freie Aktion' }[verbrauch];
      return { marken, grund: `Keine ${titel} mehr offen.` };
    }
    marken = [marke];
  }
  const zuschlag = marken[0].erschw || 0;
  return { marken, grund: null, zuschlag };
}

// Anzeige und Ausführung benutzen dieselbe Freigabe; Warnungen kommen vor dem Wurf.
function kampfOption(art, h, g, v) {
  if (art === 'tp') return { grund: null, ziel: null, zuschlag: 0 };
  let grund = kampfSperre(v, art);
  if (art === 'aw') {
    grund = grund || ausweichenMoeglich(h, g);
    const frei = pruefeAktionskosten('frei', 'aw');
    const gezielt = h.ausweichenI ? pruefeAktionskosten('abwehr', 'aw') : null;
    if (frei.grund && (!gezielt || gezielt.grund)) grund = grund || 'Keine passende Aktion zum Ausweichen offen.';
    return { grund, ziel: null, zuschlag: 0 };
  }
  if (art === 'fk') {
    if (!v.geschossDaten || v.geschossDaten.anzahl <= 0) grund = grund || 'Keine Geschosse mehr.';
    if ((g.ladung[v.waffe.id] || 0) < v.waffe.ladezeit) grund = grund || `Erst nachladen: ${aktionenText(v.waffe.ladezeit)}.`;
  }
  const verbrauch = art === 'at' || art === 'fk' ? 'angriff' : 'abwehr';
  const kosten = pruefeAktionskosten(verbrauch, art);
  grund = grund || kosten.grund;
  const basis = { at: v.at, pa: v.pa, schild: v.schildPa, fk: v.fkZiel }[art];
  const ers = erschwernis(h, g, v, art);
  const zuschlag = kosten.zuschlag || 0;
  return { grund, ziel: basis - ers.summe - zuschlag, zuschlag };
}

// Beherrschte Manöver bleiben nachlesbar, auch wenn Waffe oder Aktionsbudget sie sperren.
function manoeverOption(m, h, g, v) {
  const art = m.abwehr ? 'pa' : 'at';
  let grund = kampfSperre(v, art);
  if (m.talente && !m.talente.includes(v.waffe.talent)) {
    grund = grund || `Mit ${v.waffe.talent} nicht ausführbar.`;
  }
  const kosten = pruefeAktionskosten(m.verbrauch, art);
  grund = grund || kosten.grund;
  if (g.distanzklasse && !(v.waffe.dk || '').includes(g.distanzklasse)) {
    grund = grund || `DK ${g.distanzklasse} liegt außerhalb der Waffen-DK ${v.waffe.dk}.`;
  }
  const pruefen = !grund && (!g.distanzklasse || m.zielPruefen);
  return {
    grund, zuschlag: kosten.zuschlag || 0,
    status: grund ? 'gesperrt' : pruefen ? 'pruefen' : 'bereit',
    hinweis: grund || (!g.distanzklasse ? 'Aktuelle Distanzklasse prüfen.' : m.zielPruefen || 'Nach erfasstem Zustand verfügbar.'),
  };
}

// Ein Wirkversuch beginnt erst, wenn eine reguläre Aktion und bekannte Kosten verfügbar sind.
function wirkenSperre(e, h, g, v) {
  if (v.lage && !(v.lage.art === 'kampfunfaehig' && g.kfIgnoriert > 0)) return v.lage.text;
  if (g.patzer) return 'Patzer: Runde verloren.';
  if (g.handlung) return `${g.handlung.name} läuft noch – erst abschließen oder abbrechen.`;
  const { plan } = aktuellerPlan();
  const regulaer = plan.marken.some((m) => ['a1', 'a2'].includes(m.id) && !m.gesperrt && !g.verbraucht[m.id]);
  if (!regulaer) return 'Keine reguläre Aktion zum Beginnen mehr offen.';
  const stand = energieStand(h, e.energie);
  const kosten = e.typ === 'liturgie' ? LITURGIEGRAD[e.grad].kap : e.kostenWert;
  if (stand && kosten !== null && kosten > stand.wert) return `Nicht genug ${e.energie}: braucht ${kosten}.`;
  return null;
}

// Auswahlfelder ersetzen drei dauerhaft aufgeklappte Schaltergruppen.
function taktAuswahl(titel, name, wert, eintraege, gesperrt = false) {
  const optionen = eintraege.map((e) => {
    const aktiv = String(e.wert) === String(wert);
    return `<option value="${esc(e.wert)}" ${aktiv ? 'selected' : ''} ${e.gesperrt ? 'disabled' : ''}>${esc(e.text)}</option>`;
  }).join('');
  return `<label class="takt-auswahl"><span>${titel}</span><select data-change="${name}" aria-label="${titel}" ${gesperrt ? 'disabled' : ''}>${optionen}</select></label>`;
}

// Die gesamte Breite gehört dem Takt; Erklärungen sind über den Info-Knopf erreichbar.
function kompakterTakt(h, g, v, plan) {
  const sperre = ansageGesperrt(h, g, plan);
  const um = plan.um;
  const schild = v.schildNutzbar && h.nebenhand.schildkampfII;
  const optionen = [
    { wert: 'keine', text: '1 AT · 1 PA' },
    { wert: 'at-pa', text: `2 PA (${um.gesperrt ? '–' : vz(um.atPa.erschw)})`, gesperrt: Boolean(um.gesperrt) },
    { wert: 'pa-at', text: `2 AT (${um.gesperrt ? '–' : vz(um.paAt.erschw)})`, gesperrt: Boolean(um.gesperrt || g.zweiSchildparaden || v.iniAktuell < 8) },
  ];
  const umwandeln = taktAuswahl('Umwandeln', 'umwandeln', g.umwandeln, optionen, Boolean(sperre));
  const haltungen = ['stehend', 'kniend', 'liegend'].map((x) => ({ wert: x, text: x }));
  const gegner = [1, 2, 3, 4].map((x) => ({ wert: x, text: x === 4 ? '4+' : String(x) }));
  const dk = [{ wert: '', text: 'offen' }, ...['H', 'N', 'S', 'P'].map((x) => ({ wert: x, text: x }))];
  const offen = plan.marken.filter((m) => !m.gesperrt && !g.verbraucht[m.id]).length;
  return `<section class="takt-flach" aria-label="Takt der Kampfrunde">
    <div class="takt-oben">
      <button type="button" class="ini-kurz" data-action="takt-info" aria-label="Initiative ${minus(v.iniAktuell)}, Aufschlüsselung und Regeln öffnen"><span>INI</span><b>${minus(v.iniAktuell)}</b>${icon('info')}</button>
      <div class="plan-kurz"><span class="etikett">${offen} Aktionen offen</span><div class="marken">${plan.marken.map((m) => markeHtml(m, g)).join('')}</div></div>
      <button type="button" class="btn btn-primaer rundenwechsel" data-action="naechste-runde" aria-label="Nächste Kampfrunde, derzeit Runde ${g.kr}"><span>KR ${g.kr}</span>${icon('next')}</button>
    </div>
    <div class="takt-unten">
      ${umwandeln}${taktAuswahl('Haltung', 'haltung', g.haltung, haltungen)}${taktAuswahl('Gegner', 'gegner', g.gegner, gegner)}${taktAuswahl('DK', 'distanzklasse', g.distanzklasse || '', dk)}
      ${schild ? `<button type="button" class="check" role="checkbox" aria-checked="${g.zweiSchildparaden}" data-action="zwei-schild" ${sperre || g.umwandeln === 'pa-at' ? 'disabled' : ''}><span class="kasten">${icon('check')}</span>2 Schildparaden</button>` : ''}
      <button type="button" class="btn btn-sekundaer btn-klein weitere-aktionen" data-action="aktionen">${icon('flag')}Weitere Aktionen</button>
    </div>
    ${zustandChips(h, g, v)}
    ${plan.warnungen.map((w) => `<p class="obergrenze">${esc(w)}</p>`).join('')}
    ${handlungHtml(g)}
  </section>`;
}

// Nur wirksame Abweichungen belegen Platz; normale Haltung und Gegner stehen in den Feldern.
function zustandChips(h, g, v) {
  const chips = [];
  if (g.desorientiert) chips.push(`<span class="zustand-chip warn">Desorientiert<button type="button" class="btn btn-leise btn-klein" data-action="position">Position + Orientieren</button></span>`);
  if (g.patzer) chips.push('<span class="zustand-chip gefahr">Patzer: Runde verloren</span>');
  if (g.bewegt) chips.push('<span class="zustand-chip">Bewegt: Kampf +4</span>');
  if (g.sprint) chips.push('<span class="zustand-chip warn">Sprintet: keine Kampfaktionen</span>');
  if (g.naechsteErschwernis) chips.push(`<span class="zustand-chip warn">Nächste Aktion +${g.naechsteErschwernis}</span>`);
  if (g.nachLangfristig) chips.push('<span class="zustand-chip">Nach Handlung: Kampf +4</span>');
  if (v.aufrecht) chips.push(`<span class="zustand-chip astral">${v.aufrecht} aufrechterhalten: Kampf +${v.aufrecht}, Zauber +${3 * v.aufrecht}</span>`);
  if (g.mirakel) chips.push(`<span class="zustand-chip">Mirakel +${g.mirakel.bonus}</span>`);
  if (g.kfIgnoriert > 0) chips.push(`<span class="zustand-chip warn">Kampfunfähigkeit ignoriert: ${g.kfIgnoriert} KR</span>`);
  return chips.length ? `<div class="zustand-chips">${chips.join('')}</div>` : '';
}

// Ausführliche Regeln und manuelle Korrekturen bleiben einen Klick entfernt.
function dialogTaktInfo() {
  const h = S.held;
  const g = S.gefecht;
  const { v, plan } = aktuellerPlan();
  const sperre = ansageGesperrt(h, g, plan);
  const um = plan.um;
  const ausnahme = um.gesperrt || `Angriff → Abwehr ${vz(um.atPa.erschw)}${um.atPa.grund ? ` (${um.atPa.grund})` : ''}; Abwehr → Angriff ${vz(um.paAt.erschw)}${um.paAt.grund ? ` (${um.paAt.grund})` : ''}.`;
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">Initiative und Rundenplan</h2>
    <dl class="tabelle-kv"><dt>Aktuelle INI</dt><dd>${minus(v.iniAktuell)}</dd><dt>Ohne Wurf</dt><dd>${v.iniOhneWurf}</dd><dt>Wurf</dt><dd>${g.iniWurf}</dd><dt>Kampfverluste</dt><dd>${g.iniVerlust}</dd><dt>Kopfwunden</dt><dd>${h.kopfIni}</dd><dt>INI-Boni</dt><dd>Abwehr ${vz(v.abwehrBonus)}, freie Aktionen ${vz(v.freiBonus)}<br>${g.iniBoniFixiert ? `Fixiert bei erster Aktion: INI ${g.iniRundenbeginn}.` : 'Werden bei der ersten Aktion fixiert (Hausregel).'}</dd></dl>
    <p>${esc(ausnahme)} Zweite Attacke bei INI − 8.</p>
    <p class="legende">${esc(sperre || 'Umwandeln zu Rundenbeginn; Aufmerksamkeit bis zur eigenen Initiativphase, Kampfgespür auch später.')} Zwei Schildparaden müssen gewöhnliche Schildparaden sein. Aktionsmarken lassen sich zur Korrektur von Hand abhaken.</p>
    <div class="aktionen-zeile"><button type="button" class="btn btn-sekundaer" data-dlg="ini-minus">INI −1</button><button type="button" class="btn btn-sekundaer" data-dlg="ini-plus" ${g.iniVerlust <= 0 ? 'disabled' : ''}>INI +1</button><button type="button" class="btn btn-sekundaer" data-dlg="orientieren">Orientieren</button></div>
    <p class="legende">DK beschreibt die aktuelle Distanz, nicht nur die Reichweite der Waffe. Gegnergröße und gegnerische Manöver werden im Entwurf noch von dir geprüft. Liturgieprobe zu Beginn und die Mirakel-Bonusformel für Ausweichen sind markierte Annahmen.</p>
    <p class="legende">WdS S. 55–56, 72, 79, 81–82; Hausregel „Erweiterung und Überarbeitung“ S. 2–3. Seiten nach MCP-Index.</p></div>
    <div class="dlg-aktionen">${abbrechen('Schließen')}</div>`, {
      'ini-minus': () => { g.iniVerlust += 1; render(); dialogTaktInfo(); },
      'ini-plus': () => { g.iniVerlust = Math.max(0, g.iniVerlust - 1); render(); dialogTaktInfo(); },
      orientieren: () => { dlg.close(); fuehreAktionAus('orientieren'); },
    });
}
