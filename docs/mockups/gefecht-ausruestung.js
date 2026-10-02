/* Ausrüstungsdialog für den flüchtigen Gefecht-Entwurf. */
'use strict';

// Der Dialog benötigt nur reguläre Marken; Zusatzparaden bezahlen keinen Waffenwechsel.
function ausruestungBudget(v, plan) {
  const g = S.gefecht;
  const regulaer = plan.marken.some((m) =>
    ['a1', 'a2'].includes(m.id) && !m.gesperrt && !g.verbraucht[m.id]);
  const frei = !pruefeAktionskosten('frei').grund;
  const lage = v.lage && !(v.lage.art === 'kampfunfaehig' && g.kfIgnoriert > 0);
  return { regulaer, frei, lage };
}

// Werte und Kosten bleiben vor dem tatsächlichen Ziehen sichtbar.
function ausruestungWaffen(h, g, v, budget) {
  return h.waffen.map((w) => {
    const z = ZIEHEN[w.scheide];
    const n = h.schnellziehen ? z.schnell : z.normal;
    const aktiv = w.id === h.aktiveWaffe;
    const offen = n === 0 ? budget.frei : budget.regulaer;
    let sperre = null;
    if (budget.lage) sperre = v.lage.text;
    else if (g.patzer) sperre = 'Patzer: Runde verloren.';
    else if (!offen) sperre = 'Keine passende Aktion offen.';
    const werte = w.art === 'nah'
      ? `AT ${w.at} · PA ${w.pa} · DK ${w.dk}`
      : `FK ${w.fk} · Ladezeit ${w.ladezeit}`;
    const kosten = n === 0 ? 'Freie Aktion' : aktionenText(n);
    const zustand = aktiv ? 'Aktuell geführt' : sperre || `${z.text} · ${kosten}`;
    const deaktiviert = aktiv || sperre ? 'disabled' : '';
    return `<div class="ausruestung-zeile">
      ${icon(w.art === 'nah' ? 'sword' : 'bow')}
      <div class="zeile-text"><b>${esc(w.name)}</b>
        <small>${esc(werte)}</small><small>${esc(zustand)}</small></div>
      <button type="button" class="btn btn-sekundaer btn-klein"
        data-dlg="ziehen" data-id="${w.id}" ${deaktiviert}>
        ${aktiv ? 'Geführt' : 'Ziehen'}</button></div>`;
  }).join('');
}

// Einzelteile und ihr Anlegestatus gehören ausschließlich in den Ausrüstungsdialog.
function ausruestungTeile(h) {
  return h.ruestung.map((r) => `<div class="ausruestung-zeile">
    ${icon('armor')}<div class="zeile-text"><b>${esc(r.name)}</b>
      <small>RS ${r.rs} · BE ${r.be} · ${r.an ? 'angelegt' : 'abgelegt'}</small></div>
    <button type="button" class="schalter" role="switch" aria-checked="${r.an}"
      aria-label="${esc(r.name)} angelegt" data-dlg="ruestung"
      data-id="${r.id}"></button></div>`).join('');
}

// Ein gemeinsamer Dialog hält Waffen und Rüstungsteile aus dem Kampf-Hauptfluss heraus.
function dialogAusruestung(bereich = 'waffen') {
  const h = S.held;
  const g = S.gefecht;
  const { v, plan } = aktuellerPlan();
  const budget = ausruestungBudget(v, plan);
  const waffen = bereich === 'waffen';
  const inhalt = waffen ? ausruestungWaffen(h, g, v, budget) : ausruestungTeile(h);
  const hinweis = waffen
    ? 'Ziehen verbraucht die angegebene Aktion; längere Wechsel laufen als Handlung weiter.'
    : 'Angelegte Teile aktualisieren. Den Zeitbedarf für An- und Ablegen am Spieltisch berücksichtigen.';
  const summe = waffen ? ''
    : `<p class="ausruestung-summe">Aktuell: RS ${v.rs} · BE ${v.be}</p>`;
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">Ausrüstung wechseln</h2>
    <div class="seg ausruestung-tabs" role="group" aria-label="Ausrüstungsbereich">
      <button type="button" data-dlg="waffen" aria-pressed="${waffen}">
        ${icon('sword')}Waffen</button>
      <button type="button" data-dlg="teile" aria-pressed="${!waffen}">
        ${icon('armor')}Rüstungsteile</button>
    </div>
    <p class="legende">${hinweis}</p>
    <button type="button" class="btn btn-sekundaer" data-dlg="haende">Haupthand und Nebenhand · Folgeablauf</button>
    <div class="ausruestung-liste">${inhalt || '<p class="legende">Keine Einträge.</p>'}</div>
    ${summe}</div><div class="dlg-aktionen">${abbrechen('Fertig')}</div>`, {
      waffen: () => dialogAusruestung('waffen'),
      haende: () => dialogFolgeablaeufe('haende'),
      teile: () => dialogAusruestung('ruestung'),
      ziehen: (b) => { dlg.close(); fuehreAktionAus(`ziehen:${b.dataset.id}`); },
      ruestung: (b) => {
        const teil = h.ruestung.find((r) => r.id === b.dataset.id);
        teil.an = !teil.an;
        render();
        dialogAusruestung('ruestung');
      },
    });
}
