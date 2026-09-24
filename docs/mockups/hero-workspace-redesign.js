/* Standalone design prototype: example outcomes, no production DSA rule engine. */
'use strict';

const $ = (selector) => document.querySelector(selector);
const icon = (name) => `<svg class="icon" aria-hidden="true"><use href="#i-${name}"/></svg>`;
const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (character) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[character]));
const initialState = {
  name: 'Liora Sternfels', origin: 'Mittelreich',
  biography: 'Ich suche die Wahrheit hinter den Nebeln. Und einen guten Tee für den Weg.',
  life: 32, astral: 24, round: 4, effect: 3, ap: 320,
  equipped: 'staff', plan: [], learned: [],
  items: [
    { id: 'staff', name: 'Magierstab', kind: 'Stäbe · beidhändig', place: 'In der Hand', attack: 12, parry: 10 },
    { id: 'dagger', name: 'Dolch', kind: 'Dolche · einhändig', place: 'Am Gürtel', attack: 10, parry: 8 },
    { id: 'robe', name: 'Reiserobe', kind: 'Kleidung', place: 'Am Körper' },
    { id: 'book', name: 'Persönliches Zauberbuch', kind: 'Aufzeichnungen', place: 'Im Rucksack' },
  ],
  log: [
    { time: '21:14', text: 'Axxeleratus aktiviert. Noch 3 Kampfrunden.' },
    { time: '21:08', text: 'Sinnenschärfe gelungen. Die Spur führt nach Norden.' },
  ],
};
let state = structuredClone(initialState);
let undoStack = [];
let filter = 'Alle';
let toastTimer;
const probes = [
  { id: 'perception', name: 'Sinnenschärfe', category: 'Talente', attributes: 'KL / IN / IN', value: 12 },
  { id: 'agility', name: 'Körperbeherrschung', category: 'Talente', attributes: 'MU / IN / GE', value: 8 },
  { id: 'fire', name: 'Ignifaxius', category: 'Zauber', attributes: 'MU / KL / CH', value: 14 },
  { id: 'armor', name: 'Armatrutz', category: 'Zauber', attributes: 'IN / GE / KK', value: 10 },
];
const options = [
  { id: 'perception', name: 'Sinnenschärfe', change: 'Talentwert 12 → 13', cost: 28 },
  { id: 'agility', name: 'Körperbeherrschung', change: 'Talentwert 8 → 9', cost: 21 },
  { id: 'fire', name: 'Ignifaxius', change: 'Zauberfertigkeit 14 → 15', cost: 45 },
  { id: 'attention', name: 'Aufmerksamkeit', change: 'Neue Sonderfertigkeit', cost: 200 },
];

// Keep mock actions reversible across navigation without touching real hero data.
function changeState(message, action) {
  undoStack.push(structuredClone(state));
  action();
  addLog(message);
  render();
  toast(message);
}
function addLog(message) {
  const time = new Date().toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
  state.log.unshift({ time, text: message });
  state.log = state.log.slice(0, 6);
}
function toast(message) {
  clearTimeout(toastTimer);
  $('#toast').textContent = message;
  $('#toast').hidden = false;
  toastTimer = setTimeout(() => { $('#toast').hidden = true; }, 4000);
}
function showDialog(title, content) {
  $('#dialog-title').textContent = title;
  $('#dialog-body').innerHTML = content;
  if (!$('#action-dialog').open) $('#action-dialog').showModal();
}
function closeDialog() { $('#action-dialog').close(); }

// Demo values are deliberately fixtures, not recalculated game rules.
function render() {
  $('#life-value').textContent = state.life;
  $('#astral-value').textContent = state.astral;
  $('#life-caption').textContent = state.life === 38 ? 'Vollständig erholt' : `${38 - state.life} LeP fehlen`;
  for (const [kind, value, maximum] of [['life', state.life, 38], ['astral', state.astral, 42]]) {
    $(`#${kind}-bar`).setAttribute('aria-valuenow', value);
    $(`#${kind}-bar span`).style.width = `${value / maximum * 100}%`;
  }
  $('#round-label').textContent = `KR ${state.round}`;
  $('#effect-duration').textContent = `Noch ${state.effect} ${state.effect === 1 ? 'Kampfrunde' : 'Kampfrunden'}`;
  $('#active-effect').hidden = state.effect === 0;
  $('#effects-empty').hidden = state.effect > 0;
  $('#effect-count').textContent = state.effect > 0 ? '1' : '0';
  $('#undo-action').disabled = undoStack.length === 0;
  $('#session-log').innerHTML = state.log.map((entry) => `<li><time>${escapeHtml(entry.time)}</time><span class="log-dot"></span><p>${escapeHtml(entry.text)}</p></li>`).join('');
  $('.hero-identity h2').textContent = state.name;
  $('.breadcrumb strong').textContent = state.name;
  $('#view-verwalten .context-line').textContent = state.name;
  $('#view-entwickeln .context-line').textContent = state.name;
  $('#biography-form [name="heroName"]').value = state.name;
  $('#biography-form [name="origin"]').value = state.origin;
  $('#biography-form [name="bio"]').value = state.biography;
  const weapon = state.items.find((item) => item.id === state.equipped);
  $('#equipped-name').textContent = weapon.name;
  $('#equipped-kind').textContent = weapon.kind;
  $('#attack-value').textContent = weapon.attack;
  $('#parry-value').textContent = weapon.parry;
  renderProbes();
  renderInventory();
  renderPlan();
}
function renderProbes() {
  const visible = probes.filter((probe) => filter === 'Alle' || probe.category === filter);
  $('#probe-list').innerHTML = visible.map((probe) => {
    const magic = probe.category === 'Zauber';
    const value = probe.value + (state.learned.includes(probe.id) ? 1 : 0);
    return `<button class="probe-row" data-probe="${probe.id}" aria-label="${probe.name} würfeln"><span class="probe-symbol ${magic ? 'magic' : ''}">${icon(magic ? 'star' : 'compass')}</span><span class="probe-copy"><strong>${probe.name}</strong><small>${magic ? 'Zauber' : 'Talent'} · ${probe.attributes}</small></span><span class="probe-number">${value}</span>${icon('dice')}</button>`;
  }).join('');
}
function renderInventory() {
  $('#inventory-list').innerHTML = state.items.map((item) => {
    let action = '<span class="muted">Im Inventar</span>';
    if (item.attack) action = item.id === state.equipped
      ? `<span class="equipped-label">${icon('check')}Ausgerüstet</span>`
      : `<button class="button button-secondary" data-equip="${item.id}">Ausrüsten</button>`;
    return `<div class="inventory-row"><div class="item-name">${icon(item.attack ? 'sword' : 'book')}<div><strong>${escapeHtml(item.name)}</strong><small>${escapeHtml(item.kind)}</small></div></div><span class="item-place">${item.id === state.equipped ? 'In der Hand' : escapeHtml(item.place === 'In der Hand' ? 'Am Gepäck' : item.place)}</span><div>${action}</div></div>`;
  }).join('');
}
function renderPlan() {
  const selected = options.filter((option) => state.plan.includes(option.id));
  const reserved = selected.reduce((sum, option) => sum + option.cost, 0);
  $('#ap-total').textContent = state.ap;
  $('#ap-reserved').textContent = reserved;
  $('#ap-remaining').textContent = state.ap - reserved;
  $('#plan-count').textContent = selected.length;
  $('#plan-badge').textContent = selected.length;
  $('#plan-badge').hidden = !selected.length;
  $('#plan-cost').textContent = `${reserved} AP`;
  $('#apply-plan').disabled = selected.length === 0;
  $('#advancement-options').innerHTML = options.map((option) => {
    const learned = state.learned.includes(option.id);
    const planned = state.plan.includes(option.id);
    const blocked = learned || planned || option.cost > state.ap - reserved;
    const label = learned ? 'Übernommen' : planned ? 'Vorgemerkt' : '+ Vormerken';
    return `<div class="advancement-row"><div><strong>${option.name}</strong><p>${option.change}</p></div><span>${option.cost} AP</span><button class="button button-secondary" data-plan="${option.id}" ${blocked ? 'disabled' : ''}>${label}</button></div>`;
  }).join('');
  $('#plan-list').innerHTML = selected.length ? selected.map((option) =>
    `<div class="plan-entry"><div><strong>${option.name}</strong><small>${option.change} · ${option.cost} AP</small></div><button class="icon-button" data-remove-plan="${option.id}" aria-label="${option.name} aus Planung entfernen">${icon('close')}</button></div>`
  ).join('') : `<div class="plan-empty">${icon('grow')}Hier beginnt dein nächster Schritt.<br>Merke links eine Steigerung vor.</div>`;
}
function navigate() {
  const requested = location.hash.slice(1);
  const mode = ['spielen', 'verwalten', 'entwickeln'].includes(requested) ? requested : 'spielen';
  for (const view of document.querySelectorAll('.view')) view.hidden = view.id !== `view-${mode}`;
  for (const link of document.querySelectorAll('[data-mode]')) {
    const active = link.dataset.mode === mode;
    link.classList.toggle('active', active);
    if (active) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
  }
}
function showProbe(id) {
  const probe = probes.find((entry) => entry.id === id);
  const name = probe?.name || 'Attacke';
  const dice = probe ? ['8', '11', '4'] : ['7'];
  showDialog(name, `<p>${probe ? probe.attributes + ' · 3W20-Probe' : 'Angriff mit deiner ausgerüsteten Waffe'}</p><div class="dice-tray">${dice.map(() => '<span class="die">–</span>').join('')}</div><div class="roll-result" id="roll-result">Dein Wurf ist bereit.</div><div class="dialog-actions"><button class="button button-primary" id="roll-dice">${icon('dice')}Beispielwurf anzeigen</button></div>`);
  $('#roll-dice').addEventListener('click', () => {
    document.querySelectorAll('.die').forEach((die, index) => { die.textContent = dice[index]; });
    $('#roll-result').textContent = 'Gelungen. Beispielergebnis für den Designentwurf.';
    $('#roll-dice').disabled = true;
    addLog(`${name}: Beispielprobe gelungen.`);
    render();
  });
}
function showDamage() {
  showDialog('Schaden erhalten', `<form class="dialog-form" id="damage-form"><p class="muted">Trage die bereits ermittelten Schadenspunkte ein. Wunden werden in diesem Entwurf nicht berechnet.</p><label>Schadenspunkte<input id="damage-amount" type="number" min="1" max="${Math.max(1, state.life)}" step="1" value="6" required></label><div class="damage-preview"><span>Lebensenergie danach</span><strong id="damage-after"></strong></div><div class="dialog-actions"><button class="button button-secondary" type="button" data-action="close">Abbrechen</button><button class="button button-danger" type="submit" ${state.life === 0 ? 'disabled' : ''}>Schaden übernehmen</button></div></form>`);
  const update = () => { $('#damage-after').textContent = `${Math.max(0, state.life - Number($('#damage-amount').value))} / 38`; };
  $('#damage-amount').addEventListener('input', update);
  update();
  $('#damage-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const damage = Number($('#damage-amount').value);
    changeState(`${damage} Schadenspunkte übernommen.`, () => { state.life = Math.max(0, state.life - damage); });
    closeDialog();
  });
}
function showNote() {
  showDialog('Notiz zum Spielabend', '<form class="dialog-form" id="note-form"><label>Was möchtest du festhalten?<textarea id="note-text" rows="4" maxlength="500" required placeholder="Eine Spur, ein Name, ein Versprechen …"></textarea></label><div class="dialog-actions"><button class="button button-primary" type="submit">Notiz hinzufügen</button></div></form>');
  $('#note-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const value = $('#note-text').value.trim();
    if (!value) { $('#note-text').setCustomValidity('Bitte eine Notiz eingeben.'); $('#note-text').reportValidity(); return; }
    changeState(`Notiz: ${value}`, () => {});
    closeDialog();
  });
  $('#note-text').addEventListener('input', () => $('#note-text').setCustomValidity(''));
}
function showNewItem() {
  showDialog('Gegenstand hinzufügen', '<form class="dialog-form" id="item-form"><label>Gegenstand<input id="item-name" maxlength="80" placeholder="Zum Beispiel: Heiltrank" required></label><label>Aufbewahrung<input id="item-place" maxlength="80" value="Im Rucksack" required></label><div class="dialog-actions"><button class="button button-primary" type="submit">Gegenstand hinzufügen</button></div></form>');
  $('#item-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const name = $('#item-name').value.trim();
    if (!name) { $('#item-name').setCustomValidity('Bitte einen Namen eingeben.'); $('#item-name').reportValidity(); return; }
    const place = $('#item-place').value.trim();
    changeState(`${name} zum Inventar hinzugefügt.`, () => state.items.push({ id: `item-${state.items.length}`, name, kind: 'Persönlicher Gegenstand', place }));
    closeDialog();
  });
  $('#item-name').addEventListener('input', () => $('#item-name').setCustomValidity(''));
}
const actions = {
  close: closeDialog,
  damage: showDamage,
  note: showNote,
  'add-item': showNewItem,
  attack: () => showProbe('attack'),
  round: () => changeState('Die nächste Kampfrunde beginnt.', () => {
    state.round += 1;
    state.effect = Math.max(0, state.effect - 1);
  }),
  rest: () => {
    showDialog('Zeit zum Durchatmen', '<p>Ein ruhiger Lagerplatz, eine warme Mahlzeit und etwas Schlaf.</p><div class="dialog-callout">Beispiel einer abgeschlossenen Rast:<br><strong>+5 LeP und +6 AsP</strong>, jeweils bis zum Maximum.<br>Diese Werte sind für den Entwurf vorgegeben.</div><div class="dialog-actions"><button class="button button-primary" id="finish-rest">Rast abschließen</button></div>');
    $('#finish-rest').addEventListener('click', () => {
      changeState('Rast abgeschlossen. Lebens- und Astralenergie aufgefüllt.', () => {
        state.life = Math.min(38, state.life + 5);
        state.astral = Math.min(42, state.astral + 6);
      });
      closeDialog();
    });
  },
  'attack-detail': () => {
    const weapon = state.items.find((item) => item.id === state.equipped);
    showDialog('Deine Attacke erklärt', `<p>${escapeHtml(weapon.name)} · Beispielherleitung</p><dl class="breakdown"><div><dt>Basiswert</dt><dd>8</dd></div><div><dt>Anteil aus dem Kampftalent</dt><dd>+${weapon.attack - 8}</dd></div><div><dt>Situative Modifikatoren</dt><dd>0</dd></div><div class="total"><dt>Attacke</dt><dd>${weapon.attack}</dd></div></dl><div class="dialog-callout">Regelprofil: Unsere Hausregeln, Version 1.4.<br>Im späteren Produkt führt jeder Beitrag zur zugehörigen Regelquelle.</div>`);
  },
  profile: () => showDialog('Unsere Hausregeln', '<p>Dieses Beispielprofil ist dem Helden fest zugeordnet.</p><dl class="breakdown"><div><dt>Profilversion</dt><dd>1.4</dd></div><div><dt>Basis</dt><dd>DSA-Hausregeln</dd></div><div><dt>Aktive Bereiche</dt><dd>Kampf, Magie, Steigerung</dd></div></dl><div class="dialog-callout">Vorgesehenes Verhalten: Regelupdates zeigen ihre Auswirkungen vor der Übernahme. Dieser Entwurf ändert keine Regelpakete.</div>'),
  'trait-info': () => showDialog('Ein Merkmal mit klarer Auswahl', '<p><strong>Begabung: Sinnenschärfe</strong></p><dl class="breakdown"><div><dt>Art</dt><dd>Vorteil</dd></div><div><dt>Gewähltes Talent</dt><dd>Sinnenschärfe</dd></div><div><dt>Regelprofil</dt><dd>Unsere Hausregeln 1.4</dd></div></dl><div class="dialog-callout">Name, Auswahl und Regelwirkung gehören zusammen. Ein anderer Anzeigename verändert die gespeicherte Auswahl nicht.</div>'),
};

document.addEventListener('click', (event) => {
  const control = event.target.closest('button');
  if (control?.dataset.action) actions[control.dataset.action]?.();
  if (control?.dataset.probe) showProbe(control.dataset.probe);
  if (control?.dataset.filter) {
    filter = control.dataset.filter;
    document.querySelectorAll('[data-filter]').forEach((button) => {
      const active = button === control;
      button.classList.toggle('active', active);
      button.setAttribute('aria-pressed', active);
    });
    renderProbes();
  }
  if (control?.dataset.sheet) {
    document.querySelectorAll('.sheet-section').forEach((section) => { section.hidden = section.id !== `sheet-${control.dataset.sheet}`; });
    document.querySelectorAll('[data-sheet]').forEach((button) => {
      button.classList.toggle('active', button === control);
      button.setAttribute('aria-pressed', button === control);
    });
  }
  if (control?.dataset.equip) {
    const item = state.items.find((entry) => entry.id === control.dataset.equip);
    changeState(`${item.name} ausgerüstet.`, () => { state.equipped = item.id; });
  }
  if (control?.dataset.plan && !state.plan.includes(control.dataset.plan)) {
    state.plan.push(control.dataset.plan);
    renderPlan();
    toast('Steigerung vorgemerkt. Deine Werte bleiben zunächst unverändert.');
  }
  if (control?.dataset.removePlan) {
    state.plan = state.plan.filter((id) => id !== control.dataset.removePlan);
    renderPlan();
  }
  if (!event.target.closest('.quick-search-wrap')) $('#search-results').hidden = true;
});
$('#apply-plan').addEventListener('click', () => {
  if (!state.plan.length) return;
  const selected = options.filter((option) => state.plan.includes(option.id));
  const cost = selected.reduce((total, option) => total + option.cost, 0);
  changeState(`Steigerungsrunde übernommen: ${selected.length} Schritte, ${cost} AP.`, () => {
    state.ap -= cost;
    state.learned.push(...state.plan);
    state.plan = [];
  });
});
$('#undo-action').addEventListener('click', () => {
  if (!undoStack.length) return;
  state = undoStack.pop();
  render();
  toast('Letzte Änderung im Entwurf zurückgenommen.');
});
$('#biography-form').addEventListener('submit', (event) => {
  event.preventDefault();
  const data = new FormData(event.target);
  const name = data.get('heroName').trim();
  if (!name) return;
  changeState('Biografie im Entwurf gespeichert.', () => {
    state.name = name;
    state.origin = data.get('origin').trim();
    state.biography = data.get('bio').trim();
  });
});
$('#quick-search').addEventListener('input', () => {
  const query = $('#quick-search').value.trim().toLocaleLowerCase('de');
  $('#search-results').hidden = !query;
  if (!query) return;
  const matches = probes.filter((probe) => probe.name.toLocaleLowerCase('de').includes(query));
  let html = matches.map((probe) => `<button class="search-result" data-probe="${probe.id}"><span>${probe.name}</span><small>${probe.category}</small></button>`).join('');
  if (['attacke', 'regel', 'hausregel'].some((word) => word.includes(query) || query.includes(word))) {
    html += `<button class="search-result" data-action="attack-detail"><span>Attacke: Herleitung</span><small>Regel</small></button><button class="search-result" data-action="profile"><span>Unsere Hausregeln</span><small>Regelprofil</small></button>`;
  }
  $('#search-results').innerHTML = html || '<p class="search-empty">Kein Treffer in den Beispieldaten. Versuche „Sinnenschärfe“ oder „Attacke“.</p>';
});
document.addEventListener('keydown', (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
    event.preventDefault();
    if (!$('#action-dialog').open) $('#quick-search').focus();
  }
  if (event.key === 'Escape') $('#search-results').hidden = true;
});
$('#close-dialog').addEventListener('click', closeDialog);
$('#reset-demo').addEventListener('click', () => location.reload());
window.addEventListener('hashchange', navigate);
render();
navigate();
