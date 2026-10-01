/* Gefecht-Entwurf: Beispieldaten und vereinfachte Rechnung, keine Regelengine der App.
 * Die Abläufe folgen den Regelstellen, die im Kommentar daneben stehen (WdS = Wege des
 * Schwerts, WdZ = Wege der Zauberei, LC = Liber Cantiones, LL = Liber Liturgium,
 * HR = Hausregel „Erweiterung und Überarbeitung des Regelwerks“). */
'use strict';

window.addEventListener('error', (e) => { document.body.dataset.fehler = String(e.message); });

const $ = (s, r = document) => r.querySelector(s);
const esc = (v) => String(v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const icon = (name, cls = '') => `<svg class="icon ${cls}" aria-hidden="true"><use href="#i-${name}"/></svg>`;
const minus = (n) => String(n).replace('-', '−');
const vz = (n) => (n > 0 ? `+${n}` : n < 0 ? `−${Math.abs(n)}` : '±0');
const summe = (liste, f) => liste.reduce((s, x) => s + f(x), 0);
const wuerfel = (seiten) => 1 + Math.floor(Math.random() * seiten);
const aktionenText = (n) => `${n} ${n === 1 ? 'Aktion' : 'Aktionen'}`;

const ZONEN = ['Kopf', 'Brust', 'Bauch', 'Linker Arm', 'Rechter Arm', 'Linkes Bein', 'Rechtes Bein'];
const RESSOURCEN = [
  { key: 'lep', name: 'Lebensenergie', kurz: 'LeP', icon: 'heart', farbe: 'leben' },
  { key: 'aup', name: 'Ausdauer', kurz: 'AuP', icon: 'wind', farbe: 'ausdauer' },
  { key: 'asp', name: 'Astralenergie', kurz: 'AsP', icon: 'star', farbe: 'astral' },
  { key: 'kap', name: 'Karmaenergie', kurz: 'KaP', icon: 'sun', farbe: 'karma' },
];
const ENERGIE_KEY = { AsP: 'asp', KaP: 'kap' };
const VERBRAUCH_TEXT = {
  angriff: 'Angriffsaktion',
  abwehr: 'Abwehraktion',
  angriff_und_abwehr: 'Angriffs- und Abwehraktion',
  alle: 'alle Aktionen der Kampfrunde',
};
// LL S. 11: Probenzuschlag und Kosten je Liturgiegrad.
const LITURGIEGRAD = { 0: { zuschlag: -2, kap: 2 }, 1: { zuschlag: 0, kap: 5 }, 2: { zuschlag: 2, kap: 10 }, 3: { zuschlag: 4, kap: 15 }, 4: { zuschlag: 6, kap: 20 } };
// WdS S. 67: Ausweichen nach Distanzklasse; gezielt doppelt.
const DK_AUSWEICHEN = { H: 4, N: 2, S: 1, P: 0 };
// Basisregelwerk S. 296: Patzertabelle Nahkampf (2W6).
const PATZER = [
  { bis: 2, name: 'Waffe zerstört', ini: 4, folge: 'Neue Waffe ziehen.' },
  { bis: 5, name: 'Sturz', ini: 2, folge: 'Liegt am Boden.', liegend: true },
  { bis: 8, name: 'Stolpern', ini: 2, folge: '' },
  { bis: 10, name: 'Waffe verloren', ini: 2, folge: 'GE-Probe zum Aufheben oder neue Waffe ziehen.' },
  { bis: 11, name: 'Selbst verletzt', ini: 3, folge: 'TP der eigenen Waffe.' },
  { bis: 12, name: 'Schwerer Eigentreffer', ini: 4, folge: 'Doppelte TP der eigenen Waffe.' },
];
// WdS S. 55: Dauer von „Waffe ziehen“ (in Klammern mit Schnellziehen).
const ZIEHEN = { guertel: { normal: 1, schnell: 0, text: 'Gürtel-, Arm- oder Brustscheide' }, ruecken: { normal: 2, schnell: 1, text: 'Rückenscheide' }, schild: { normal: 5, schnell: 3, text: 'Schild vom Rücken' } };

const WUCHT = { id: 'wucht', name: 'Wuchtschlag', typ: 'Angriffsaktion', erschwernis: 'Angriff +Ansage', basis: 0, ansage: true, verbrauch: 'angriff', text: 'Erhöht die Trefferpunkte um die Höhe der angesagten Erschwernis.' };
const FINTE = { id: 'finte', name: 'Finte', typ: 'Angriffsaktion', erschwernis: 'Angriff +Ansage', basis: 0, ansage: true, verbrauch: 'angriff', text: 'Erschwert die gegnerische Parade um die eigene Ansage.' };

const HELDEN = {
  kriegerin: {
    name: 'Rondrika Eisenhag', profession: 'Kriegerin aus Weiden', monogramm: 'RE',
    eigenschaften: { MU: 14, KL: 11, IN: 13, CH: 10, FF: 12, GE: 14, KO: 15, KK: 15 },
    ressourcen: { lep: { wert: 34, max: 38 }, aup: { wert: 31, max: 36 } },
    wundschwellen: [8, 15, 23], wunden: {}, kopfIni: 0,
    heldenIni: 17, iniHerkunft: 'INI-Basis 13 · Kampfreflexe +4', iniSeiten: 6, axxIni: 0,
    ausweichen: 10, ruestungsgewoehnung: 1,
    aufmerksamkeit: false, kampfgespuer: false, ausweichenI: false, defensiverKampfstil: false, klingenwand: false,
    schnellziehen: false, zauberkontrolle: false, konzentrationsstaerke: false, eisern: false, zaeherHund: false,
    selbstbeherrschung: 8, kriegskunst: 6,
    sf: ['Kampfreflexe', 'Linkhand', 'Schildkampf I', 'Schildkampf II', 'Rüstungsgewöhnung I', 'Wuchtschlag', 'Finte', 'Befreiungsschlag', 'Hammerschlag'],
    ruestung: [
      { id: 'kette', name: 'Kettenhemd', rs: 3, be: 3, an: true },
      { id: 'helm', name: 'Topfhelm', rs: 1, be: 1, an: true },
      { id: 'bein', name: 'Beinschienen', rs: 1, be: 2, an: false },
    ],
    waffen: [
      { id: 'schwert', name: 'Langschwert', talent: 'Schwerter', taw: 14, art: 'nah', dk: 'N', hand: 'einhändig', at: 16, pa: 13, tp: [1, 6, 4], ini: 0, scheide: 'guertel' },
      {
        id: 'bogen', name: 'Kurzbogen', talent: 'Bogen', taw: 12, art: 'fern', hand: 'beidhändig', fk: 15, tp: [1, 6, 4], ini: 0, ladezeit: 2, scheide: 'ruecken',
        entfernung: 2,
        entfernungen: [
          { name: 'sehr nah', fk: -2, tp: 1 }, { name: 'nah', fk: 0, tp: 1 }, { name: 'mittel', fk: 4, tp: 0 },
          { name: 'weit', fk: 8, tp: 0 }, { name: 'sehr weit', fk: 12, tp: -1 },
        ],
        geschoss: 0,
        geschosse: [{ name: 'Jagdpfeile', anzahl: 18, tp: 0 }, { name: 'Kriegspfeile', anzahl: 6, tp: 1 }],
      },
    ],
    aktiveWaffe: 'schwert',
    nebenhand: { name: 'Holzschild', art: 'schild', pa: 15, schildkampfII: true, turmschild: false },
    manoever: [
      WUCHT, FINTE,
      { id: 'befreiung', name: 'Befreiungsschlag', typ: 'Angriffsmanöver', erschwernis: 'Angriff +4 pro Gegner (verbraucht auch die Abwehraktion)', basis: 4, proGegner: true, verbrauch: 'angriff_und_abwehr', text: 'Rundumschlag gegen bis zu drei Gegner, der zurückdrängt und Niederwerfen einschließt.' },
      { id: 'hammer', name: 'Hammerschlag', typ: 'Angriffsaktion', erschwernis: 'Angriff +8 +Ansage (verbraucht alle Aktionen der KR)', basis: 8, ansage: true, verbrauch: 'alle', text: 'Verdreifacht die TP samt Schadensansage; bei Misslingen droht ein Passierschlag.', talente: ['Anderthalbhänder', 'Hiebwaffen', 'Infanteriewaffen', 'Kettenwaffen', 'Zweihandflegel', 'Zweihand-Hiebwaffen', 'Zweihandschwerter/-säbel'], zielPruefen: 'Nicht gegen sehr große Gegner oder große beziehungsweise sehr große Schilde.' },
    ],
    effekte: [], zauber: [], ritualKategorien: [], karmalSf: [], mirakel: false,
  },
  magier: {
    name: 'Corvin Aschentau', profession: 'Kampfmagier', monogramm: 'CA',
    eigenschaften: { MU: 13, KL: 15, IN: 14, CH: 12, FF: 12, GE: 13, KO: 12, KK: 11 },
    ressourcen: { lep: { wert: 27, max: 31 }, aup: { wert: 29, max: 33 }, asp: { wert: 26, max: 42 } },
    wundschwellen: [7, 13, 20], wunden: {}, kopfIni: 0,
    heldenIni: 11, iniHerkunft: 'INI-Basis 11', iniSeiten: 6, axxIni: 6,
    ausweichen: 12, ruestungsgewoehnung: 0,
    aufmerksamkeit: false, kampfgespuer: false, ausweichenI: true, defensiverKampfstil: false, klingenwand: true,
    schnellziehen: false, zauberkontrolle: false, konzentrationsstaerke: false, eisern: false, zaeherHund: false,
    selbstbeherrschung: 6, kriegskunst: 0,
    sf: ['Ausweichen I', 'Meisterparade', 'Klingenwand', 'Binden', 'Finte', 'Wuchtschlag'],
    ruestung: [
      { id: 'rock', name: 'Wattierter Waffenrock', rs: 2, be: 1, an: true },
      { id: 'arm', name: 'Lederarmschienen', rs: 1, be: 0, an: true },
    ],
    waffen: [
      { id: 'stab', name: 'Magierstab', talent: 'Stäbe', taw: 11, art: 'nah', dk: 'NS', hand: 'beidhändig', at: 13, pa: 14, tp: [1, 6, 1], ini: 0, stab: true, scheide: 'guertel' },
      {
        id: 'wurfdolch', name: 'Wurfdolch', talent: 'Wurfmesser', taw: 9, art: 'fern', hand: 'einhändig', fk: 12, tp: [1, 6, 0], ini: 0, ladezeit: 1, scheide: 'guertel',
        entfernung: 1,
        entfernungen: [
          { name: 'sehr nah', fk: -2, tp: 1 }, { name: 'nah', fk: 0, tp: 0 }, { name: 'mittel', fk: 4, tp: 0 },
          { name: 'weit', fk: 8, tp: -1 }, { name: 'sehr weit', fk: 12, tp: -2 },
        ],
        geschoss: 0,
        geschosse: [{ name: 'Wurfdolche', anzahl: 3, tp: 0 }],
      },
    ],
    aktiveWaffe: 'stab',
    nebenhand: null,
    manoever: [
      FINTE, WUCHT,
      { id: 'binden', name: 'Binden', typ: 'Abwehraktion', erschwernis: 'Abwehr +4', basis: 4, verbrauch: 'abwehr', abwehr: true, text: 'Bindet die gegnerische Waffe und erleichtert den eigenen Folgeangriff bei erschwerter gegnerischer Parade.' },
      { id: 'meisterparade', name: 'Meisterparade', typ: 'Abwehraktion', erschwernis: 'Abwehr +Ansage', basis: 0, ansage: true, verbrauch: 'abwehr', abwehr: true, text: 'Erschwert die eigene Parade, um die nächste eigene Angriffs- oder Abwehraktion zu verbessern.' },
      { id: 'klingenwand', name: 'Klingenwand', typ: 'Abwehraktion', erschwernis: '–', verbrauch: 'abwehr', abwehr: true, nurAnsage: true, text: 'Spaltet die Parade auf mehrere Angriffe auf und ignoriert den üblichen Überzahlabzug.' },
    ],
    // Axxeleratus und Armatrutz sind eigene, aufrechterhaltene Zauber (A) des Magiers.
    effekte: [
      { id: 'axx', name: 'Axxeleratus', wirkung: 'Beschleunigt: INI-Basis und GS verdoppelt, Abwehr verbessert', einheit: 'KR', rest: 3, gesamt: 5, aufrecht: true },
      { id: 'armatrutz', name: 'Armatrutz', wirkung: 'RS +2 ohne Behinderung', einheit: 'KR', rest: 4, gesamt: 6, rs: 2, aufrecht: true },
      { id: 'attributo', name: 'Attributo (KK)', wirkung: 'KK +2', einheit: 'SR', rest: 2, gesamt: 3 },
    ],
    // Zauberwerte aus assets/catalogs/house_rules_v1/magie.json; die ZfW sind Beispiele.
    zauber: [
      { id: 'axx', name: 'Axxeleratus Blitzgeschwind', probe: ['KL', 'GE', 'KO'], zfw: 11, dauer: '2 Aktionen', aktionen: 2, kosten: '7 AsP (Sch: 5 AsP)', kostenWert: 7, reichweite: 'selbst, 7 Schritt', wirkungsdauer: 'ZfP* mal 3 Kampfrunden (A)', ziel: 'Einzelperson, freiwillig', merkmale: 'Eigenschaften', modifikationen: 'Zauberdauer, Kosten, Zielobjekt (mehrere), Reichweite', effekt: { id: 'axx', faktor: 3, wirkung: 'Beschleunigt: INI-Basis und GS verdoppelt, Abwehr verbessert', aufrecht: true } },
      { id: 'blitz', name: 'Blitz dich find', probe: ['KL', 'IN', 'GE'], zfw: 12, dauer: '1 Aktion', aktionen: 1, kosten: '4 AsP (Sch: 3 AsP)', kostenWert: 4, reichweite: 'ZfW Schritt', wirkungsdauer: 'ZfW/2 Aktionen', ziel: 'Einzelwesen', merkmale: 'Einfluss', modifikationen: 'Zielobjekt (mehrere Wesen), Reichweite' },
      { id: 'fulmi', name: 'Fulminictus Donnerkeil', probe: ['IN', 'GE', 'KO'], zfw: 10, dauer: '2 Aktionen', aktionen: 2, kosten: '1 AsP pro zugefügtem Schadenspunkt', kostenWert: null, reichweite: '7 Schritt', wirkungsdauer: 'augenblicklich', ziel: 'Einzelwesen', merkmale: 'Schaden, Kraft', modifikationen: 'Zauberdauer, Reichweite' },
      { id: 'gardi', name: 'Gardianum Zauberschild', probe: ['KL', 'IN', 'KO'], zfw: 8, dauer: '2 Aktionen', aktionen: 2, kosten: 'nach Wahl, mindestens aber 3 AsP', kostenWert: 3, reichweite: '3 Schritt Radius um den Magier herum', wirkungsdauer: 'bis die aufgewendeten AsP aufgezehrt sind', ziel: 'Zone', merkmale: 'Antimagie, Kraft, Metamagie', modifikationen: 'Zauberdauer, Reichweite (Größe der Kuppel), Wirkungsdauer' },
      { id: 'armatrutz', name: 'Armatrutz', probe: ['IN', 'GE', 'KO'], zfw: 9, dauer: '3 Aktionen', aktionen: 3, kosten: 'zusätzlicher RS mal zusätzlicher RS minus ZfP*/2 in AsP, mindestens aber 4 AsP', kostenWert: 4, reichweite: 'selbst', wirkungsdauer: 'maximal eine Spielrunde (A)', ziel: 'Einzelperson, freiwillig', merkmale: 'Eigenschaften, Elementar (Erz)', modifikationen: 'Zauberdauer, Kosten, Reichweite (Berührung), Wirkungsdauer' },
      { id: 'plumbum', name: 'Plumbumbarum schwerer Arm', probe: ['CH', 'GE', 'KK'], zfw: 7, dauer: '3 Aktionen', aktionen: 3, kosten: '4 AsP plus 2 AsP für jeden Gegner', kostenWert: 6, reichweite: '7 Schritt', wirkungsdauer: '5 Kampfrunden', ziel: 'mehrere Wesen', merkmale: 'Einfluss', modifikationen: 'Zauberdauer, Erzwingen, Reichweite, Wirkungsdauer' },
      { id: 'igni', name: 'Ignifaxius', probe: ['KL', 'FF', 'KO'], zfw: 9, dauer: '4 Aktionen', aktionen: 4, kosten: 'Anzahl der TP in AsP', kostenWert: null, reichweite: '21 Schritt', wirkungsdauer: 'augenblicklich', ziel: 'Einzelwesen', merkmale: 'Schaden, Elementar (Feuer)', modifikationen: 'Zauberdauer, Kosten, Reichweite' },
      { id: 'paralysis', name: 'Paralysis starr wie Stein', probe: ['IN', 'CH', 'KK'], zfw: 6, dauer: '5 Aktionen', aktionen: 5, kosten: '11 AsP', kostenWert: 11, reichweite: '7 Schritt', wirkungsdauer: 'ZfP* Spielrunden', ziel: 'Einzelwesen', merkmale: 'Form, Elementar (Erz)', modifikationen: 'Zauberdauer, Zielobjekt (mehrere, freiwillig), Reichweite (selbst), Erzwingen' },
      { id: 'balsam', name: 'Balsam Salabunde', probe: ['KL', 'IN', 'CH'], zfw: 8, dauer: 'min. 5 Aktionen bis zum langsamen Einsetzen der ersten Heilwirkung, 1 SR insgesamt', aktionen: 5, kosten: '1 AsP pro LeP, mindestens aber 5 AsP', kostenWert: 5, reichweite: 'selbst, Berührung', wirkungsdauer: 'augenblicklich', ziel: 'Einzelwesen, freiwillig', merkmale: 'Heilung, Form', modifikationen: 'Zauberdauer, Kosten, Reichweite' },
    ],
    // Ritualkategorien legt der Held selbst an; die Inhalte sind seine Einträge.
    ritualKategorien: [{
      id: 'stab', name: 'Stabzauber', kenntnis: 'Ritualkenntnis (Gildenmagie)', wert: 9, energie: 'AsP',
      rituale: [
        { id: 'flammenschwert', name: 'Flammenschwert', probe: null, dauer: '1 Aktion', aktionen: 1, kosten: '2 AsP', kostenWert: 2, reichweite: 'selbst', wirkungsdauer: 'laut Eintrag des Helden', merkmale: 'Elementar (Feuer)', wirkung: 'Eintrag des Helden aus der Ritualkategorie.' },
        { id: 'seil', name: 'Seil des Adepten', probe: null, dauer: '1 Aktion', aktionen: 1, kosten: '1 AsP', kostenWert: 1, reichweite: 'selbst', wirkungsdauer: 'laut Eintrag des Helden', merkmale: 'Objekt', wirkung: 'Eintrag des Helden aus der Ritualkategorie.' },
        { id: 'bindung', name: 'Bindung des Stabes', probe: ['KL', 'IN', 'FF'], dauer: '1 Tag', aktionen: null, kosten: 'laut Eintrag des Helden', kostenWert: null, reichweite: 'Berührung', wirkungsdauer: 'permanent', merkmale: 'Objekt', wirkung: 'Eintrag des Helden aus der Ritualkategorie.' },
      ],
    }],
    karmalSf: [], mirakel: false,
  },
  geweihte: {
    name: 'Ailsa Sturmwacht', profession: 'Geweihte der Rondra', monogramm: 'AS',
    eigenschaften: { MU: 15, KL: 11, IN: 13, CH: 14, FF: 10, GE: 13, KO: 14, KK: 15 },
    ressourcen: { lep: { wert: 36, max: 40 }, aup: { wert: 33, max: 38 }, kap: { wert: 18, max: 24 } },
    wundschwellen: [7, 14, 21], wunden: {}, kopfIni: 0,
    heldenIni: 13, iniHerkunft: 'INI-Basis 13', iniSeiten: 6, axxIni: 0,
    ausweichen: 8, ruestungsgewoehnung: 1,
    aufmerksamkeit: true, kampfgespuer: false, ausweichenI: false, defensiverKampfstil: false, klingenwand: false,
    schnellziehen: false, zauberkontrolle: false, konzentrationsstaerke: false, eisern: false, zaeherHund: false,
    selbstbeherrschung: 10, kriegskunst: 4, liturgiekenntnis: 12,
    sf: ['Aufmerksamkeit', 'Rüstungsgewöhnung I', 'Wuchtschlag', 'Niederwerfen'],
    ruestung: [
      { id: 'kette', name: 'Kettenhemd', rs: 3, be: 3, an: true },
      { id: 'helm', name: 'Sturmhaube', rs: 1, be: 1, an: true },
    ],
    waffen: [
      { id: 'rondrakamm', name: 'Rondrakamm', talent: 'Zweihandschwerter/-säbel', taw: 13, art: 'nah', dk: 'N', hand: 'beidhändig', at: 15, pa: 12, tp: [2, 6, 2], ini: 0, scheide: 'ruecken' },
    ],
    aktiveWaffe: 'rondrakamm',
    nebenhand: null,
    manoever: [
      WUCHT,
      { id: 'niederwerfen', name: 'Niederwerfen', typ: 'Angriffsaktion', erschwernis: 'Angriff +4 +Ansage', basis: 4, ansage: true, verbrauch: 'angriff', text: 'Zwingt den Gegner mit einem schweren Schlag zu einer KK-Probe, um auf den Beinen zu bleiben.' },
    ],
    effekte: [],
    zauber: [],
    // Liturgien hat die App nicht als eigenes Modell: hier eine Ritualkategorie mit Liturgiekenntnis und KaP.
    // Grad, Dauer und Wirkungsdauer nach LL S. 84 f. (Schutzsegen) und S. 134 (Ehrenhafter Zweikampf).
    ritualKategorien: [{
      id: 'liturgien', name: 'Liturgien der Rondra', kenntnis: 'Liturgiekenntnis (Rondra)', wert: 12, energie: 'KaP', liturgie: true,
      rituale: [
        { id: 'schutzsegen', name: 'Schutzsegen', grad: 1, probe: ['MU', 'IN', 'CH'], dauer: 'Stoßgebet (10 Aktionen)', aktionen: 10, kosten: '5 KaP (Grad I)', kostenWert: 5, reichweite: 'Berührung', wirkungsdauer: 'LkP* in Spielrunden', ziel: 'Zone', merkmale: 'Allgemein', wirkung: 'Eintrag der Heldin aus der Ritualkategorie.' },
        { id: 'zweikampf', name: 'Ehrenhafter Zweikampf', grad: 2, probe: ['MU', 'IN', 'CH'], dauer: 'Stoßgebet (10 Aktionen)', aktionen: 10, kosten: '10 KaP (Grad II)', kostenWert: 10, reichweite: 'Sicht', wirkungsdauer: 'LkP* × 10 Kampfrunden', ziel: 'P+P', merkmale: 'Speziell (Rondra)', wirkung: 'Eintrag der Heldin aus der Ritualkategorie.' },
      ],
    }],
    // Beschreibungen aus karmale_sonderfertigkeiten.json.
    karmalSf: [
      { id: 'lk', name: 'Liturgiekenntnis (Rondra)', gruppe: 'Liturgie', text: 'Der Geweihte ist in der Lage, Liturgien und Anrufungen seiner Kirche zu erlernen und so durchzuführen, dass die göttliche Kraft in ihm zur Wirkung gelangt (nur für Geweihte).' },
      { id: 'aura', name: 'Aura der Heiligkeit', gruppe: 'Manifestation', text: 'Der Geweihte kann seine göttliche Kraft wie die Aura einer leibhaftigen Gottheit verströmen (nur für Geweihte).' },
    ],
    mirakel: true,
  },
};

const S = {
  heldKey: 'kriegerin', breite: 1200, thema: 'hell', ansicht: 'ruhe',
  held: structuredClone(HELDEN.kriegerin), gefecht: null, taktOffen: false, rundeAnimiert: false,
  katalogOffen: false, wirkenSuche: '', wirkenKurz: false,
  optLe: true, // Optionalregel „Niedrige Lebensenergie“ (WdS S. 58)
};
const frame = $('#frame');
const app = $('#app');
const dlg = $('#dlg');
const toastEl = $('#toast');
let toastTimer;

// ---------------------------------------------------------------- Rechnung
const aktiveWaffe = (h) => h.waffen.find((w) => w.id === h.aktiveWaffe);
const effektWirkt = (e) => e.einheit === 'dauerhaft' || e.rest > 0;
const iniStufe = (ini) => Math.min(3, Math.max(0, Math.trunc((ini - 11) / 10))); // WdS S. 79: über 20/30/40
const energieStand = (h, energie) => h.ressourcen[ENERGIE_KEY[energie]];

function leStufe(h) {
  const { wert, max } = h.ressourcen.lep;
  if (!S.optLe || wert >= max / 2) return 0;
  if (wert < max / 4) return 3;
  if (wert < max / 3) return 2;
  return 1;
}

function lageGrund(h) {
  const le = h.ressourcen.lep.wert;
  const ko = h.eigenschaften.KO * (h.zaeherHund ? 1.5 : 1);
  if (le < -ko) return { art: 'tot', text: `LE unter −${ko}: tot (WdS S. 57)` };
  if (le <= 0) return { art: 'lebensgefahr', text: 'LE 0 oder weniger: Lebensgefahr (WdS S. 57)' };
  const zone = ZONEN.find((z) => (h.wunden[z] || 0) >= 3);
  if (zone) return { art: 'kampfunfaehig', text: `dritte Wunde: ${zone}` };
  if (le <= 5 && !h.eisern && !h.zaeherHund) return { art: 'kampfunfaehig', text: 'LE 5 oder weniger (WdS S. 57)', ignorierbar: true };
  return null;
}

function berechne(h, g) {
  const waffe = aktiveWaffe(h);
  const an = h.ruestung.filter((r) => r.an);
  const beRoh = summe(an, (r) => r.be);
  const be = Math.max(0, beRoh - h.ruestungsgewoehnung);
  const armatrutz = h.effekte.find((e) => e.id === 'armatrutz' && effektWirkt(e));
  const rs = summe(an, (r) => r.rs) + (armatrutz ? armatrutz.rs : 0);
  const wunden = summe(Object.values(h.wunden), (n) => n);
  const wundMalus = 2 * wunden;
  const axx = h.effekte.some((e) => e.id === 'axx' && effektWirkt(e));
  const aufrecht = h.effekte.filter((e) => e.aufrecht && effektWirkt(e)).length;
  const iniOhneWurf = h.heldenIni + (axx ? h.axxIni : 0) + (waffe.ini || 0) - be - wundMalus;
  const iniKampf = iniOhneWurf + (g ? g.iniWurf : 0);
  const iniAktuell = iniKampf - (g ? g.iniVerlust : 0) - h.kopfIni;
  // HR S. 3: Die INI zu Beginn der ersten Aktion bestimmt die Boni der Runde (WdS S. 79).
  const iniBezug = g && g.iniBoniFixiert ? g.iniRundenbeginn : iniAktuell;
  const abwehrBonus = iniStufe(iniBezug);
  const nah = waffe.art === 'nah';
  const schildNutzbar = Boolean(h.nebenhand && h.nebenhand.art === 'schild' && nah && waffe.hand === 'einhändig');
  const e = waffe.art === 'fern' ? waffe.entfernungen[waffe.entfernung] : null;
  const geschoss = waffe.art === 'fern' ? waffe.geschosse[waffe.geschoss] : null;
  const tpMod = (e ? e.tp : 0) + (geschoss ? geschoss.tp : 0);
  const pa = nah ? waffe.pa + abwehrBonus - wundMalus : null;
  return {
    waffe, nah, be, beRoh, rs, armatrutz: armatrutz ? armatrutz.rs : 0, wunden, wundMalus, axx, aufrecht,
    iniOhneWurf, iniKampf, iniAktuell, iniBezug, abwehrBonus, freiBonus: abwehrBonus, leStufe: leStufe(h),
    at: nah ? waffe.at - wundMalus : null,
    fk: !nah ? waffe.fk - wundMalus : null,
    fkZiel: !nah ? waffe.fk - wundMalus - e.fk : null,
    entfernung: e, geschossDaten: geschoss,
    pa, schildNutzbar,
    schildPa: schildNutzbar ? h.nebenhand.pa + abwehrBonus - wundMalus : null,
    aw: h.ausweichen + (axx ? 2 : 0) + abwehrBonus,
    klingenwand: h.klingenwand && nah ? Math.trunc(pa / 2) + 2 : null,
    tpText: `${waffe.tp[0]}W${waffe.tp[1]}${vz(waffe.tp[2] + tpMod).replace('±0', '')}`,
    tpMod,
    lage: lageGrund(h),
  };
}

// Erschwernisse, die nicht schon im Wert stecken, mit Begründung (für AT, PA, AW, FK, Zauber, Talent).
function erschwernis(h, g, v, art) {
  const teile = [];
  const kampf = ['at', 'pa', 'aw', 'fk', 'schild'].includes(art);
  const nahkampf = ['at', 'pa', 'schild'].includes(art);
  if (g && nahkampf && g.haltung === 'liegend') teile.push(['liegend', 3]);
  if (g && nahkampf && g.haltung === 'kniend') teile.push(['kniend', 1]);
  if (g && art === 'aw' && g.haltung === 'kniend') teile.push(['kniend', 4]);
  if (g && (art === 'pa' || art === 'schild') && g.gegner > 1) teile.push([`${g.gegner - 1} weitere Gegner`, Math.min(2, g.gegner - 1)]);
  if (g && art === 'aw' && g.gegner > 1) teile.push([`${g.gegner - 1} weitere Gegner`, Math.min(4, 2 * (g.gegner - 1))]);
  if (g && g.bewegt && (nahkampf || art === 'aw')) teile.push(['nach Bewegen', 4]);
  if (g && nahkampf && g.nachLangfristig) teile.push(['nach längerfristiger Aktion', 4]);
  if (g && kampf && g.naechsteErschwernis) teile.push(['misslungene Ansage', g.naechsteErschwernis]);
  if (v.aufrecht && kampf) teile.push([`${v.aufrecht} aufrechterhaltene Zauber`, v.aufrecht]);
  if (v.aufrecht && (art === 'zauber' || art === 'talent')) teile.push([`${v.aufrecht} aufrechterhaltene Zauber`, 3 * v.aufrecht]);
  if (v.leStufe && kampf) teile.push(['niedrige LE', v.leStufe]);
  if (v.leStufe && (art === 'zauber' || art === 'talent')) teile.push(['niedrige LE', 3 * v.leStufe]);
  if (g && art === 'aw' && g.mirakel && g.mirakel.ziel === 'aw') teile.push(['Mirakel', -g.mirakel.bonus]);
  return { summe: summe(teile, (t) => t[1]), teile };
}
const erschwernisText = (ers) => ers.teile.map(([grund, wert]) => `${grund} ${vz(wert)}`).join(', ');

function ausweichenMoeglich(h, g) {
  if (g && g.haltung === 'liegend') return 'Liegend ist kein Ausweichen möglich (WdS S. 58).';
  if (g && g.gegner >= 4) return 'Umstellt (4+ Gegner): Ausweichen unmöglich (WdS S. 67).';
  return null;
}

function umwandlung(h, w) {
  if (w.art !== 'nah') return { gesperrt: 'Umwandeln gilt nur für Nahkampfwaffen.' };
  const atPa = { erschw: 4, grund: '' };
  const paAt = { erschw: 4, grund: '' };
  if (w.stab && w.taw >= 10) {
    Object.assign(atPa, { erschw: 0, grund: 'Stab ab TaW 10' });
    Object.assign(paAt, { erschw: 0, grund: 'Stab ab TaW 10' });
  }
  if (h.nebenhand && h.nebenhand.art === 'schild' && w.hand === 'einhändig') Object.assign(atPa, { erschw: 0, grund: 'mit Schild' });
  if (h.defensiverKampfstil) Object.assign(atPa, { erschw: 0, grund: 'Defensiver Kampfstil' });
  return { atPa, paAt };
}

function aktionsplan(h, g, v) {
  const um = umwandlung(h, v.waffe);
  const marken = [];
  const zweiSchild = g.zweiSchildparaden && v.schildNutzbar && h.nebenhand.schildkampfII;
  // Gesperrt vor allem anderen: Lage, Patzer, Sprinten.
  let rundeGesperrt = null;
  if (v.lage && v.lage.art !== 'kampfunfaehig') rundeGesperrt = v.lage.text;
  else if (v.lage && !(g.kfIgnoriert > 0)) rundeGesperrt = `kampfunfähig: ${v.lage.text}`;
  else if (g.patzer) rundeGesperrt = 'Patzer: weitere Aktionen der Runde verloren';
  const angriffSperre = rundeGesperrt || (v.iniAktuell < 0 ? 'INI unter 0: keine Angriffsaktion (WdS S. 56)' : null);
  const abwehrSperre = rundeGesperrt;
  if (g.umwandeln === 'at-pa' && !um.gesperrt) {
    marken.push({ id: 'a1', art: 'abwehr', titel: 'Abwehr', sub: 'umgewandelt · jederzeit', erschw: um.atPa.erschw, grund: um.atPa.grund, waffe: v.waffe.id, gesperrt: abwehrSperre });
  } else {
    marken.push({ id: 'a1', art: 'angriff', titel: 'Angriff', sub: `bei INI ${minus(v.iniAktuell)}`, waffe: v.waffe.id, gesperrt: angriffSperre });
  }
  if (g.umwandeln === 'pa-at' && !um.gesperrt) {
    const phase = v.iniAktuell - 8;
    marken.push({
      id: 'a2', art: 'angriff', titel: 'Angriff', sub: phase >= 0 ? `umgewandelt · bei INI ${phase}` : 'umgewandelt',
      erschw: um.paAt.erschw, grund: um.paAt.grund, waffe: v.waffe.id, gesperrt: angriffSperre || (phase < 0 ? 'INI − 8 liegt unter 0 (WdS S. 82)' : null),
    });
  } else {
    marken.push({ id: 'a2', art: 'abwehr', titel: zweiSchild ? 'Schildparade 1' : 'Abwehr', sub: zweiSchild ? 'Schildkampf II' : 'jederzeit', waffe: zweiSchild ? 'schild' : v.waffe.id, nur: zweiSchild ? 'schild' : null, gesperrt: abwehrSperre });
  }
  if (zweiSchild) {
    // Errata WdS S. 71 f.: Zusatzaktionen nur zusätzlich zu einer regulären Kampfaktion.
    const beideLang = ['a1', 'a2'].every((id) => g.lang[id]);
    const grund = abwehrSperre || (v.be > 4 ? `BE ${v.be} über 4 (WdS S. 72)` : null) || (beideLang ? 'Beide Aktionen für längerfristige Handlungen genutzt (Errata WdS)' : null);
    marken.push({ id: 'z1', art: 'abwehr', titel: 'Schildparade 2', sub: 'Schildkampf II', waffe: 'schild', nur: 'schild', gesperrt: grund });
  }
  marken.push({ id: 'f1', art: 'frei', titel: 'frei', sub: 'zur Aktion', gesperrt: rundeGesperrt });
  marken.push({ id: 'f2', art: 'frei', titel: 'frei', sub: 'zur Abwehr', gesperrt: rundeGesperrt });
  for (let i = 0; i < v.freiBonus; i += 1) marken.push({ id: `fb${i + 1}`, art: 'frei', titel: 'frei', sub: 'hohe INI', gesperrt: rundeGesperrt });
  const aktiv = marken.filter((m) => m.art !== 'frei' && !m.gesperrt);
  const jeWaffe = {};
  aktiv.forEach((m) => { jeWaffe[m.waffe] = (jeWaffe[m.waffe] || 0) + 1; });
  // Sperrt die Lage die ganze Runde, steht der Grund im Banner; die Marken sagen nur „gesperrt“.
  if (rundeGesperrt) marken.forEach((m) => { if (m.gesperrt === rundeGesperrt) m.kurz = 'gesperrt'; });
  const warnungen = [];
  if (aktiv.length > 3) warnungen.push(`${aktiv.length} Aktionen – höchstens 3 je Kampfrunde (WdS S. 73)`);
  if (Object.values(jeWaffe).some((n) => n > 2)) warnungen.push('Mehr als 2 Aktionen mit einer Waffe (WdS S. 73)');
  return { marken, um, zweiSchild, warnungen };
}

function ansageGesperrt(h, g, plan) {
  if (h.kampfgespuer) return null;
  const verbraucht = plan.marken.some((m) => m.art !== 'frei' && g.verbraucht[m.id]);
  if (!verbraucht) return null;
  return h.aufmerksamkeit
    ? 'Ansage nur bis zur ersten eigenen Aktion (Aufmerksamkeit, WdS S. 81).'
    : 'Ansage nur zu Rundenbeginn – es wurde schon eine Aktion genutzt (WdS S. 81).';
}

// ---------------------------------------------------------------- Aktionen verbrauchen
function aktuellerPlan() {
  const v = berechne(S.held, S.gefecht);
  return { v, plan: aktionsplan(S.held, S.gefecht, v) };
}

function offeneMarke(art) {
  const { plan } = aktuellerPlan();
  return plan.marken.find((m) => m.art === art && !m.gesperrt && !S.gefecht.verbraucht[m.id]);
}

// Verbraucht die nächste Marke einer Art. `lang` kennzeichnet Aktionen einer längerfristigen Handlung.
function verbrauche(art, label, lang = false) {
  const m = offeneMarke(art);
  if (!m) return null;
  fixiereIniBoni();
  S.gefecht.verbraucht[m.id] = label;
  if (lang) S.gefecht.lang[m.id] = true;
  return m.id;
}

// Eine reguläre Aktion: zuerst die Angriffs-, dann die Abwehraktion (WdS S. 53).
function verbraucheAktion(label, lang = true) {
  const { plan } = aktuellerPlan();
  const g = S.gefecht;
  const m = plan.marken.find((x) => ['a1', 'a2'].includes(x.id) && !x.gesperrt && !g.verbraucht[x.id]);
  if (!m) return null;
  fixiereIniBoni();
  g.verbraucht[m.id] = label;
  if (lang) g.lang[m.id] = true;
  return m.id;
}

function verbraucheNach(verbrauch, label, art = null) {
  const kosten = pruefeAktionskosten(verbrauch, art);
  if (kosten.grund) return kosten.grund;
  fixiereIniBoni();
  kosten.marken.forEach((m) => { S.gefecht.verbraucht[m.id] = label; });
  return null;
}

// Eine Kampfaktion als zweite Aktion nach einer längerfristigen gilt als umgewandelt (WdS S. 55).
function merkeLangfristig() {
  const g = S.gefecht;
  g.nachLangfristig = Object.keys(g.lang).length > 0;
}

function protokolliere(text, ergebnis = '', detail = '') {
  if (!S.gefecht) return;
  S.gefecht.log.unshift({ kr: S.gefecht.kr, text, ergebnis, detail });
  S.gefecht.log = S.gefecht.log.slice(0, 40);
}

// ---------------------------------------------------------------- Laufende Handlung (WdS S. 53/55)
const HANDLUNG_FOLGE = {
  zauber: 'Der Zauber misslingt (WdS S. 55, LC S. 5).',
  liturgie: 'Die Liturgie misslingt.',
  laden: 'Die bisherigen Lade-Aktionen verfallen (WdS S. 55).',
  orientieren: 'Orientieren braucht zwei ungestörte Aktionen (WdS S. 56).',
};

// Jede andere Aktion außer den Freien Aktionen Schritt und Drehen unterbricht eine laufende Handlung.
function mitUnterbrechung(beschreibung, weiter) {
  const hd = S.gefecht && S.gefecht.handlung;
  if (!hd || hd.stand >= hd.gesamt) { weiter(); return; }
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">${esc(hd.name)} unterbrechen?</h2>
      <p>${esc(hd.name)} läuft noch (${hd.stand} von ${aktionenText(hd.gesamt)}). ${esc(beschreibung)} unterbricht die Handlung.</p>
      <p class="ergebnis">${esc(HANDLUNG_FOLGE[hd.typ] || 'Die Handlung verfällt.')}${hd.typ === 'zauber' || hd.typ === 'liturgie' ? ' Zauberer und Geweihte können währenddessen auch nicht abwehren.' : ''}</p></div>
    <div class="dlg-aktionen">${abbrechen('Nicht unterbrechen')}<button type="button" class="btn btn-gefahr" data-dlg="ja">Unterbrechen</button></div>`, {
    ja: () => { dlg.close(); brichHandlungAb(true, false); weiter(); },
  });
}

function starteHandlung(daten) {
  const g = S.gefecht;
  if (g.handlung) { zeigeToast(`${g.handlung.name} läuft noch – erst abschließen oder abbrechen.`, 'alert'); return false; }
  g.handlung = { stand: 0, ...daten };
  protokolliere(`${daten.name} begonnen`, '', aktionenText(daten.gesamt));
  setzeHandlungFort();
  return true;
}

function setzeHandlungFort() {
  const g = S.gefecht;
  const hd = g.handlung;
  if (!hd || hd.stand >= hd.gesamt) return;
  const { v } = aktuellerPlan();
  if (v.lage && !(v.lage.art === 'kampfunfaehig' && g.kfIgnoriert > 0)) { zeigeToast(`Nicht möglich: ${v.lage.text}`, 'alert'); return; }
  const kurz = hd.kurz || hd.name.split(' ')[0];
  if (!verbraucheAktion(kurz)) {
    zeigeToast(v.iniAktuell < 0 ? 'INI unter 0: nur eine Aktion je Runde (LC S. 5) – weiter in der nächsten Kampfrunde.' : 'Keine Aktion mehr offen – weiter in der nächsten Kampfrunde.', 'hourglass');
    render();
    return;
  }
  hd.stand += 1;
  if (hd.typ === 'laden') g.ladung[hd.waffe] = (g.ladung[hd.waffe] || 0) + 1;
  merkeLangfristig();
  if (hd.stand >= hd.gesamt) handlungFertig();
  render();
}

function brichHandlungAb(neuZeichnen = true, misslungen = true) {
  const g = S.gefecht;
  const hd = g.handlung;
  if (!hd) return;
  protokolliere(`${hd.name} abgebrochen`, misslungen ? '' : 'unterbrochen', `${hd.stand} von ${aktionenText(hd.gesamt)}`);
  if (hd.typ === 'laden') g.ladung[hd.waffe] = 0;
  g.handlung = null;
  // Ein unterbrochener Zauber kostet wie ein misslungener die Hälfte (LC S. 5).
  if ((hd.typ === 'zauber' || hd.typ === 'liturgie') && hd.eintrag) {
    const e = findeWirken(S.held, hd.eintrag.typ, hd.eintrag.id);
    if (e) setTimeout(() => danach(() => kostenDialog(e, { gelungen: false, abgebrochen: true })), 0);
  }
  if (neuZeichnen) render();
}

function handlungFertig() {
  const g = S.gefecht;
  const hd = g.handlung;
  const h = S.held;
  if (hd.typ === 'laden') {
    g.ladung[hd.waffe] = aktiveWaffe(h).ladezeit;
    protokolliere(`Geladen: ${hd.name.replace('Nachladen: ', '')}`);
    g.handlung = null;
    zeigeToast('Geladen.', 'bow');
  } else if (hd.typ === 'ziehen') {
    h.aktiveWaffe = hd.waffe;
    protokolliere(`Waffe gezogen: ${aktiveWaffe(h).name}`);
    g.handlung = null;
    g.umwandeln = 'keine';
    g.zweiSchildparaden = false;
    zeigeToast(`${aktiveWaffe(h).name} ist gezogen.`, 'swap');
  } else if (hd.typ === 'orientieren') {
    g.handlung = null;
    orientierenProbe(false);
  } else if (hd.typ === 'zauber' || hd.typ === 'liturgie') {
    const e = findeWirken(h, hd.eintrag.typ, hd.eintrag.id);
    g.handlung = null;
    setTimeout(() => danach(() => kostenDialog(e, hd.ergebnis)), 0);
  } else {
    protokolliere(`${hd.name} abgeschlossen`);
    g.handlung = null;
    zeigeToast(`${hd.name} abgeschlossen.`, 'check');
  }
}

// ---------------------------------------------------------------- Proben
function w20(titel, ziel, art) {
  const wurf = wuerfel(20);
  const r = { wurf, ziel, gelungen: wurf === 1 || (wurf !== 20 && wurf <= ziel), glueck: false, patzer: null, bestaetigung: null };
  if (wurf === 1 || (wurf === 20 && ['at', 'pa', 'schild'].includes(art))) {
    r.bestaetigung = wuerfel(20);
    const bestaetigt = r.bestaetigung <= ziel;
    if (wurf === 1) r.glueck = bestaetigt;
    if (wurf === 20 && !bestaetigt) r.patzer = patzerWurf();
  }
  return r;
}

function patzerWurf() {
  const w = wuerfel(6) + wuerfel(6);
  return { w, ...PATZER.find((p) => w <= p.bis) };
}

function dreiW20(werte, pool) {
  const w = [wuerfel(20), wuerfel(20), wuerfel(20)];
  let rest = pool;
  w.forEach((x, i) => { if (x > werte[i]) rest -= x - werte[i]; });
  let gelungen = rest >= 0;
  if (w.filter((x) => x === 20).length >= 2) gelungen = false;
  if (w.filter((x) => x === 1).length >= 2) gelungen = true;
  return { w, werte, gelungen, punkte: gelungen ? Math.min(pool, Math.max(0, rest)) : null };
}

function talentProbe(name, wert, eigenschaften, zuschlag) {
  const h = S.held;
  const { v } = aktuellerPlan();
  const ers = erschwernis(h, S.gefecht, v, 'talent');
  return dreiW20(eigenschaften.map((a) => h.eigenschaften[a]), wert - zuschlag - ers.summe);
}

// Würfelt AT, PA, Schild oder FK samt Folgen (Patzer, glückliche Abwehr, Ansage).
function kampfwurf({ art, titel, basis, verbrauch, label, ansage = 0, zusatz = 0 }) {
  const h = S.held;
  const g = S.gefecht;
  const { v } = aktuellerPlan();
  const kosten = verbrauch ? pruefeAktionskosten(verbrauch, art) : { marken: [], zuschlag: 0 };
  if (kosten.grund) { zeigeToast(kosten.grund, 'alert'); return null; }
  const ers = erschwernis(h, g, v, art);
  const umwandeln = kosten.zuschlag || 0;
  const ziel = basis - ers.summe - zusatz - ansage - umwandeln;
  fixiereIniBoni();
  const r = w20(titel, ziel, art);
  g.naechsteErschwernis = 0;
  if (g.mirakel && art === 'aw') g.mirakel = null;
  kosten.marken.forEach((m) => { g.verbraucht[m.id] = `${label} ${r.wurf}/${ziel}`; });
  if (['at', 'pa', 'schild', 'fk'].includes(art)) g.lang = {};
  g.nachLangfristig = false;
  let text = `W20 ${r.wurf} gegen ${minus(ziel)}`;
  if (umwandeln) text += ` (Umwandeln +${umwandeln})`;
  if (ers.teile.length) text += ` (${erschwernisText(ers)})`;
  if (r.glueck && ['pa', 'schild'].includes(art)) {
    // Basisregelwerk S. 296: bestätigte glückliche Parade zählt nicht als Aktion.
    kosten.marken.forEach((m) => { delete g.verbraucht[m.id]; });
  }
  protokolliere(titel, r.gelungen ? 'gelungen' : 'misslungen', text);
  if (!r.gelungen && ansage > 0) g.naechsteErschwernis = ansage; // misslungene Ansage erschwert die nächste Aktion
  if (r.patzer) {
    g.patzer = true;
    g.iniVerlust += r.patzer.ini;
    if (r.patzer.liegend) g.haltung = 'liegend';
    protokolliere(`Patzer: ${r.patzer.name}`, `INI −${r.patzer.ini}`, `2W6 ${r.patzer.w}`);
  }
  return { r, ziel, ers, fehlt: null };
}

function zeigeWurfErgebnis(titel, art, res) {
  const { r, ziel, fehlt } = res;
  const abwehr = ['pa', 'aw', 'schild'].includes(art);
  if (r.patzer) {
    oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">Patzer!</h2>
        <p class="ergebnis gefahr">W20 ${r.wurf}, Bestätigung ${r.bestaetigung} gegen ${minus(ziel)} misslungen.</p>
        <dl class="tabelle-kv"><dt>Patzertabelle</dt><dd>2W6 ${r.patzer.w}: <b>${esc(r.patzer.name)}</b></dd><dt>Folgen</dt><dd>INI −${r.patzer.ini}${r.patzer.folge ? ` · ${esc(r.patzer.folge)}` : ''}<br>Alle weiteren Aktionen dieser Runde sind verloren.</dd></dl>
        <p class="legende">Basisregelwerk S. 296</p></div>
      <div class="dlg-aktionen"><button type="button" class="btn btn-primaer" data-dlg="schliessen">Verstanden</button></div>`);
    return;
  }
  if (abwehr && !r.gelungen) {
    oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">${esc(titel)} misslungen</h2>
        <p class="ergebnis">W20 ${r.wurf} gegen ${minus(ziel)} – der Treffer sitzt.</p>${res.folge ? `<p>${esc(res.folge)}</p>` : ''}</div>
      <div class="dlg-aktionen">${abbrechen('Schließen')}<button type="button" class="btn btn-primaer" data-dlg="schaden">Schaden erhalten</button></div>`, {
      schaden: () => dialogSchaden(),
    });
    return;
  }
  let text = `${titel}: W20 ${r.wurf} gegen ${minus(ziel)} – ${r.gelungen ? 'gelungen' : 'misslungen'}`;
  if (r.bestaetigung && r.wurf === 1 && r.glueck) {
    text += ['at', 'fk'].includes(art)
      ? ' · kritisch bestätigt: TP verdoppeln, keine zusätzliche Wunde (Hausregel)'
      : ['pa', 'schild'].includes(art) ? ' · glücklich bestätigt: zählt nicht als Aktion' : ' · glücklich bestätigt';
  } else if (r.bestaetigung && r.wurf === 1) text += ' · nicht bestätigt';
  if (r.bestaetigung && r.wurf === 20) text += ' · Patzer abgewendet';
  if (res.folge) text += ` · ${res.folge}`;
  if (fehlt) text += ` · Plan: ${fehlt}`;
  zeigeToast(text, fehlt ? 'alert' : 'dice');
}

function schadenWurf(v) {
  const [anz, seiten, plus] = v.waffe.tp;
  let w = 0;
  for (let i = 0; i < anz; i += 1) w += wuerfel(seiten);
  const tp = w + plus + v.tpMod;
  protokolliere(`Trefferpunkte (${v.waffe.name})`, `${tp} TP`, `${anz}W${seiten} ${w} ${vz(plus + v.tpMod)}`);
  zeigeToast(`Trefferpunkte: ${tp} (W${seiten}: ${w})`, 'dice');
}

function wurf(art) {
  const g = S.gefecht;
  if (!g) return;
  const h = S.held;
  const { v } = aktuellerPlan();
  const w = v.waffe;
  if (art === 'tp') { schadenWurf(v); render(); return; }
  if (art === 'aw') { dialogAusweichen(); return; }
  const sperre = kampfOption(art, h, g, v).grund;
  if (sperre) { zeigeToast(sperre, 'alert'); return; }
  const titel = { at: `Attacke (${w.name})`, pa: `Parade (${w.name})`, schild: `Schildparade (${h.nebenhand ? h.nebenhand.name : ''})`, fk: `Schuss (${w.name})` }[art];
  mitUnterbrechung(titel, () => {
    if (art === 'fk') {
      const res = kampfwurf({ art: 'fk', titel: `${titel}, ${v.entfernung.name}`, basis: v.fkZiel, verbrauch: 'angriff', label: 'FK' });
      if (!res) return;
      g.ladung[w.id] = 0;
      if (v.geschossDaten.anzahl > 0) v.geschossDaten.anzahl -= 1;
      zeigeWurfErgebnis(titel, 'fk', res);
    } else {
      const basis = { at: v.at, pa: v.pa, schild: v.schildPa }[art];
      const res = kampfwurf({ art, titel, basis, verbrauch: art === 'at' ? 'angriff' : 'abwehr', label: { at: 'AT', pa: 'PA', schild: 'Schild' }[art] });
      if (!res) return;
      zeigeWurfErgebnis(titel, art, res);
    }
    render();
  });
}

function kampfSperre(v, art) {
  const g = S.gefecht;
  if (v.lage && !(v.lage.art === 'kampfunfaehig' && g.kfIgnoriert > 0)) return `Keine Kampfaktion möglich: ${v.lage.text}`;
  if (g.desorientiert && art !== 'aw') return 'Desorientiert nach dem Ausweichen: erst Aktion Position, bis dahin nur Ausweichen (WdS S. 68).';
  if (g.sprint) return 'Wer sprintet, kann weder angreifen noch abwehren (WdS S. 55).';
  return null;
}

// ---------------------------------------------------------------- Ausweichen (WdS S. 66–68, HR S. 2 f.)
function dialogAusweichen() {
  const h = S.held;
  const g = S.gefecht;
  const { v } = aktuellerPlan();
  const sperre = kampfOption('aw', h, g, v).grund;
  if (sperre) { zeigeToast(sperre, 'alert'); return; }
  const frei = pruefeAktionskosten('frei', 'aw');
  const gezielt = h.ausweichenI ? pruefeAktionskosten('abwehr', 'aw') : { grund: 'Braucht die SF Ausweichen I.' };
  let variante = frei.grund ? 'gezielt' : 'frei';
  let dk = g.distanzklasse;
  const zielwert = () => {
    const ers = erschwernis(h, g, v, 'aw');
    const kosten = pruefeAktionskosten(variante === 'frei' ? 'frei' : 'abwehr', 'aw');
    const dkMod = dk ? DK_AUSWEICHEN[dk] * (variante === 'gezielt' ? 2 : 1) : null;
    const zuschlag = kosten.zuschlag || 0;
    return { ziel: dk ? v.aw - ers.summe - dkMod - zuschlag : null, ers, dkMod, kosten, zuschlag };
  };
  const aktualisiere = () => {
    const { ziel, ers, dkMod, kosten, zuschlag } = zielwert();
    dlg.querySelectorAll('[data-dlg^="var-"]').forEach((b) => b.setAttribute('aria-checked', String(b.dataset.dlg === `var-${variante}`)));
    dlg.querySelectorAll('[data-dlg^="dk-"]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.dlg === `dk-${dk}`)));
    const teile = [`AW ${v.aw}`, ...(dk ? [`DK ${dk} +${dkMod}${variante === 'gezielt' ? ' (doppelt)' : ''}`] : []), ...ers.teile.map(([gr, w]) => `${gr} ${vz(w)}`)];
    if (zuschlag) teile.push(`Umwandeln +${zuschlag}`);
    $('#aw-ergebnis').innerHTML = dk ? `${esc(teile.join(' · '))} → Zielwert <b>${minus(ziel)}</b>` : 'Aktuelle Distanzklasse auswählen; der Zielwert steht dann fest.';
    $('#aw-verbrauch').textContent = kosten.grund || (variante === 'frei'
      ? 'Eine Freie Aktion; immer INI −4. Bei Gelingen desorientiert, bis Position + Orientieren folgt.'
      : 'Eine passende Abwehraktion; bei Misslingen INI −2.');
    dlg.querySelector('[data-dlg="los"]').disabled = !dk || Boolean(kosten.grund);
  };
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">Ausweichen</h2>
      <div class="auswahl" role="radiogroup" aria-label="Art des Ausweichens">
        <button type="button" class="wahl" role="radio" data-dlg="var-frei" ${frei.grund ? 'disabled' : ''}><b>Freies Ausweichen</b><small>${esc(frei.grund || 'Freie Aktion · immer INI −4 · bei Gelingen desorientiert')}</small></button>
        <button type="button" class="wahl" role="radio" data-dlg="var-gezielt" ${gezielt.grund ? 'disabled' : ''}><b>Gezieltes Ausweichen</b><small>${esc(gezielt.grund || 'Abwehraktion · bleibt kampfbereit · misslungen: INI −2 · DK-Zuschlag doppelt')}</small></button>
      </div>
      <div class="formzeile"><span class="etikett">Aktuelle Distanzklasse</span><div class="seg" role="group" aria-label="Distanzklasse">${Object.keys(DK_AUSWEICHEN).map((k) => `<button type="button" data-dlg="dk-${k}">${k}</button>`).join('')}</div></div>
      <div class="ergebnis" id="aw-ergebnis"></div>
      <p class="legende" id="aw-verbrauch"></p>
      <p class="legende">Gegnerzahl, Haltung und Mirakel kommen aus dem Takt. Hausregel: Freies Ausweichen verändert die DK nicht; gezielt ist eine Stufe zurück optional (zwei mit weiteren +4). DK-Wechsel hier nach dem Wurf manuell erfassen.</p></div>
    <div class="dlg-aktionen">${abbrechen()}<button type="button" class="btn btn-primaer" data-dlg="los" disabled>${icon('dice')}Ausweichen würfeln</button></div>`, {
    'var-frei': () => { if (!frei.grund) { variante = 'frei'; aktualisiere(); } },
    'var-gezielt': () => { if (!gezielt.grund) { variante = 'gezielt'; aktualisiere(); } },
    ...Object.fromEntries(Object.keys(DK_AUSWEICHEN).map((k) => [`dk-${k}`, () => { dk = k; aktualisiere(); }])),
    los: () => {
      const { ziel, kosten } = zielwert();
      if (!dk || kosten.grund) return;
      g.distanzklasse = dk;
      dlg.close();
      mitUnterbrechung('Ausweichen', () => ausweichenWuerfeln(variante, ziel));
    },
  });
  aktualisiere();
}

function ausweichenWuerfeln(variante, ziel) {
  const g = S.gefecht;
  const kosten = pruefeAktionskosten(variante === 'frei' ? 'frei' : 'abwehr', 'aw');
  const { v } = aktuellerPlan();
  const sperre = kampfSperre(v, 'aw') || ausweichenMoeglich(S.held, g) || kosten.grund;
  if (sperre || !g.distanzklasse || ziel === null) { zeigeToast(sperre || 'Aktuelle DK auswählen.', 'alert'); return; }
  fixiereIniBoni();
  const r = w20('Ausweichen', ziel, 'aw');
  g.naechsteErschwernis = 0;
  if (g.mirakel && g.mirakel.ziel === 'aw') g.mirakel = null;
  const label = `AW ${r.wurf}/${ziel}`;
  kosten.marken.forEach((m) => { g.verbraucht[m.id] = label; });
  let folge = '';
  if (variante === 'frei') {
    g.iniVerlust += 4;
    if (r.gelungen) { g.desorientiert = true; folge = 'INI −4, desorientiert: Position + Orientieren nötig.'; } else folge = 'INI −4.';
  } else if (!r.gelungen) {
    g.iniVerlust += 2;
    folge = 'INI −2.';
  }
  const titel = variante === 'frei' ? 'Ausweichen' : 'Gezieltes Ausweichen';
  protokolliere(titel, r.gelungen ? 'gelungen' : 'misslungen', `W20 ${r.wurf} gegen ${minus(ziel)} · ${folge}`);
  zeigeWurfErgebnis(titel, 'aw', { r, ziel, fehlt: null, folge });
  render();
}

// ---------------------------------------------------------------- Weitere Aktionen (WdS S. 55 f.)
function aktionenKatalog(h, g, v) {
  const liegend = g.haltung === 'liegend';
  const orientKosten = h.aufmerksamkeit ? 1 : 2;
  const waffen = h.waffen.filter((w) => w.id !== h.aktiveWaffe);
  return [
    { gruppe: 'Aktionen', id: 'position', name: 'Position', kosten: '1 Aktion', text: g.desorientiert ? 'Nach dem Ausweichen dem Gegner wieder zuwenden; laut Hausregel zugleich Orientieren.' : g.haltung !== 'stehend' ? `Aufstehen: ${g.haltung} → ${g.haltung === 'liegend' ? 'kniend (oder mit GE-Probe stehend)' : 'stehend'}.` : 'Kampfstil wechseln, günstigere Position einnehmen.', quelle: 'WdS S. 55, 58' },
    { gruppe: 'Aktionen', id: 'bewegen', name: 'Bewegen', kosten: '1 Aktion', text: 'Bis zur GS weit, ohne PA-Einbußen. Kampfaktionen danach in dieser Runde +4.', quelle: 'WdS S. 55' },
    { gruppe: 'Längerfristig', id: 'orientieren', name: 'Orientieren', kosten: aktionenText(orientKosten), text: h.aufmerksamkeit ? 'Ohne Probe: INI wie mit einer 6 gewürfelt, Verluste aus Kampfaktionen weg.' : `IN-Probe (Kriegskunst ${h.kriegskunst}: −${Math.floor(h.kriegskunst / 2)}): INI wie mit einer 6 gewürfelt.`, sperre: liegend ? 'Liegend nicht möglich (WdS S. 58).' : null, quelle: 'WdS S. 56, 74' },
    ...(v.waffe.art === 'fern' ? [{ gruppe: 'Längerfristig', id: 'laden', name: `Nachladen: ${v.waffe.name}`, kosten: aktionenText(v.waffe.ladezeit), text: 'Lade-Aktionen ohne Unterbrechung, sonst verfallen sie.', quelle: 'WdS S. 55' }] : []),
    ...waffen.map((w) => {
      const z = ZIEHEN[w.scheide];
      const n = h.schnellziehen ? z.schnell : z.normal;
      return { gruppe: 'Längerfristig', id: `ziehen:${w.id}`, name: `Waffe ziehen: ${w.name}`, kosten: n === 0 ? 'Freie Aktion' : aktionenText(n), text: `${z.text}${h.schnellziehen ? ' (Schnellziehen)' : ''}.`, quelle: 'WdS S. 55' };
    }),
    { gruppe: 'Längerfristig', id: 'sprinten', name: 'Sprinten', kosten: '2 Aktionen', text: 'Dreifache GS; diese Runde kein Angriff, keine Abwehr, kein Ausweichen.', quelle: 'WdS S. 55' },
    { gruppe: 'Längerfristig', id: 'gegenstand', name: 'Gegenstand benutzen', kosten: '10 / 20 Aktionen', text: 'Gürteltasche 10, Rucksack 20 Aktionen; eine gelungene FF-Probe halbiert.', quelle: 'WdS S. 55' },
    { gruppe: 'Längerfristig', id: 'talent', name: 'Talent einsetzen', kosten: 'nach Meister', text: 'Dauer in Aktionen festlegen; TaP* verkürzen.', quelle: 'WdS S. 55' },
    ...(h.mirakel ? [{ gruppe: 'Karmal', id: 'mirakel', name: 'Mirakel', kosten: '1 Aktion · 5 KaP', text: 'Bonus auf eine Probe: Eigenschaft +LkP*/2+2, Talent +LkP*/2+5.', quelle: 'LL S. 9' }] : []),
    { gruppe: 'Freie Aktionen', id: 'frei:Rufen', name: 'Rufen', kosten: 'Freie Aktion', text: 'Warnruf, Befehl, Fluch – höchstens drei Worte.', quelle: 'WdS S. 55' },
    { gruppe: 'Freie Aktionen', id: 'frei:Schritt', name: 'Schritt', kosten: 'Freie Aktion', text: 'Ein Schritt; unterbricht kein Zaubern.', quelle: 'WdS S. 55' },
    { gruppe: 'Freie Aktionen', id: 'frei:Drehen', name: 'Drehen', kosten: 'Freie Aktion', text: 'Drehung um 45°; unterbricht kein Zaubern.', quelle: 'WdS S. 55' },
    { gruppe: 'Freie Aktionen', id: 'frei:Artefakt aktivieren', name: 'Artefakt aktivieren', kosten: 'Freie Aktion', text: 'Am Körper getragenes oder gehaltenes Artefakt.', quelle: 'WdS S. 55' },
    { gruppe: 'Freie Aktionen', id: 'frei:Waffe fallen lassen', name: 'Waffe fallen lassen', kosten: 'Freie Aktion', text: 'Sie kann beschädigt oder unerreichbar werden.', quelle: 'WdS S. 55' },
    { gruppe: 'Freie Aktionen', id: 'boden', name: 'Sich zu Boden werfen', kosten: 'Freie Aktion', text: 'GE-Probe; misslingt sie: 1W6 INI. Danach liegend.', sperre: liegend ? 'Liegt bereits.' : null, quelle: 'WdS S. 55' },
  ];
}

function dialogAktionen() {
  const h = S.held;
  const g = S.gefecht;
  const { v } = aktuellerPlan();
  const { plan } = aktuellerPlan();
  const regulaer = plan.marken.some((m) => ['a1', 'a2'].includes(m.id) && !m.gesperrt && !g.verbraucht[m.id]);
  const frei = !pruefeAktionskosten('frei').grund;
  const katalog = aktionenKatalog(h, g, v).map((a) => {
    const brauchtFrei = a.kosten === 'Freie Aktion';
    const budget = brauchtFrei ? frei : regulaer;
    const lage = v.lage && !(v.lage.art === 'kampfunfaehig' && g.kfIgnoriert > 0);
    const sperre = a.sperre || (lage ? v.lage.text : null) || (g.patzer ? 'Patzer: Runde verloren.' : null);
    return { ...a, sperre: sperre || (!budget ? 'Keine passende Aktion mehr offen.' : null) };
  });
  const gruppen = [...new Set(katalog.map((a) => a.gruppe))];
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">Aktion wählen</h2>
      <p class="legende">Was eine Handlung kostet, steht rechts. Mehrere Aktionen laufen als längerfristige Handlung und dürfen nicht unterbrochen werden.</p>
      ${gruppen.map((gr) => `<div class="unterkopf"><span class="etikett">${gr}</span></div><div class="aktion-liste">${katalog.filter((a) => a.gruppe === gr).map((a) => `
        <button type="button" class="aktion-zeile" data-dlg="akt" data-akt="${esc(a.id)}" ${a.sperre ? 'disabled' : ''}>
          <span class="manoever-text"><b>${esc(a.name)}</b><small>${esc(a.sperre || a.text)} · ${esc(a.quelle)}</small></span>
          <span class="chip-marke">${esc(a.kosten)}</span></button>`).join('')}</div>`).join('')}
    </div>
    <div class="dlg-aktionen">${abbrechen('Schließen')}</div>`, {
    akt: (b) => { dlg.close(); fuehreAktionAus(b.dataset.akt); },
  });
}

function fuehreAktionAus(id) {
  const h = S.held;
  const g = S.gefecht;
  const { v } = aktuellerPlan();
  if (v.lage && !(v.lage.art === 'kampfunfaehig' && g.kfIgnoriert > 0)) { zeigeToast(`Nicht möglich: ${v.lage.text}`, 'alert'); return; }
  if (g.patzer) { zeigeToast('Patzer: Runde verloren.', 'alert'); return; }
  if (id.startsWith('frei:')) {
    const name = id.slice(5);
    const ausfuehren = () => {
      if (!verbrauche('frei', name)) { zeigeToast('Keine Freie Aktion mehr offen.', 'alert'); return; }
      protokolliere(`Freie Aktion: ${name}`);
      zeigeToast(`${name} (Freie Aktion).`, 'free');
      render();
    };
    // Schritt und Drehen unterbrechen kein Zaubern (WdS S. 55).
    if (name === 'Schritt' || name === 'Drehen') ausfuehren(); else mitUnterbrechung(name, ausfuehren);
    return;
  }
  if (id === 'boden') {
    mitUnterbrechung('Sich zu Boden werfen', () => {
      if (!verbrauche('frei', 'Zu Boden')) { zeigeToast('Keine Freie Aktion mehr offen.', 'alert'); return; }
      const r = w20('GE-Probe', h.eigenschaften.GE - v.be, 'ge');
      let folge = 'liegt jetzt';
      if (!r.gelungen) { const n = wuerfel(6); g.iniVerlust += n; folge += `, GE-Probe misslungen: INI −${n}`; }
      g.haltung = 'liegend';
      protokolliere('Sich zu Boden werfen', r.gelungen ? 'gelungen' : 'misslungen', folge);
      zeigeToast(`Zu Boden geworfen – ${folge}.`, 'alert');
      render();
    });
    return;
  }
  if (id === 'position') { aktionPosition(); return; }
  if (id === 'bewegen') {
    mitUnterbrechung('Bewegen', () => {
      if (!verbraucheAktion('Bewegen', false)) { zeigeToast('Keine Aktion mehr offen.', 'alert'); return; }
      g.bewegt = true;
      protokolliere('Bewegen', '', 'Kampfaktionen diese Runde +4');
      zeigeToast('Bewegt: Kampfaktionen in dieser Runde +4 (WdS S. 55).', 'next');
      render();
    });
    return;
  }
  const starte = (daten) => mitUnterbrechung(daten.name, () => starteHandlung(daten));
  if (id === 'orientieren') { starte({ typ: 'orientieren', name: 'Orientieren', gesamt: h.aufmerksamkeit ? 1 : 2, sym: 'compass' }); return; }
  if (id === 'laden') {
    const w = v.waffe;
    starte({ typ: 'laden', name: `Nachladen: ${w.name}`, kurz: 'Laden', waffe: w.id, gesamt: Math.max(1, w.ladezeit - (g.ladung[w.id] || 0)), sym: 'bow' });
    return;
  }
  if (id.startsWith('ziehen:')) {
    const w = h.waffen.find((x) => x.id === id.slice(7));
    const z = ZIEHEN[w.scheide];
    const n = h.schnellziehen ? z.schnell : z.normal;
    if (n === 0) {
      if (!verbrauche('frei', `Ziehen: ${w.name}`)) { zeigeToast('Keine Freie Aktion mehr offen.', 'alert'); return; }
      h.aktiveWaffe = w.id;
      zeigeToast(`${w.name} gezogen (Schnellziehen, Freie Aktion).`, 'swap');
      render();
      return;
    }
    starte({ typ: 'ziehen', name: `Waffe ziehen: ${w.name}`, kurz: 'Ziehen', waffe: w.id, gesamt: n, sym: 'swap' });
    return;
  }
  if (id === 'sprinten') {
    mitUnterbrechung('Sprinten', () => { if (starteHandlung({ typ: 'sprinten', name: 'Sprinten', gesamt: 2, sym: 'next' })) { g.sprint = true; render(); } });
    return;
  }
  if (id === 'gegenstand' || id === 'talent') {
    const titel = id === 'gegenstand' ? 'Gegenstand benutzen' : 'Talent einsetzen';
    oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">${titel}</h2>
        <div class="formzeile"><label for="hd-name">Was?</label><input class="eingabe breit" id="hd-name" value="${id === 'gegenstand' ? 'Heiltrank aus der Gürteltasche' : 'Klettern'}"></div>
        <div class="formzeile"><label for="hd-n">Aktionen</label><input class="eingabe" id="hd-n" type="number" min="1" value="${id === 'gegenstand' ? 10 : 4}"></div>
        <p class="legende">${id === 'gegenstand' ? 'Gürteltasche 10, Rucksack 20 Aktionen; gelungene FF-Probe halbiert (WdS S. 55).' : 'Dauer nach Meister, verkürzt um TaP* (WdS S. 55).'}</p></div>
      <div class="dlg-aktionen">${abbrechen()}<button type="button" class="btn btn-primaer" data-dlg="los">Beginnen</button></div>`, {
      los: () => {
        const name = $('#hd-name').value.trim() || titel;
        const n = Math.max(1, Number($('#hd-n').value) || 1);
        dlg.close();
        starte({ typ: id, name, gesamt: n, sym: id === 'gegenstand' ? 'flag' : 'book' });
      },
    });
    return;
  }
  if (id === 'mirakel') dialogMirakel();
}

// Position: aufstehen oder nach dem Ausweichen dem Gegner zuwenden (WdS S. 55, 58; HR S. 2 f.).
function aktionPosition() {
  const h = S.held;
  const g = S.gefecht;
  const { v } = aktuellerPlan();
  const ausfuehren = (direktStehen) => mitUnterbrechung('Position', () => {
    if (!verbraucheAktion('Position', false)) { zeigeToast('Keine Aktion mehr offen.', 'alert'); return; }
    if (g.desorientiert) {
      g.desorientiert = false;
      protokolliere('Position', '', 'dem Gegner wieder zugewandt');
      // Hausregel: Position und Orientieren nach freiem Ausweichen in einer Aktion.
      orientierenProbe(true);
    } else if (g.haltung === 'liegend' && direktStehen) {
      const r = w20('GE-Probe', h.eigenschaften.GE - v.be, 'ge');
      if (r.gelungen) g.haltung = 'stehend';
      protokolliere('Position: aufstehen', r.gelungen ? 'gelungen' : 'misslungen', `GE-Probe +BE: W20 ${r.wurf} gegen ${h.eigenschaften.GE - v.be}`);
      zeigeToast(r.gelungen ? 'Steht wieder.' : 'GE-Probe misslungen – liegt noch.', r.gelungen ? 'check' : 'alert');
    } else if (g.haltung !== 'stehend') {
      g.haltung = g.haltung === 'liegend' ? 'kniend' : 'stehend';
      protokolliere('Position', '', `jetzt ${g.haltung}`);
      zeigeToast(`Position: jetzt ${g.haltung}.`, 'check');
    } else {
      protokolliere('Position');
      zeigeToast('Position eingenommen.', 'check');
    }
    render();
  });
  if (g.haltung === 'liegend' && !g.desorientiert) {
    oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">Aufstehen</h2>
        <p>Von liegend zu kniend kostet eine Aktion Position. Wer in einer Aktion ganz aufstehen will, braucht eine GE-Probe +BE (WdS S. 58).</p></div>
      <div class="dlg-aktionen">${abbrechen()}<button type="button" class="btn btn-sekundaer" data-dlg="knien">Auf die Knie</button><button type="button" class="btn btn-primaer" data-dlg="stehen">Ganz aufstehen (GE ${h.eigenschaften.GE - v.be})</button></div>`, {
      knien: () => { dlg.close(); ausfuehren(false); },
      stehen: () => { dlg.close(); ausfuehren(true); },
    });
    return;
  }
  ausfuehren(false);
}

// Orientieren: INI wie mit einer 6 gewürfelt, Verluste aus Kampfaktionen weg (WdS S. 56, 209).
function orientierenProbe(ausHausregel) {
  const h = S.held;
  const g = S.gefecht;
  let gelungen = true;
  let text = 'Aufmerksamkeit: ohne Probe';
  if (!h.aufmerksamkeit) {
    const ziel = h.eigenschaften.IN + Math.floor(h.kriegskunst / 2);
    const r = w20('IN-Probe', ziel, 'in');
    gelungen = r.gelungen;
    text = `IN-Probe W20 ${r.wurf} gegen ${ziel}`;
  }
  if (gelungen) {
    const vorher = berechne(h, g).iniAktuell;
    g.iniVerlust = 0;
    g.iniWurf = h.iniSeiten === 12 ? 12 : 6;
    const nachher = berechne(h, g).iniAktuell;
    protokolliere(ausHausregel ? 'Orientieren (mit Position, Hausregel)' : 'Orientieren', 'gelungen', `${text} · INI ${minus(vorher)} → ${minus(nachher)}`);
    zeigeToast(`Orientiert: INI ${minus(vorher)} → ${minus(nachher)}.`, 'compass');
  } else {
    protokolliere('Orientieren', 'misslungen', text);
    zeigeToast('Orientieren misslungen – INI bleibt.', 'alert');
  }
  render();
}

// ---------------------------------------------------------------- Lage: kampfunfähig, Lebensgefahr
function pruefeLage(vorherLe) {
  const h = S.held;
  const g = S.gefecht;
  if (!g) return;
  const le = h.ressourcen.lep.wert;
  if (le <= 0 && vorherLe > 0 && g.todesfrist === null) {
    const w = wuerfel(6);
    g.todesfrist = w * h.eigenschaften.KO * (h.zaeherHund ? 1.5 : 1);
    protokolliere('Lebensgefahr', `${g.todesfrist} KR`, `W6 ${w} × KO ${h.eigenschaften.KO}`);
  }
  if (le > 0) g.todesfrist = null;
}

function dialogKampfunfaehigIgnorieren() {
  const h = S.held;
  const g = S.gefecht;
  if (g.kfIgnoriertGenutzt) { zeigeToast('Nur einmal pro Kampf möglich (WdS S. 84).', 'alert'); return; }
  const r = talentProbe('Selbstbeherrschung', h.selbstbeherrschung, ['MU', 'KO', 'KK'], 12);
  g.kfIgnoriertGenutzt = true;
  const erschoepfung = wuerfel(6);
  if (r.gelungen) g.kfIgnoriert = Math.max(1, r.punkte);
  protokolliere('Kampfunfähigkeit ignorieren', r.gelungen ? `${g.kfIgnoriert} KR` : 'misslungen', `Selbstbeherrschung +12: 3W20 ${r.w.join('/')} · Erschöpfung +${erschoepfung}`);
  zeigeToast(r.gelungen ? `Handlungsfähig für ${g.kfIgnoriert} KR (+${erschoepfung} Erschöpfung).` : `Selbstbeherrschung +12 misslungen (+${erschoepfung} Erschöpfung).`, r.gelungen ? 'check' : 'alert');
  render();
}

// ---------------------------------------------------------------- Rundenwechsel, Beginn
function naechsteRunde() {
  const g = S.gefecht;
  const h = S.held;
  const abgelaufen = [];
  h.effekte.forEach((e) => {
    if (e.einheit === 'KR' && e.rest > 0) {
      e.rest -= 1;
      if (e.rest === 0) abgelaufen.push(e.name);
    }
  });
  g.kr += 1;
  Object.assign(g, { verbraucht: {}, lang: {}, umwandeln: 'keine', zweiSchildparaden: false, bewegt: false, sprint: false, patzer: false, nachLangfristig: false, iniBoniFixiert: false });
  if (g.kfIgnoriert > 0) g.kfIgnoriert -= 1;
  if (g.todesfrist !== null) g.todesfrist = Math.max(0, g.todesfrist - 1);
  g.iniRundenbeginn = berechne(h, g).iniAktuell;
  S.rundeAnimiert = true;
  const details = [];
  if (abgelaufen.length) details.push(`abgelaufen: ${abgelaufen.join(', ')}`);
  if (g.handlung) details.push(`${g.handlung.name} läuft weiter`);
  protokolliere(`Kampfrunde ${g.kr} beginnt`, '', details.join(' · '));
  zeigeToast(`Kampfrunde ${g.kr}${details.length ? ` · ${details.join(' · ')}` : ''}`, 'hourglass');
  render();
}

function beginneGefecht(iniWurf) {
  S.gefecht = {
    kr: 1, iniWurf, iniVerlust: 0, iniRundenbeginn: 0, iniBoniFixiert: false, umwandeln: 'keine', zweiSchildparaden: false,
    verbraucht: {}, lang: {}, ladung: {}, handlung: null, log: [],
    haltung: 'stehend', gegner: 1, distanzklasse: null, desorientiert: false, bewegt: false, sprint: false, patzer: false, nachLangfristig: false,
    naechsteErschwernis: 0, mirakel: null, kfIgnoriert: 0, kfIgnoriertGenutzt: false, todesfrist: null, fehlversuche: {},
  };
  S.gefecht.iniRundenbeginn = berechne(S.held, S.gefecht).iniAktuell;
  S.ansicht = 'gefecht';
  S.taktOffen = false;
  protokolliere('Gefecht beginnt', `INI ${S.gefecht.iniRundenbeginn}`, `Wurf ${iniWurf}`);
  app.scrollTop = 0;
  render();
}

// ---------------------------------------------------------------- Zauber, Rituale, Liturgien, Mirakel
const hatWirken = (h) => h.zauber.length > 0 || h.ritualKategorien.some((k) => k.rituale.length > 0) || h.karmalSf.length > 0 || h.mirakel;

function wirkenEintraege(h) {
  const liste = h.zauber.map((z) => ({ ...z, typ: 'zauber', gruppe: 'Zauber', wert: z.zfw, wertName: 'ZfW', energie: 'AsP', sym: 'star' }));
  h.ritualKategorien.forEach((k) => k.rituale.forEach((r) => liste.push({
    ...r, typ: k.liturgie ? 'liturgie' : 'ritual', gruppe: k.name, wert: k.wert, wertName: k.kenntnis, energie: k.energie, sym: k.energie === 'KaP' ? 'sun' : 'star',
  })));
  return liste;
}
const findeWirken = (h, typ, id) => wirkenEintraege(h).find((e) => e.typ === typ && e.id === id);

function wirkenTitel(h) {
  const teile = [];
  if (h.zauber.length) teile.push('Zauber');
  if (h.ritualKategorien.some((k) => !k.liturgie && k.rituale.length)) teile.push('Rituale');
  if (h.ritualKategorien.some((k) => k.liturgie && k.rituale.length)) teile.push('Liturgien');
  if (h.karmalSf.length || h.mirakel) teile.push('karmale Fähigkeiten');
  const satz = teile.length > 1 ? `${teile.slice(0, -1).join(', ')} und ${teile[teile.length - 1]}` : teile[0];
  return satz.charAt(0).toUpperCase() + satz.slice(1);
}

// Probenzuschlag einer Zauber-, Ritual- oder Liturgieprobe mit Begründung.
function wirkenZuschlag(h, g, v, e) {
  const ers = erschwernis(h, g, v, 'zauber');
  const teile = [...ers.teile];
  if (e.typ === 'liturgie') teile.push([`Grad ${['0', 'I', 'II', 'III', 'IV'][e.grad]}`, LITURGIEGRAD[e.grad].zuschlag]);
  const fehl = g.fehlversuche[`${e.typ}:${e.id}`] || 0;
  if (fehl) teile.push([`${fehl}. Wiederholung`, 3 * fehl]); // WdZ S. 15, LL S. 11: +3 je vorherigem Scheitern
  return { summe: summe(teile, (t) => t[1]), teile };
}

function zoneWirken(h, g) {
  const eintraege = wirkenEintraege(h).sort((a, b) => (a.aktionen ?? 999) - (b.aktionen ?? 999) || a.name.localeCompare(b.name, 'de'));
  const arkan = eintraege.some((e) => e.energie === 'AsP');
  const energien = [...new Set([...eintraege.map((e) => e.energie), ...(h.mirakel ? ['KaP'] : [])])];
  const energieChips = energien.map((en) => {
    const st = energieStand(h, en);
    return st ? `<span class="chip-marke">${en} ${st.wert} / ${st.max}</span>` : '';
  }).join('');
  const zeile = (e) => {
    const stand = energieStand(h, e.energie);
    const zuWenig = e.kostenWert && stand && stand.wert < e.kostenWert;
    const kurz = e.aktionen !== null && e.aktionen <= 2;
    const laeuft = g.handlung && g.handlung.eintrag && g.handlung.eintrag.typ === e.typ && g.handlung.eintrag.id === e.id;
    const wertText = e.typ === 'zauber' ? `ZfW ${e.wert}` : `${e.wertName.split(' ')[0]} ${e.wert}`;
    return `<button type="button" class="wirken-zeile" data-action="wirken" data-typ="${e.typ}" data-id="${e.id}" data-suche="${esc(e.name.toLowerCase())}" data-kurz="${kurz}">
      ${icon(e.sym, e.energie === 'KaP' ? 'karmal' : 'arkan')}
      <span class="manoever-text"><b>${esc(e.name)}</b><small>${e.probe ? e.probe.join('/') : 'ohne Probe'} · ${esc(wertText)}${e.grad !== undefined ? ` · Grad ${['0', 'I', 'II', 'III', 'IV'][e.grad]}` : ''} · ${esc(e.reichweite)}</small></span>
      <span class="wirken-meta"><span class="chip-marke">${esc(e.aktionen ? aktionenText(e.aktionen) : e.dauer)}</span>
        <span class="chip-marke ${zuWenig ? 'warn' : ''}" ${zuWenig ? `title="Nur ${stand.wert} ${e.energie} übrig"` : ''}>${esc(e.kostenWert ? `${e.kostenWert} ${e.energie}` : `${e.energie} nach Formel`)}</span>
        ${laeuft ? '<span class="chip-marke ok">läuft</span>' : ''}</span>
    </button>`;
  };
  const gruppen = [...new Set(eintraege.map((e) => e.gruppe))];
  const filter = eintraege.length > 5
    ? `<div class="wirken-filter"><input class="eingabe suche" type="search" data-input="wirken-suche" value="${esc(S.wirkenSuche)}" placeholder="Suchen …" aria-label="${esc(wirkenTitel(h))} durchsuchen">
      <button type="button" class="chip-filter" data-action="wirken-kurz" aria-pressed="${S.wirkenKurz}">Bis 2 Aktionen</button></div>`
    : '';
  return `<section class="zone ${arkan ? 'astral' : 'akzent'}" id="z-wirken" aria-labelledby="z-wirken-titel">
    ${zoneKopf(arkan ? 'star' : 'sun', `<span id="z-wirken-titel">${esc(wirkenTitel(h))}</span>`, energieChips)}
    ${filter}
    ${gruppen.map((gr) => {
      const kat = h.ritualKategorien.find((k) => k.name === gr);
      return `<div class="wirken-gruppe"><div class="unterkopf"><span class="etikett">${esc(gr)}</span><span class="etikett">${kat ? `${esc(kat.kenntnis)} ${kat.wert}` : 'kürzeste zuerst'}</span></div>
        ${eintraege.filter((e) => e.gruppe === gr).map(zeile).join('')}</div>`;
    }).join('')}
    <p class="legende wirken-leer" hidden>Kein Eintrag passt zu Suche oder Filter.</p>
    ${h.mirakel ? `<div class="unterkopf"><span class="etikett">Karmale Handlungen</span></div>
      <button type="button" class="wirken-zeile" data-action="mirakel">${icon('sun', 'karmal')}<span class="manoever-text"><b>Mirakel</b><small>Bonus auf eine Probe, auch auf Ausweichen · LL S. 9</small></span>
        <span class="wirken-meta"><span class="chip-marke">1 Aktion</span><span class="chip-marke">5 KaP</span></span></button>` : ''}
    ${h.karmalSf.length ? `<div class="unterkopf"><span class="etikett">Karmale Sonderfertigkeiten</span></div>
      <div class="sf-chips">${h.karmalSf.map((k) => `<button type="button" class="chip chip-knopf" data-action="karmal" data-id="${k.id}">${icon('sun')}${esc(k.name)}</button>`).join('')}</div>` : ''}
  </section>`;
}

function filterWirken() {
  const zone = app.querySelector('#z-wirken');
  if (!zone) return;
  const q = S.wirkenSuche.trim().toLowerCase();
  let sichtbar = 0;
  zone.querySelectorAll('.wirken-gruppe').forEach((gruppe) => {
    let n = 0;
    gruppe.querySelectorAll('.wirken-zeile').forEach((z) => {
      const passt = (!q || z.dataset.suche.includes(q)) && (!S.wirkenKurz || z.dataset.kurz === 'true');
      z.hidden = !passt;
      if (passt) n += 1;
    });
    gruppe.hidden = n === 0;
    sichtbar += n;
  });
  const leer = zone.querySelector('.wirken-leer');
  if (leer) leer.hidden = sichtbar > 0;
}

// Wirken beginnen: Die Probe fällt zu Beginn der Zauberdauer (LC S. 5, WdZ S. 15).
function beginneWirken(e) {
  const h = S.held;
  const g = S.gefecht;
  const { v } = aktuellerPlan();
  const sperre = wirkenSperre(e, h, g, v);
  if (sperre) { zeigeToast(sperre, 'alert'); return; }
  let ergebnis = null;
  let gesamt = e.aktionen;
  if (e.probe) {
    const zuschlag = wirkenZuschlag(h, g, v, e);
    const r = dreiW20(e.probe.map((a) => h.eigenschaften[a]), e.wert - zuschlag.summe);
    const stern = e.typ === 'zauber' ? 'ZfP*' : e.typ === 'liturgie' ? 'LkP*' : 'P*';
    ergebnis = { ...r, stern, zuschlag };
    const art = { zauber: 'Zauberprobe', liturgie: 'Liturgieprobe', ritual: 'Ritualprobe' }[e.typ];
    protokolliere(`${art}: ${e.name}`, r.gelungen ? 'gelungen' : 'misslungen', `3W20 ${r.w.join('/')} gegen ${r.werte.join('/')}${zuschlag.teile.length ? ` (${erschwernisText(zuschlag)})` : ''}${r.gelungen ? ` · ${stern} ${r.punkte}` : ''}`);
    if (!r.gelungen) {
      g.fehlversuche[`${e.typ}:${e.id}`] = (g.fehlversuche[`${e.typ}:${e.id}`] || 0) + 1;
      // Scheitern bemerkt der Zaubernde erst nach der halben Zauberdauer; mit Zauberkontrolle nach einer Aktion (WdZ S. 15).
      if (e.typ === 'zauber') gesamt = h.zauberkontrolle ? 1 : Math.max(1, Math.ceil(e.aktionen / 2));
    }
  }
  const typ = e.typ === 'liturgie' ? 'liturgie' : 'zauber';
  const ok = starteHandlung({ typ, name: e.name, gesamt, sym: e.sym, eintrag: { typ: e.typ, id: e.id }, ergebnis });
  if (ok && ergebnis) {
    zeigeToast(ergebnis.gelungen
      ? `${e.name}: ${ergebnis.stern} ${ergebnis.punkte} – wirkt nach der letzten Aktion.`
      : `${e.name} misslingt – bemerkt nach ${aktionenText(gesamt)}.`, e.sym);
  }
}

// Kosten am Ende: gelungen voll; misslungen Zauber die Hälfte (aufgerundet), Liturgie 1/5, mindestens 1 KaP.
function kostenDialog(e, erg) {
  const h = S.held;
  const stand = energieStand(h, e.energie);
  const gelungen = !erg || erg.gelungen;
  const voll = e.typ === 'liturgie' ? LITURGIEGRAD[e.grad].kap : e.kostenWert;
  let vorschlag = voll;
  let regel = '';
  if (!gelungen && voll !== null) {
    if (e.typ === 'liturgie') { vorschlag = Math.max(1, Math.round(voll / 5)); regel = 'Misslungen: 1/5 der Kosten, mindestens 1 KaP (LL S. 11).'; } else { vorschlag = Math.ceil(voll / 2); regel = 'Misslungen: die Hälfte der Kosten, aufgerundet (LC S. 5, WdZ S. 14).'; }
  } else if (!gelungen) {
    regel = e.typ === 'liturgie' ? 'Misslungen: 1/5 der geplanten KaP, mindestens 1 (LL S. 11).' : 'Misslungen: die Hälfte der geplanten AsP (LC S. 5).';
  }
  const effekt = e.effekt && erg && erg.gelungen && erg.punkte > 0 ? erg.punkte * e.effekt.faktor : 0;
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">${esc(e.name)}</h2>
      ${erg && erg.w ? `<div class="ergebnis ${gelungen ? '' : 'gefahr'}" id="k-ergebnis">3W20 ${erg.w.join(' · ')} gegen ${erg.werte.join(' · ')} → <b>${gelungen ? `gelungen, ${erg.stern} ${erg.punkte}` : 'misslungen'}</b>${erg.zuschlag && erg.zuschlag.teile.length ? `<br><span class="leise">${esc(erschwernisText(erg.zuschlag))}</span>` : ''}</div>`
    : erg && erg.abgebrochen ? '<p class="ergebnis gefahr" id="k-ergebnis">Unterbrochen – das Wirken ist misslungen.</p>' : '<p class="leise">Ohne Probe aktiviert.</p>'}
      <dl class="tabelle-kv"><dt>Kosten</dt><dd>${esc(e.kosten)}</dd><dt>${e.energie}</dt><dd>${stand.wert} von ${stand.max}</dd></dl>
      ${regel ? `<p class="legende">${esc(regel)}</p>` : ''}
      <div class="formzeile"><label for="k-wert">${e.energie} abziehen</label><input class="eingabe" id="k-wert" type="number" min="0" inputmode="numeric" value="${vorschlag ?? ''}" placeholder="Wert" autofocus></div>
      ${effekt ? `<button type="button" class="check" role="checkbox" aria-checked="true" data-dlg="effekt" id="k-effekt"><span class="kasten">${icon('check')}</span>Als aktiven Effekt eintragen: ${effekt} KR (${erg.stern} × ${e.effekt.faktor})</button>` : ''}
    </div>
    <div class="dlg-aktionen"><button type="button" class="btn btn-leise" data-dlg="ohne">Nichts abziehen</button><button type="button" class="btn btn-primaer" data-dlg="zahlen">${e.energie} abziehen</button></div>`, {
    effekt: (b) => b.setAttribute('aria-checked', String(b.getAttribute('aria-checked') !== 'true')),
    ohne: () => schliesseWirken(e, 0, effekt),
    zahlen: () => schliesseWirken(e, Math.max(0, Number($('#k-wert').value) || 0), effekt),
  });
}

function schliesseWirken(e, betrag, effektDauer) {
  const h = S.held;
  const stand = energieStand(h, e.energie);
  if (betrag) {
    stand.wert = Math.max(0, stand.wert - betrag);
    protokolliere(`${e.energie} für ${e.name}`, `−${betrag} ${e.energie}`);
  }
  const schalter = $('#k-effekt');
  if (effektDauer && schalter && schalter.getAttribute('aria-checked') === 'true') {
    const vorhanden = h.effekte.find((x) => x.id === e.effekt.id);
    if (vorhanden) Object.assign(vorhanden, { rest: effektDauer, gesamt: effektDauer });
    else h.effekte.push({ id: e.effekt.id, name: e.name, wirkung: e.effekt.wirkung, einheit: 'KR', rest: effektDauer, gesamt: effektDauer, aufrecht: e.effekt.aufrecht });
    protokolliere(`Effekt eingetragen: ${e.name}`, `${effektDauer} KR`);
  }
  dlg.close();
  zeigeToast(betrag ? `${e.name}: ${betrag} ${e.energie} abgezogen.` : `${e.name} abgeschlossen.`, e.sym);
  render();
}

function dialogWirken(typ, id) {
  const h = S.held;
  const g = S.gefecht;
  const { v } = aktuellerPlan();
  const e = findeWirken(h, typ, id);
  const stand = energieStand(h, e.energie);
  const imKampf = e.aktionen !== null && e.aktionen <= 40;
  let zeit = 'Dauert länger, als ein Kampf üblicherweise währt – im Gefecht nur zum Nachschlagen.';
  if (e.aktionen === 1) zeit = 'Eine Aktion – anstelle der Angriffsaktion.';
  else if (e.aktionen === 2) zeit = 'Zwei Aktionen – die Angriffsaktion und eine zweite 8 INI-Phasen später (WdS S. 53).';
  else if (e.aktionen) zeit = `${aktionenText(e.aktionen)} – mindestens ${Math.ceil(e.aktionen / 2)} Kampfrunden, höchstens zwei Aktionen je Runde, ohne Unterbrechung (WdS S. 55).`;
  let wirkung;
  if (e.typ === 'zauber') {
    wirkung = S.katalogOffen
      ? '<p>(Beispiel) Hier steht nach dem Entsperren die Wirkung aus dem Zauberkatalog, mit eigenen Textanpassungen des Helden, wo vorhanden. Varianten folgen darunter.</p>'
      : `<p class="hinweis-zeile">${icon('info')}<span>Wirkung und Varianten sind geschützter Katalogtext und erscheinen nach dem Entsperren.</span></p>
        <button type="button" class="btn btn-leise btn-klein" data-dlg="entsperren">Katalog entsperren (Beispiel)</button>`;
  } else {
    wirkung = `<p>${esc(e.wirkung || 'Kein Wirkungstext eingetragen.')}</p>`;
  }
  const zuschlag = e.probe ? wirkenZuschlag(h, g, v, e) : { summe: 0, teile: [] };
  const laeuft = Boolean(g.handlung);
  const merkmale = (e.merkmale || '').split(',').map((m) => m.trim()).filter(Boolean);
  const dauerName = e.typ === 'liturgie' ? 'Liturgiedauer' : e.typ === 'zauber' ? 'Zauberdauer' : 'Ritualdauer';
  const gesperrt = wirkenSperre(e, h, g, v);
  oeffneDialog(`<div class="dlg-inhalt">
      <h2 id="dlg-titel">${esc(e.name)}</h2>
      <div class="aktionen-zeile"><span class="chip-marke">${esc(e.gruppe)}</span>${e.grad !== undefined ? `<span class="chip-marke">Grad ${['0', 'I', 'II', 'III', 'IV'][e.grad]}</span>` : ''}${merkmale.map((m) => `<span class="chip-marke">${esc(m)}</span>`).join('')}</div>
      <dl class="tabelle-kv">
        <dt>Probe</dt><dd>${e.probe ? e.probe.map((a) => `${a} ${h.eigenschaften[a]}`).join(' · ') : 'keine Probe hinterlegt'}${zuschlag.teile.length ? `<br><span class="leise">${esc(erschwernisText(zuschlag))}</span>` : ''}</dd>
        <dt>${e.typ === 'zauber' ? 'Zauberfertigkeit' : esc(e.wertName)}</dt><dd>${e.wert}</dd>
        <dt>${dauerName}</dt><dd>${esc(e.dauer)}<br><span class="leise">${zeit}</span></dd>
        <dt>Kosten</dt><dd>${esc(e.kosten)}<br><span class="leise">${e.energie} ${stand ? `${stand.wert} von ${stand.max}` : 'nicht aktiviert'}</span></dd>
        <dt>Reichweite</dt><dd>${esc(e.reichweite)}</dd>
        <dt>Wirkungsdauer</dt><dd>${esc(e.wirkungsdauer)}</dd>
        ${e.ziel ? `<dt>Zielobjekt</dt><dd>${esc(e.ziel)}</dd>` : ''}
        ${e.modifikationen ? `<dt>Modifikationen</dt><dd>${esc(e.modifikationen)}</dd>` : ''}
      </dl>
      <div class="unterkopf"><span class="etikett">Wirkung</span></div>${wirkung}
      <p class="legende">Die Probe fällt zu Beginn${e.typ === 'liturgie' ? ' (angenommen wie bei Zaubern)' : ' (LC S. 5)'}. Treffer während des Wirkens verlangen eine Selbstbeherrschungs-Probe +SP${e.typ === 'zauber' ? ' (WdZ S. 15)' : ' (WdG S. 251)'}.</p>
      ${laeuft ? `<p class="obergrenze">${icon('alert')}<span>${esc(g.handlung.name)} läuft noch – erst abschließen oder abbrechen.</span></p>` : ''}
      ${gesperrt ? `<p class="obergrenze">${icon('alert')}<span>${esc(gesperrt)}</span></p>` : ''}
    </div>
    <div class="dlg-aktionen">${abbrechen('Schließen')}
      ${imKampf ? `<button type="button" class="btn btn-primaer" data-dlg="start" ${laeuft || gesperrt ? 'disabled' : ''}>${icon(e.sym)}${e.probe ? `Wirken (Probe, ${aktionenText(e.aktionen)})` : `Aktivieren (${aktionenText(e.aktionen)})`}</button>` : ''}
    </div>`, {
    entsperren: () => { S.katalogOffen = true; dialogWirken(typ, id); },
    start: () => { dlg.close(); mitUnterbrechung(e.name, () => beginneWirken(e)); },
  });
}

function dialogKarmal(id) {
  const k = S.held.karmalSf.find((x) => x.id === id);
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">${esc(k.name)}</h2>
      <div class="aktionen-zeile"><span class="chip-marke">${esc(k.gruppe)}</span><span class="chip-marke">Karmale Sonderfertigkeit</span></div>
      <p>${esc(k.text)}</p>
      <p class="legende">Beschreibung aus dem Katalog der karmalen Sonderfertigkeiten.</p></div>
    <div class="dlg-aktionen">${abbrechen('Schließen')}</div>`);
}

// Mirakel: 1 Aktion, 5 KaP; Liturgiekenntnis-Probe nach Gunst; misslungen 1 KaP (LL S. 9).
function dialogMirakel() {
  const h = S.held;
  const g = S.gefecht;
  let ziel = 'aw';
  let gunst = 0;
  const aktualisiere = () => {
    dlg.querySelectorAll('[data-dlg^="z-"]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.dlg === `z-${ziel}`)));
    dlg.querySelectorAll('[data-dlg^="g-"]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.dlg === `g-${gunst}`)));
    $('#mir-text').textContent = `Liturgiekenntnis ${h.liturgiekenntnis}${gunst ? ` −${gunst}` : ''} · Bonus bei Gelingen: LkP*/2 + ${ziel === 'talent' ? 5 : 2}${ziel === 'aw' ? ' (Annahme: wie Eigenschaft)' : ''}`;
  };
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">Mirakel</h2>
      <p>Die Geweihte ruft ihre Gottheit kurz um Beistand an: 1 Aktion, 5 KaP für einen Bonus auf eine einzelne Probe.</p>
      <div class="formzeile"><span class="etikett">Wofür</span><div class="seg" role="group" aria-label="Ziel des Mirakels"><button type="button" data-dlg="z-aw">Ausweichen</button><button type="button" data-dlg="z-eigenschaft">Eigenschaft</button><button type="button" data-dlg="z-talent">Talent</button></div></div>
      <div class="formzeile"><span class="etikett">Der Gottheit</span><div class="seg" role="group" aria-label="Gunst"><button type="button" data-dlg="g-0">gefällig ±0</button><button type="button" data-dlg="g-6">ungelistet +6</button><button type="button" data-dlg="g-18">zuwider +18</button></div></div>
      <p class="ergebnis" id="mir-text"></p>
      <p class="legende">LL S. 9: Eigenschaft oder MR +LkP*/2+2, Talent oder Gabe +LkP*/2+5. Misslingt die Probe, kostet sie 1 KaP.</p></div>
    <div class="dlg-aktionen">${abbrechen()}<button type="button" class="btn btn-primaer" data-dlg="los">${icon('sun')}Mirakel wirken</button></div>`, {
    'z-aw': () => { ziel = 'aw'; aktualisiere(); },
    'z-eigenschaft': () => { ziel = 'eigenschaft'; aktualisiere(); },
    'z-talent': () => { ziel = 'talent'; aktualisiere(); },
    'g-0': () => { gunst = 0; aktualisiere(); },
    'g-6': () => { gunst = 6; aktualisiere(); },
    'g-18': () => { gunst = 18; aktualisiere(); },
    los: () => {
      dlg.close();
      mitUnterbrechung('Mirakel', () => {
        if (!verbraucheAktion('Mirakel', true)) { zeigeToast('Keine Aktion mehr offen.', 'alert'); return; }
        merkeLangfristig();
        const r = talentProbe('Liturgiekenntnis', h.liturgiekenntnis, ['MU', 'IN', 'CH'], gunst);
        const kap = h.ressourcen.kap;
        if (r.gelungen) {
          const bonus = Math.floor(r.punkte / 2) + (ziel === 'talent' ? 5 : 2);
          kap.wert = Math.max(0, kap.wert - 5);
          g.mirakel = { ziel, bonus };
          protokolliere('Mirakel', 'gelungen', `LkP* ${r.punkte} · +${bonus} auf ${ziel === 'aw' ? 'das nächste Ausweichen' : `die nächste ${ziel === 'talent' ? 'Talent' : 'Eigenschafts'}probe`} · −5 KaP`);
          zeigeToast(`Mirakel: +${bonus} auf ${ziel === 'aw' ? 'das nächste Ausweichen' : 'die nächste Probe'} (−5 KaP).`, 'sun');
        } else {
          kap.wert = Math.max(0, kap.wert - 1);
          protokolliere('Mirakel', 'misslungen', `3W20 ${r.w.join('/')} · −1 KaP`);
          zeigeToast('Mirakel misslungen (−1 KaP).', 'alert');
        }
        render();
      });
    },
  });
  aktualisiere();
}

// ---------------------------------------------------------------- Bausteine
const kompass = '<svg viewBox="0 0 44 44" aria-hidden="true"><circle cx="22" cy="22" r="20"/><circle cx="22" cy="22" r="16.5" stroke-dasharray="1 3"/><path d="M22 0v5M22 39v5M0 22h5M39 22h5"/></svg>';
const heldenmarke = (h) => `<span class="marke-held" aria-hidden="true">${kompass}${esc(h.monogramm)}</span>`;

function ressourcenHtml(h) {
  return `<div class="ressourcen">${RESSOURCEN.filter((r) => h.ressourcen[r.key]).map((r) => {
    const { wert, max } = h.ressourcen[r.key];
    const anteil = max > 0 ? Math.min(1, Math.max(0, wert / max)) : 0;
    let hinweis = 'Voll';
    let klasse = '';
    if (wert < max) hinweis = `${max - wert} ${r.kurz} fehlen`;
    if (wert > max) hinweis = `${wert - max} über Maximum`;
    if (r.key === 'lep' && wert <= 5) { hinweis = wert <= 0 ? 'Lebensgefahr' : 'kampfunfähig'; klasse = 'gefahr'; }
    return `<button type="button" class="ressource" data-action="ressource" data-key="${r.key}" aria-label="${r.name} ${wert} von ${max}, ändern">
      <span class="ressource-kopf frb-${r.farbe}">${icon(r.icon)}<span class="etikett">${r.name}</span>${icon('gear', 'tune')}</span>
      <span class="wert-gross">${minus(wert)}<span class="bezug"> / ${max}</span></span>
      <span class="balken"><i class="frb-${r.farbe}-bg" style="width:${Math.round(anteil * 100)}%"></i></span>
      <span class="hinweis ${klasse}">${hinweis}</span>
    </button>`;
  }).join('')}</div>`;
}

function wertfeld({ etikett, wert, zusatz = '', wurfArt, wurfText, gedimmt = false, deaktiviert = false, ziel = null, grund = '' }) {
  return `<div class="wertfeld ${gedimmt ? 'gedimmt' : ''}">
    <span class="etikett">${etikett}</span>
    <span class="wert-gross">${wert}${ziel !== null && ziel !== wert ? `<span class="bezug"> · Ziel ${minus(ziel)}</span>` : ''}</span>
    <span class="zusatz">${zusatz}</span>
    ${wurfArt ? `<button type="button" class="wurf" data-action="wurf" data-art="${wurfArt}" aria-label="${wurfText}${grund ? `: ${esc(grund)}` : ''}" ${deaktiviert ? 'disabled' : ''}>${icon('dice')}${wurfText}</button>` : ''}
    ${grund ? `<span class="aktions-grund gesperrt">${esc(grund)}</span>` : ''}
  </div>`;
}

const zoneKopf = (sym, titel, extra = '') => `<div class="zone-kopf">${icon(sym)}<h2 class="abschnitt">${titel}</h2>${extra}</div>`;

// ---------------------------------------------------------------- Zonen
function zoneDurchhalten(h, v) {
  const wundenText = v.wunden
    ? `${v.wunden} ${v.wunden === 1 ? 'Wunde' : 'Wunden'}: AT/PA/FK und INI je ${minus(-2)}, GS je ${minus(-1)}${h.kopfIni ? ` · Kopfwunde INI ${minus(-h.kopfIni)}` : ''}`
    : 'Keine Wunden.';
  const le = v.leStufe ? `<p class="hinweis-zeile">${icon('info')}<span>Niedrige LE (Optionalregel WdS S. 58): Kampfwürfe +${v.leStufe}, Talent- und Zauberproben +${3 * v.leStufe}.</span></p>` : '';
  return `<section class="zone" aria-labelledby="z-durch">
    <div class="zone-kopf">${icon('heart')}<h2 class="abschnitt" id="z-durch">Durchhalten</h2>
      <button type="button" class="btn btn-sekundaer btn-klein" data-action="schaden">Schaden erhalten</button></div>
    ${ressourcenHtml(h)}
    ${le}
    <div class="unterkopf"><span class="etikett">Wunden</span><span class="etikett">Wundschwellen ${h.wundschwellen.join(' · ')}</span></div>
    <div class="wund-raster">${ZONEN.map((z) => {
      const n = h.wunden[z] || 0;
      return `<div class="wund-zone"><span>${z}</span><span class="wund-pips" aria-label="${n} von 3 Wunden">${[0, 1, 2].map((i) => `<i class="${i < n ? 'voll' : ''}"></i>`).join('')}</span></div>`;
    }).join('')}</div>
    <p class="hinweis-zeile" style="margin-top:10px">${icon('info')}<span>${wundenText}</span></p>
  </section>`;
}

function zoneEffekte(h) {
  const liste = h.effekte.length
    ? h.effekte.map((e) => {
      const ab = e.rest <= 0;
      const dauer = ab ? 'abgelaufen' : `noch ${e.rest} von ${e.gesamt} ${e.einheit}`;
      const zusatz = e.einheit === 'KR' ? '' : '<small>zählt nicht mit Kampfrunden</small>';
      return `<div class="effekt">${icon('star')}<div class="zeile-text"><b>${esc(e.name)}</b><small>${esc(e.wirkung)}</small>${zusatz}${e.aufrecht && !ab ? '<small>aufrechterhalten (A): Kampfwürfe +1, Zauberproben +3 (WdZ S. 15)</small>' : ''}</div>
        <span class="chip-marke ${ab ? 'warn' : ''}">${dauer}</span></div>`;
    }).join('')
    : '<p class="legende">Keine aktiven Effekte.</p>';
  return `<section class="zone astral" aria-labelledby="z-eff">
    ${zoneKopf('star', '<span id="z-eff">Aktive Effekte</span>', '<button type="button" class="btn btn-leise btn-klein" data-action="hinweis" data-text="Öffnet in der App „Effekte verwalten“.">Verwalten</button>')}
    ${liste}
  </section>`;
}

function zoneAngriff(h, g, v) {
  const w = v.waffe;
  let kern;
  if (v.nah) {
    const ers = erschwernis(h, g, v, 'at');
    const option = kampfOption('at', h, g, v);
    const zusatz = [`AT ${v.at}`, erschwernisText(ers), option.zuschlag ? `Umwandeln +${option.zuschlag}` : ''].filter(Boolean).join(' · ');
    kern = `<div class="werte">
      ${wertfeld({ etikett: 'Attacke (Zielwert)', wert: option.ziel, zusatz, wurfArt: 'at', wurfText: 'Angreifen', deaktiviert: Boolean(option.grund), grund: option.grund })}
      ${wertfeld({ etikett: 'Trefferpunkte', wert: v.tpText, zusatz: 'TP/KK eingerechnet', wurfArt: 'tp', wurfText: 'Schaden würfeln' })}
    </div>`;
  } else {
    const geladen = g.ladung[w.id] || 0;
    const gs = v.geschossDaten;
    const ers = erschwernis(h, g, v, 'fk');
    const option = kampfOption('fk', h, g, v);
    kern = `<div class="werte">
      ${wertfeld({ etikett: 'Schuss (Zielwert)', wert: option.ziel, zusatz: `FK ${v.fk} · ${v.entfernung.name}: ${vz(v.entfernung.fk)}${ers.teile.length ? ` · ${erschwernisText(ers)}` : ''}`, wurfArt: 'fk', wurfText: 'Schießen', deaktiviert: Boolean(option.grund), grund: option.grund })}
      ${wertfeld({ etikett: 'Trefferpunkte', wert: v.tpText, zusatz: v.tpMod ? `Entfernung/Geschoss ${vz(v.tpMod)}` : 'ohne Zuschlag', wurfArt: 'tp', wurfText: 'Schaden würfeln' })}
    </div>
    <div class="feld-reihe"><span class="etikett">Entfernung</span>
      <div class="seg" role="group" aria-label="Entfernung">${w.entfernungen.map((e, i) => `<button type="button" data-action="entfernung" data-i="${i}" aria-pressed="${i === w.entfernung}">${e.name}</button>`).join('')}</div></div>
    <div class="feld-reihe"><span class="etikett">Geschoss</span>
      <select class="select" data-change="geschoss" aria-label="Geschoss">${w.geschosse.map((x, i) => `<option value="${i}" ${i === w.geschoss ? 'selected' : ''}>${esc(x.name)}${x.tp ? ` (TP ${vz(x.tp)})` : ''}</option>`).join('')}</select>
      <span class="stepper mini-stepper" role="group" aria-label="Bestand ${esc(gs.name)}"><button type="button" data-action="geschoss-schritt" data-wert="-1" aria-label="Bestand verringern">−</button><span>${gs.anzahl}</span><button type="button" data-action="geschoss-schritt" data-wert="1" aria-label="Bestand erhöhen">+</button></span></div>
    <div class="ladung"><span class="etikett">Ladezeit ${aktionenText(w.ladezeit)}</span>
      <span class="ladung-punkte" aria-label="${geladen} von ${w.ladezeit} geladen">${Array.from({ length: w.ladezeit }, (_, i) => `<i class="${i < geladen ? 'voll' : ''}"></i>`).join('')}</span>
      <span class="wert">${geladen >= w.ladezeit ? 'geladen' : `${geladen} von ${w.ladezeit}`}</span>
      <button type="button" class="btn btn-sekundaer btn-klein" data-action="nachladen" ${geladen >= w.ladezeit ? 'disabled' : ''}>Nachladen</button></div>`;
  }
  const hinweise = [];
  if (v.axx && v.nah) hinweise.push('Abwehr des beschleunigten Nahkampfangriffs: Automatische Finte +2');
  if (h.nebenhand && !v.schildNutzbar) hinweise.push(`${h.nebenhand.name}: mit ${w.name} (${w.hand}) nicht nutzbar.`);
  return `<section class="zone akzent" aria-labelledby="z-angriff">
    ${zoneKopf(v.nah ? 'sword' : 'bow', '<span id="z-angriff">Angriff</span>', '<button type="button" class="btn btn-leise btn-klein" data-action="ausruestung" data-bereich="waffen">Waffe wechseln</button>')}
    <div class="waffe-name"><span class="titel" style="font-size:22px">${esc(w.name)}</span></div>
    <div class="waffe-meta">${esc(w.talent)}${w.dk ? ` · DK ${w.dk}` : ''} · ${w.hand} · INI ${vz(w.ini)}</div>
    ${kern}
    ${hinweise.length ? `<div class="hinweise">${hinweise.map((t) => `<p class="hinweis-zeile">${icon('info')}<span>${esc(t)}</span></p>`).join('')}</div>` : ''}

  </section>`;
}

function verbrauchSymbole(m) {
  if (m.verbrauch === 'alle') return `${icon('sword')}${icon('shield')}<span class="chip-marke">alle</span>`;
  if (m.verbrauch === 'angriff_und_abwehr') return `${icon('sword')}${icon('shield')}`;
  return icon(m.verbrauch === 'abwehr' ? 'shield' : 'sword');
}

function zoneKoennen(h, v, alsDetails) {
  const g = S.gefecht;
  const manoever = v.nah ? h.manoever : [];
  const chips = h.sf.filter((s) => !h.manoever.some((m) => m.name === s));
  const zeilen = manoever.map((m) => {
    const option = manoeverOption(m, h, g, v);
    const status = { bereit: 'bereit', pruefen: 'prüfen', gesperrt: 'gesperrt' }[option.status];
    const kurz = m.id === 'wucht' ? 'Mehr Schaden durch höhere Ansage.' : m.id === 'finte' ? 'Erschwert die gegnerische Parade.' : m.text;
    return `<button type="button" class="manoever ${option.status}" data-action="manoever" data-id="${m.id}" aria-label="${esc(m.name)}: ${status}. Details öffnen">
      <span class="manoever-text"><b>${esc(m.name)}</b><small>${esc(kurz)}</small><small class="aktions-grund">${esc(option.hinweis)}</small></span>
      <span class="manoever-meta"><span class="chip-marke ${option.status}">${status}</span><span class="verbrauch" title="${VERBRAUCH_TEXT[m.verbrauch]}">${verbrauchSymbole(m)}</span></span></button>`;
  }).join('');
  const sf = `<details class="sf-details"><summary>Sonderfertigkeiten (${chips.length})</summary><div class="sf-chips">${chips.map((s) => `<span class="chip">${esc(s)}</span>`).join('')}</div></details>`;
  const inhalt = `${zeilen || `<p class="legende">Für ${esc(v.waffe.name)} sind keine Manöver hinterlegt.</p>`}${sf}`;
  if (alsDetails) return `<details class="zone" open><summary>${zoneKopf('book', 'Manöver', icon('chevron', 'auf'))}</summary>${inhalt}</details>`;
  return `<section class="zone" aria-labelledby="z-koennen">${zoneKopf('book', '<span id="z-koennen">Manöver</span>', '<span class="etikett">Kosten und Folgen im Detail</span>')}${inhalt}</section>`;
}

function zoneVerteidigung(h, g, v) {
  const n = h.nebenhand;
  const felder = [];
  const bonus = v.abwehrBonus ? `hohe INI ${vz(v.abwehrBonus)}` : '';
  if (v.nah) {
    const ers = erschwernis(h, g, v, 'pa');
    const option = kampfOption('pa', h, g, v);
    const zusatz = [bonus, erschwernisText(ers), option.zuschlag ? `Umwandeln +${option.zuschlag}` : ''].filter(Boolean).join(', ');
    felder.push(wertfeld({ etikett: 'Parade (Zielwert)', wert: option.ziel, zusatz: zusatz || v.waffe.name, wurfArt: 'pa', wurfText: 'Parieren', deaktiviert: Boolean(option.grund), grund: option.grund }));
  } else {
    felder.push(wertfeld({ etikett: 'Parade', wert: '–', zusatz: `mit ${esc(v.waffe.name)} keine Parade`, gedimmt: true }));
  }
  if (n && n.art === 'schild') {
    const ers = erschwernis(h, g, v, 'schild');
    const option = v.schildNutzbar ? kampfOption('schild', h, g, v) : null;
    felder.push(v.schildNutzbar
      ? wertfeld({ etikett: 'Schildparade (Zielwert)', wert: option.ziel, zusatz: [bonus, erschwernisText(ers), option.zuschlag ? `Umwandeln +${option.zuschlag}` : ''].filter(Boolean).join(', ') || n.name, wurfArt: 'schild', wurfText: 'Mit Schild', deaktiviert: Boolean(option.grund), grund: option.grund })
      : wertfeld({ etikett: `Schildparade (${esc(n.name)})`, wert: '–', zusatz: 'gerade nicht nutzbar', gedimmt: true }));
  }
  const ersAw = erschwernis(h, g, v, 'aw');
  const awSperre = ausweichenMoeglich(h, g);
  const awOption = kampfOption('aw', h, g, v);
  felder.push(wertfeld({ etikett: 'Ausweichen (Basis)', wert: v.aw, zusatz: [h.ausweichenI ? 'frei oder gezielt' : 'nur frei', 'DK und Zielwert im Dialog', bonus, erschwernisText(ersAw)].filter(Boolean).join(', '), wurfArt: 'aw', wurfText: 'Ausweichen', deaktiviert: Boolean(awOption.grund), grund: awOption.grund }));
  const klingenwand = v.klingenwand
    ? `<p class="hinweis-zeile" style="margin-top:10px">${icon('info')}<span>Klingenwand: Parade in 2 × PA ${v.klingenwand} aufspalten. Ansage zu Rundenbeginn (WdS S. 70).</span></p>`
    : '';
  return `<section class="zone akzent" aria-labelledby="z-vert">
    ${zoneKopf('shield', '<span id="z-vert">Verteidigung</span>')}
    <div class="werte" style="margin-top:0">${felder.join('')}</div>
    ${klingenwand}
    <div class="unterkopf"><span class="etikett">Rüstung</span><button type="button" class="btn btn-leise btn-klein" data-action="ausruestung" data-bereich="ruestung">Teile wechseln</button></div>
    <div class="werte" style="margin-top:0">
      ${wertfeld({ etikett: 'Rüstungsschutz', wert: v.rs, zusatz: v.armatrutz ? `Armatrutz ${vz(v.armatrutz)}` : 'aus angelegten Teilen' })}
      ${wertfeld({ etikett: 'Behinderung', wert: v.be, zusatz: h.ruestungsgewoehnung ? `BE ${v.beRoh}, Rüstungsgewöhnung ${minus(-h.ruestungsgewoehnung)}` : 'BE gesamt' })}
    </div>

  </section>`;
}

function zoneProtokoll(g, offen) {
  const eintraege = g.log.length
    ? `<ul class="protokoll">${g.log.map((e) => `<li><span class="kr">KR ${e.kr}</span><span>${esc(e.text)}${e.detail ? ` <span class="stumm">· ${esc(e.detail)}</span>` : ''}</span>
      <span class="${e.ergebnis === 'gelungen' ? 'erg-ok' : e.ergebnis === 'misslungen' ? 'erg-nein' : 'leise'}">${esc(e.ergebnis)}</span></li>`).join('')}</ul>`
    : '<p class="legende">Noch keine Würfe in diesem Gefecht.</p>';
  return `<details class="zone" ${offen ? 'open' : ''}><summary>${zoneKopf('dice', 'Würfelprotokoll', `<span class="etikett">${g.log.length} ${g.log.length === 1 ? 'Eintrag' : 'Einträge'}</span>${icon('chevron', 'auf')}`)}</summary>${eintraege}</details>`;
}

// ---------------------------------------------------------------- Takt
function markeHtml(m, g) {
  const verbraucht = g.verbraucht[m.id];
  const sym = m.art === 'angriff' ? 'sword' : m.art === 'abwehr' ? 'shield' : 'free';
  const erschw = m.erschw === undefined ? '' : `<span class="mk-erschw ${m.erschw === 0 ? 'null' : ''}" title="${m.erschw === 0 ? esc(m.grund) : 'Umwandeln'}">${m.erschw === 0 ? '±0' : `+${m.erschw}`}</span>`;
  const sub = m.gesperrt ? (m.kurz || m.gesperrt) : verbraucht ? `✓ ${verbraucht}` : m.sub;
  const label = `${m.titel}${m.erschw ? `, Erschwernis ${m.erschw}` : ''}: ${m.gesperrt ? `nicht verfügbar, ${m.gesperrt}` : verbraucht ? 'verbraucht' : `offen, ${m.sub}`}`;
  return `<button type="button" class="mk ${m.art === 'frei' ? 'frei' : ''} ${m.gesperrt ? 'gesperrt' : ''}" data-action="marke" data-id="${m.id}"
    aria-pressed="${Boolean(verbraucht)}" aria-label="${esc(label)}" ${m.gesperrt ? `disabled title="${esc(m.gesperrt)}"` : ''}>
    ${icon(sym)}<span class="mk-titel"><span class="mk-punkt"></span>${m.titel}${erschw}</span><span class="mk-sub">${esc(sub)}</span></button>`;
}

function ansageHtml(h, g, v, plan) {
  const sperre = ansageGesperrt(h, g, plan);
  const um = plan.um;
  const opt = (wert, text, erschw, deaktiviert) => `<button type="button" data-action="umwandeln" data-wert="${wert}" aria-pressed="${g.umwandeln === wert}" ${deaktiviert ? 'disabled' : ''}>${text}${erschw === undefined ? '' : ` · ${erschw ? `+${erschw}` : '±0'}`}</button>`;
  const hinweise = [];
  if (um.gesperrt) hinweise.push(um.gesperrt);
  else {
    if (um.atPa.erschw === 0) hinweise.push(`Angriff → Abwehr ohne Zuschlag: ${um.atPa.grund}.`);
    if (um.paAt.erschw === 0) hinweise.push(`Abwehr → Angriff ohne Zuschlag: ${um.paAt.grund}.`);
    hinweise.push('Ein umgewandelter Angriff kommt bei INI − 8 (WdS S. 82).');
  }
  const schildMoeglich = v.schildNutzbar && h.nebenhand && h.nebenhand.schildkampfII;
  const paAtMitSchild = g.zweiSchildparaden && schildMoeglich;
  return `<div class="ansage">
    <span class="etikett">Ansage zu Rundenbeginn</span>
    <div class="seg" role="group" aria-label="Aktionen umwandeln">
      ${opt('keine', 'Nicht umwandeln', undefined, Boolean(sperre))}
      ${opt('at-pa', 'Angriff → Abwehr', um.gesperrt ? undefined : um.atPa.erschw, Boolean(sperre || um.gesperrt))}
      ${opt('pa-at', 'Abwehr → Angriff', um.gesperrt ? undefined : um.paAt.erschw, Boolean(sperre || um.gesperrt || paAtMitSchild))}
    </div>
    ${schildMoeglich ? `<button type="button" class="check" role="checkbox" aria-checked="${g.zweiSchildparaden}" data-action="zwei-schild" ${sperre || g.umwandeln === 'pa-at' ? 'disabled' : ''}>
      <span class="kasten">${icon('check')}</span>Zwei Schildparaden (Schildkampf II)</button>` : ''}
    <p class="ansage-hinweis ${sperre ? 'warn' : ''}">${esc(sperre || hinweise.join(' '))}</p>
  </div>`;
}

// Zustand des Kämpfers: Haltung, Gegnerzahl und alles, was gerade Würfe verändert.
function zustandHtml(h, g, v) {
  const chips = [];
  if (g.desorientiert) chips.push(`<span class="zustand-chip warn">${icon('alert')}Desorientiert – nur Ausweichen<button type="button" class="btn btn-leise btn-klein" data-action="position">Position${h.aufmerksamkeit ? '' : ' + Orientieren'}</button></span>`);
  if (g.patzer) chips.push(`<span class="zustand-chip gefahr">${icon('alert')}Patzer: Runde verloren</span>`);
  if (g.bewegt) chips.push(`<span class="zustand-chip">${icon('next')}Bewegt: Kampfaktionen +4</span>`);
  if (g.sprint) chips.push(`<span class="zustand-chip warn">${icon('next')}Sprintet: keine Kampfaktionen</span>`);
  if (g.naechsteErschwernis) chips.push(`<span class="zustand-chip warn">${icon('alert')}Ansage misslungen: nächste Aktion +${g.naechsteErschwernis}</span>`);
  if (g.nachLangfristig) chips.push(`<span class="zustand-chip">${icon('hourglass')}Kampfaktion als zweite Aktion +4</span>`);
  if (v.aufrecht) chips.push(`<span class="zustand-chip astral">${icon('star')}${v.aufrecht} aufrechterhalten: Kampf +${v.aufrecht}, Zauber +${3 * v.aufrecht}</span>`);
  if (g.mirakel) chips.push(`<span class="zustand-chip">${icon('sun')}Mirakel: +${g.mirakel.bonus} auf ${g.mirakel.ziel === 'aw' ? 'nächstes Ausweichen' : 'nächste Probe'}</span>`);
  if (g.kfIgnoriert > 0) chips.push(`<span class="zustand-chip warn">${icon('alert')}Kampfunfähigkeit ignoriert: noch ${g.kfIgnoriert} KR</span>`);
  return `<div class="zustand">
    <div class="zustand-steuer">
      <span class="etikett">Haltung</span>
      <div class="seg" role="group" aria-label="Haltung">${['stehend', 'kniend', 'liegend'].map((x) => `<button type="button" data-action="haltung" data-wert="${x}" aria-pressed="${g.haltung === x}">${x}</button>`).join('')}</div>
      <span class="etikett">Gegner</span>
      <div class="seg" role="group" aria-label="Zahl der Gegner">${[1, 2, 3, 4].map((x) => `<button type="button" data-action="gegner" data-wert="${x}" aria-pressed="${g.gegner === x}">${x === 4 ? '4+' : x}</button>`).join('')}</div>
      <button type="button" class="btn btn-sekundaer btn-klein" data-action="aktionen">${icon('flag')}Aktion wählen …</button>
    </div>
    ${chips.length ? `<div class="zustand-chips">${chips.join('')}</div>` : ''}
  </div>`;
}

function iniBlock(h, g, v) {
  return `<div class="ini-block">
    <span class="etikett">Initiative</span>
    <div class="ini-zeile"><span class="ini-wert">${minus(v.iniAktuell)}</span>${v.iniAktuell !== v.iniKampf ? `<span class="bezug">von ${v.iniKampf}</span>` : ''}</div>
    <div class="ini-auf"><span>ohne Wurf <b>${v.iniOhneWurf}</b></span><span>Wurf <b>${g.iniWurf}</b></span>
      ${g.iniVerlust ? `<span>Kampfaktionen <b>${minus(-g.iniVerlust)}</b></span>` : ''}${h.kopfIni ? `<span>Kopfwunde <b>${minus(-h.kopfIni)}</b></span>` : ''}</div>
    <div class="ini-steuer">
      <span class="stepper" role="group" aria-label="INI ändern"><button type="button" data-action="ini" data-wert="1" aria-label="INI um 1 senken">−</button><span>Verlust ${g.iniVerlust}</span><button type="button" data-action="ini" data-wert="-1" aria-label="INI um 1 erhöhen" ${g.iniVerlust <= 0 ? 'disabled' : ''}>+</button></span>
      <button type="button" class="btn btn-sekundaer btn-klein" data-action="aktion-direkt" data-akt="orientieren" ${g.haltung === 'liegend' || g.handlung ? 'disabled' : ''}>${icon('compass')}Orientieren</button>
    </div>
    <span class="etikett">Ab INI ${g.iniRundenbeginn} (Rundenbeginn): Abwehr ${vz(v.abwehrBonus)} · freie Aktionen ${vz(v.freiBonus)} (WdS S. 79)</span>
  </div>`;
}

function planBlock(h, g, v, plan, mitHandlung = true) {
  const offen = plan.marken.filter((m) => !m.gesperrt && !g.verbraucht[m.id]).length;
  return `<div class="plan-block">
    <div class="plan-kopf"><h2 class="abschnitt">Aktionen dieser Runde</h2><span class="etikett">${offen} von ${plan.marken.filter((m) => !m.gesperrt).length} offen · antippen zum Abhaken</span></div>
    <div class="marken">${plan.marken.map((m) => markeHtml(m, g)).join('')}</div>
    ${mitHandlung ? handlungHtml(g) : ''}
    ${plan.warnungen.map((w) => `<p class="obergrenze">${icon('alert')}<span>${esc(w)}</span></p>`).join('')}
    ${ansageHtml(h, g, v, plan)}
    ${zustandHtml(h, g, v)}
  </div>`;
}

function rundeBlock(g) {
  const anim = S.rundeAnimiert ? 'wechsel' : '';
  return `<div class="runde-block">
    <div><span class="etikett">Kampfrunde</span><div class="runde-zahl ${anim}" aria-live="polite">${g.kr}</div></div>
    <button type="button" class="btn btn-primaer" data-action="naechste-runde">Nächste Kampfrunde${icon('next')}</button>
  </div>`;
}

function handlungHtml(g, kompakt = false) {
  const hd = g.handlung;
  if (!hd) return '';
  const fertig = hd.stand >= hd.gesamt;
  const pips = !kompakt && hd.gesamt <= 12
    ? `<span class="ladung-punkte" aria-hidden="true">${Array.from({ length: hd.gesamt }, (_, i) => `<i class="${i < hd.stand ? 'voll' : ''}"></i>`).join('')}</span>` : '';
  const probe = hd.ergebnis ? (hd.ergebnis.gelungen ? ` · Probe gelungen (${hd.ergebnis.stern} ${hd.ergebnis.punkte})` : ' · Probe misslungen') : '';
  const stand = kompakt ? `${hd.stand}/${hd.gesamt} Aktionen` : `${hd.stand} von ${aktionenText(hd.gesamt)}${probe} · ohne Unterbrechung`;
  const weiter = fertig ? '' : `<button type="button" class="btn btn-sekundaer btn-klein" data-action="handlung-weiter">${kompakt ? `Weiter${icon('next')}` : 'Aktion fortsetzen'}</button>`;
  return `<div class="handlung ${kompakt ? 'kompakt' : ''} ${hd.sym === 'sun' ? 'karmal' : ''}" role="group" aria-label="Laufende Handlung: ${esc(hd.name)}">
    ${icon(hd.sym)}
    <div class="handlung-text"><b>${esc(hd.name)}</b><small>${stand}</small>${pips}</div>
    <div class="rechts">${weiter}
      <button type="button" class="btn btn-leise btn-klein ${kompakt ? 'btn-icon' : ''}" data-action="handlung-abbruch" aria-label="Abbrechen" title="Abbrechen">${kompakt ? icon('close') : 'Abbrechen'}</button>
    </div>
  </div>`;
}

function taktKompakt(h, g, v, plan) {
  const punkte = plan.marken.map((m) => {
    const sym = m.art === 'angriff' ? 'sword' : m.art === 'abwehr' ? 'shield' : 'free';
    return `<span class="punkt ${g.verbraucht[m.id] ? 'voll' : ''} ${m.gesperrt ? 'gesperrt' : ''}">${icon(sym)}</span>`;
  }).join('');
  const offen = plan.marken.filter((m) => !m.gesperrt && !g.verbraucht[m.id]).length;
  return `<div class="takt-kompakt">
    <div class="ini-mini"><span>INI</span><b>${minus(v.iniAktuell)}</b></div>
    <button type="button" class="punkte" data-action="takt-auf" aria-expanded="${S.taktOffen}" aria-controls="takt-plan" aria-label="Aktionsplan, ${offen} offen, ${S.taktOffen ? 'zuklappen' : 'aufklappen'}">${punkte}${icon('chevron', 'auf')}</button>
    <button type="button" class="btn btn-primaer btn-klein" data-action="naechste-runde" aria-label="Nächste Kampfrunde, derzeit Runde ${g.kr}">KR ${g.kr}${icon('next')}</button>
  </div>`;
}

// Der aufgeklappte Plan liegt im Seitenfluss, nicht im klebenden Kopf: sonst wäre der Kopf höher als der Bildschirm.
function taktAusgeklappt(h, g, v, plan) {
  return S.taktOffen ? `<section class="takt akzent takt-ausgeklappt" id="takt-plan" aria-label="Takt der Kampfrunde">${iniBlock(h, g, v)}<hr class="trenner">${planBlock(h, g, v, plan, false)}</section>` : '';
}

function wuerfelleiste(h, v) {
  const g = S.gefecht;
  const knopf = (art, text, wert) => {
    const option = kampfOption(art, h, g, v);
    return `<button type="button" data-action="wurf" data-art="${art}" ${option.grund ? 'disabled' : ''} aria-label="${text}${option.grund ? `: ${esc(option.grund)}` : ''}"><b>${option.ziel ?? wert}</b><span>${text}</span></button>`;
  };
  const arkan = h.zauber.length > 0 || h.ritualKategorien.some((k) => k.energie === 'AsP' && k.rituale.length);
  const wirken = hatWirken(h) ? `<button type="button" data-action="zu-wirken"><b>${icon(arkan ? 'star' : 'sun')}</b><span>${arkan ? 'Zauber' : 'Liturgie'}</span></button>` : '';
  if (v.nah) {
    return `<nav class="wuerfelleiste" aria-label="Schnellaktionen">${knopf('at', 'Angriff', v.at)}${knopf('pa', 'Parade', v.pa)}${v.schildNutzbar ? knopf('schild', 'Schild', v.schildPa) : ''}${knopf('aw', 'Ausw.', '…')}${knopf('tp', 'TP', v.tpText)}${wirken}</nav>`;
  }
  return `<nav class="wuerfelleiste" aria-label="Schnellaktionen">${knopf('fk', 'Schuss', v.fkZiel)}${knopf('aw', 'Ausw.', '…')}${knopf('tp', 'TP', v.tpText)}<button type="button" data-action="nachladen"><b>${icon('bow')}</b><span>Laden</span></button>${wirken}</nav>`;
}

function lageBanner(h, g, v) {
  if (!v.lage) return '';
  if (v.lage.art === 'tot') return `<div class="banner" role="alert">${icon('alert')}<span>Tot – ${esc(v.lage.text)}</span></div>`;
  if (v.lage.art === 'lebensgefahr') {
    return `<div class="banner" role="alert">${icon('alert')}<span>Lebensgefahr – ${g.todesfrist !== null ? `stirbt in ${g.todesfrist} KR ohne Hilfe` : 'W6 × KO KR'}. Rettung: Heilkunde Wunden, erschwert um das Doppelte der LeP unter 0 (WdS S. 57).</span></div>`;
  }
  if (g.kfIgnoriert > 0) return '';
  return `<div class="banner" role="alert">${icon('alert')}<span>Kampfunfähig – ${esc(v.lage.text)}. Keine Aktionen außer Bewegen mit GS 1, kein Zaubern.</span>
    ${v.lage.ignorierbar && !g.kfIgnoriertGenutzt ? '<button type="button" class="btn btn-sekundaer btn-klein" data-action="kf-ignorieren">Ignorieren (SB +12)</button>' : ''}</div>`;
}

// ---------------------------------------------------------------- Ansichten
function stufe() {
  const b = frame.clientWidth;
  if (b < 744) return 'schmal';
  if (b < 1024) return 'tablet';
  if (b < 1366) return 'breit';
  return 'sehrBreit';
}

function renderRuhe(h, g, v) {
  const w = v.waffe;
  const band = g ? `<div class="band" role="status">${icon('sword')}<div class="band-text"><b>Gefecht läuft</b> · Kampfrunde ${g.kr} · INI ${minus(v.iniAktuell)}</div>
    <button type="button" class="btn btn-primaer" data-action="zum-gefecht">Zurück zum Gefecht${icon('next')}</button></div>` : '';
  const kampf = `<section class="zone senke akzent" aria-labelledby="z-kampf">
    ${zoneKopf('shield', '<span id="z-kampf">Kampf</span>')}
    <div class="waffe-meta"><b style="color:var(--schrift)">${esc(w.name)}</b> · ${esc(w.talent)}${h.nebenhand ? ` · ${esc(h.nebenhand.name)}` : ''}</div>
    <div class="kampf-kurz">
      ${v.nah ? `<div><span class="etikett">AT</span><span class="wert">${v.at}</span></div><div><span class="etikett">PA</span><span class="wert">${v.pa}</span></div>` : `<div><span class="etikett">FK</span><span class="wert">${v.fk}</span></div><div><span class="etikett">Ladezeit</span><span class="wert">${w.ladezeit}</span></div>`}
      <div><span class="etikett">TP</span><span class="wert">${v.tpText}</span></div>
      <div><span class="etikett">INI</span><span class="wert">${g ? minus(v.iniAktuell) : `${v.iniOhneWurf} + 1W6`}</span></div>
      <div><span class="etikett">AW</span><span class="wert">${v.aw}</span></div>
      <div><span class="etikett">RS / BE</span><span class="wert">${v.rs} / ${v.be}</span></div>
    </div>
    ${g ? '<button type="button" class="btn btn-sekundaer" style="width:100%" data-action="zum-gefecht">Zurück zum Gefecht</button>'
    : `<button type="button" class="btn btn-primaer" style="width:100%" data-action="gefecht-beginnen">${icon('sword')}Gefecht beginnen</button>`}
  </section>`;
  const seite = `${kampf}
    <section class="zone senke astral">${zoneKopf('star', 'Aktive Effekte')}${h.effekte.length ? h.effekte.map((e) => `<div class="effekt">${icon('star')}<div class="zeile-text"><b>${esc(e.name)}</b></div><span class="chip-marke">${e.rest <= 0 ? 'abgelaufen' : `noch ${e.rest} ${e.einheit}`}</span></div>`).join('') : '<p class="legende">Keine aktiven Effekte.</p>'}</section>
    <section class="zone senke">${zoneKopf('person', 'Zustand')}<p class="platzhalter legende">Belastung, Wunden und Statuswerte wie bisher.</p></section>`;
  const haupt = `
    ${ressourcenHtml(h)}
    <div class="aktionen-zeile" style="margin:16px 0">
      <button type="button" class="btn btn-primaer" data-action="hinweis" data-text="Öffnet die Probensuche der App (Strg K).">${icon('search')}Probe suchen</button>
      <button type="button" class="btn btn-sekundaer" data-action="hinweis" data-text="Öffnet in der App den Rast-Dialog.">Rast</button>
      <button type="button" class="btn btn-sekundaer" data-action="schaden">Schaden erhalten</button>
    </div>
    <section class="zone">${zoneKopf('person', 'Eigenschaften')}<div class="eigenschaften">${Object.entries(h.eigenschaften).map(([k, wert]) => `<div class="wert">${k} ${wert}</div>`).join('')}</div></section>
    <section class="zone">${zoneKopf('book', 'Vor- und Nachteile')}<p class="platzhalter legende">Wie bisher – hier unverändert und nur angedeutet.</p></section>`;
  const nav = `<nav class="nav" aria-label="Bereiche">
    <div class="nav-marke">${icon('compass')}Heldenverwaltung</div>
    <div class="nav-held">${heldenmarke(h)}<div><b>${esc(h.name)}</b><small>${esc(h.profession)}</small></div></div>
    <a href="#" aria-current="page" data-action="hinweis" data-text="Du bist im Bereich Spielen.">${icon('dice')}Spielen</a><a href="#" data-action="hinweis" data-text="Nur angedeutet.">${icon('person')}Held verwalten</a><a href="#" data-action="hinweis" data-text="Nur angedeutet.">${icon('grow')}Entwicklung planen</a>
  </nav>`;
  const appbar = `<div class="appbar">${heldenmarke(h)}<span class="abschnitt">${esc(h.name)}</span></div>`;
  // Die Spalten ordnet das Stylesheet je Breite; schmal folgt die Seitenspalte darunter.
  return `<div class="spiel">${nav}<div>${appbar}<main class="spiel-inhalt">
    <header class="seitenkopf"><h1 class="titel-gross">Am Spieltisch</h1><p class="legende">Spielansicht vereinfacht – nur der Kampfabschnitt ist neu.</p></header>
    ${band}<div class="spiel-raster"><div>${haupt}</div><div class="g-spalte">${seite}</div></div></main></div></div>`;
}

function renderGefecht(h, g, v) {
  const st = stufe();
  const plan = aktionsplan(h, g, v);
  const kopf = `<header class="g-kopf">
    <button type="button" class="btn btn-icon btn-leise" data-action="zurueck" aria-label="Zur Spielansicht – das Gefecht läuft weiter" title="Zur Spielansicht">${icon('back')}</button>
    <div class="g-kopf-titel">${heldenmarke(h)}<div><div class="kontext">${esc(h.name)} · ${esc(h.profession)}</div>
      <h1><span class="titel">Gefecht</span><span class="etikett">Kampfrunde ${g.kr} · INI ${minus(v.iniAktuell)}</span></h1></div></div>
    <div class="g-kopf-aktionen">
      <button type="button" class="btn btn-leise nur-breit" data-action="hinweis" data-text="Öffnet die Probensuche der App (Strg K).">${icon('search')}Probe suchen</button>
      <button type="button" class="btn btn-icon btn-leise" data-action="hinweis" data-text="Öffnet die Probensuche der App (Strg K)." aria-label="Probe suchen" ${st === 'breit' || st === 'sehrBreit' ? 'hidden' : ''}>${icon('search')}</button>
      <button type="button" class="btn btn-gefahr ${st === 'schmal' ? 'btn-icon' : ''}" data-action="beenden" aria-label="Gefecht beenden">${icon('flag')}${st === 'schmal' ? '' : 'Gefecht beenden'}</button>
    </div>
  </header>`;
  const banner = lageBanner(h, g, v);
  const takt = kompakterTakt(h, g, v, plan);
  const durch = zoneDurchhalten(h, v);
  const eff = zoneEffekte(h);
  const angriff = zoneAngriff(h, g, v);
  const vert = zoneVerteidigung(h, g, v);
  const wirken = hatWirken(h) ? zoneWirken(h, g) : '';
  let inhalt;
  if (st === 'schmal') {
    const le = h.ressourcen.lep;
    const durchDetails = `<details class="zone durch-details" ${v.wunden || v.leStufe ? 'open' : ''}><summary><span class="abschnitt">Durchhalten</span><span class="etikett">${le.wert}/${le.max} LeP · ${v.wunden} Wunden</span>${icon('chevron', 'auf')}</summary><div class="durch-inhalt">${durch}</div></details>`;
    inhalt = `${kopf}<main class="g-inhalt">${banner}${takt}${angriff}${zoneKoennen(h, v, false)}${vert}${wirken}${durchDetails}${eff}${zoneProtokoll(g, false)}</main>
      ${wuerfelleiste(h, v)}`;
  } else if (st === 'tablet') {
    inhalt = `${kopf}<main class="g-inhalt">${banner}${takt}
      <div class="g-spalten"><div class="g-spalte">${angriff}${zoneKoennen(h, v, false)}${wirken}</div><div class="g-spalte">${vert}${durch}${eff}</div></div>
      ${zoneProtokoll(g, true)}</main>`;
  } else {
    inhalt = `${kopf}<main class="g-inhalt">${banner}${takt}
      <div class="g-spalten"><div class="g-spalte">${angriff}${zoneKoennen(h, v, false)}${wirken}</div><div class="g-spalte">${vert}</div><div class="g-spalte durchhalten">${durch}${eff}</div></div>
      ${zoneProtokoll(g, true)}</main>`;
  }
  return `<div class="gefecht">${inhalt}</div>`;
}

// Am Handy bleiben Haltung, Gegner und „Aktion wählen“ auch bei zugeklapptem Plan erreichbar.
function zustandKompakt(h, g, v) {
  return `<section class="zone senke zustand-zone" aria-label="Zustand im Kampf">${zustandHtml(h, g, v)}</section>`;
}

function render() {
  const aktiv = document.activeElement;
  const fokus = aktiv && app.contains(aktiv) ? fokusSchluessel(aktiv) : null;
  const scroll = app.scrollTop;
  const h = S.held;
  const g = S.gefecht;
  const v = berechne(h, g);
  app.innerHTML = S.ansicht === 'gefecht' && g ? renderGefecht(h, g, v) : renderRuhe(h, g, v);
  app.scrollTop = scroll;
  S.rundeAnimiert = false;
  filterWirken();
  if (fokus) {
    const ziel = app.querySelector(fokus);
    if (ziel) ziel.focus({ preventScroll: true });
  }
  document.querySelectorAll('#ctl-breite button').forEach((b) => b.setAttribute('aria-pressed', String(Number(b.dataset.breite) === S.breite)));
  document.querySelectorAll('#ctl-thema button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.thema === S.thema)));
  const le = $('#ctl-le');
  if (le) le.checked = S.optLe;
}

function fokusSchluessel(el) {
  const a = el.dataset.action;
  if (!a) return null;
  const teile = [`[data-action="${a}"]`];
  ['id', 'art', 'wert', 'key', 'i', 'akt'].forEach((k) => { if (el.dataset[k] !== undefined) teile.push(`[data-${k}="${el.dataset[k]}"]`); });
  return teile.join('');
}

// ---------------------------------------------------------------- Dialoge
// Folgedialoge (z. B. Kosten nach einem unterbrochenen Zauber) warten, bis der offene Dialog zu ist.
const warteschlange = [];
function danach(fn) { if (dlg.open) warteschlange.push(fn); else fn(); }
dlg.addEventListener('close', () => { setTimeout(() => { if (!dlg.open && warteschlange.length) warteschlange.shift()(); }, 0); });

function oeffneDialog(html, handlers = {}, beiEingabe = null) {
  dlg.innerHTML = html;
  dlg.handlers = handlers;
  dlg.beiEingabe = beiEingabe;
  if (!dlg.open) dlg.showModal();
  if (beiEingabe) beiEingabe();
  const erstes = dlg.querySelector('[autofocus]') || dlg.querySelector('input, select, button:not([disabled])');
  if (erstes) erstes.focus();
}
dlg.addEventListener('click', (e) => {
  if (e.target === dlg) { dlg.close(); return; }
  const b = e.target.closest('[data-dlg]');
  if (!b || b.disabled) return;
  if (b.dataset.dlg === 'schliessen') { dlg.close(); return; }
  const f = dlg.handlers && dlg.handlers[b.dataset.dlg];
  if (f) f(b);
});
dlg.addEventListener('input', () => { if (dlg.beiEingabe) dlg.beiEingabe(); });
const abbrechen = (text = 'Abbrechen') => `<button type="button" class="btn btn-leise" data-dlg="schliessen">${text}</button>`;

function dialogIni() {
  const h = S.held;
  // Gewünschter Startablauf wie in der App: Aufmerksamkeit setzt den maximalen Wurf.
  if (h.aufmerksamkeit) {
    beginneGefecht(h.iniSeiten);
    zeigeToast('Aufmerksamkeit: INI mit 6 statt 1W6 angesetzt.', 'compass');
    return;
  }
  const v = berechne(h, null);
  let wurfWert = null;
  oeffneDialog(`<div class="dlg-inhalt">
      <h2 id="dlg-titel">Gefecht beginnen</h2>
      <p class="legende">Die Initiative wird einmal zu Kampfbeginn ermittelt und ändert sich danach nur durch das Kampfgeschehen (WdS S. 53 f.). Würfle in der App oder trage deinen echten Wurf ein.</p>
      <dl class="tabelle-kv"><dt>INI ohne Wurf</dt><dd><b>${v.iniOhneWurf}</b> <span class="leise">(${esc(h.iniHerkunft)}${v.axx ? ` · Axxeleratus +${h.axxIni}` : ''} · BE ${minus(-v.be)})</span></dd></dl>
      <div class="formzeile"><label for="ini-wurf">Wurf 1W${h.iniSeiten}</label>
        <input class="eingabe" id="ini-wurf" type="number" min="1" max="${h.iniSeiten}" inputmode="numeric" placeholder="1–${h.iniSeiten}">
        <button type="button" class="btn btn-sekundaer" data-dlg="wuerfeln">${icon('dice')}Würfeln</button></div>
      <div class="ergebnis" id="ini-ergebnis"></div>
    </div>
    <div class="dlg-aktionen">${abbrechen()}<button type="button" class="btn btn-primaer" data-dlg="start" id="ini-start" disabled>${icon('sword')}Gefecht beginnen</button></div>`, {
    wuerfeln: () => { $('#ini-wurf').value = wuerfel(h.iniSeiten); dlg.beiEingabe(); },
    start: () => { if (wurfWert) { dlg.close(); beginneGefecht(wurfWert); } },
  }, () => {
    const roh = Number($('#ini-wurf').value);
    wurfWert = Number.isInteger(roh) && roh >= 1 && roh <= h.iniSeiten ? roh : null;
    $('#ini-start').disabled = !wurfWert;
    if (!wurfWert) { $('#ini-ergebnis').innerHTML = '<span class="leise">Noch kein Wurf.</span>'; return; }
    const ini = v.iniOhneWurf + wurfWert;
    const stufeIni = iniStufe(ini);
    $('#ini-ergebnis').innerHTML = `Kampf-INI <b>${ini}</b>${stufeIni ? ` · Abwehr ${vz(stufeIni)} · ${stufeIni} freie Aktion${stufeIni > 1 ? 'en' : ''} mehr je Runde (WdS S. 79)` : ' · keine Boni durch hohe INI (ab 21)'}`;
  });
}

function dialogBeenden() {
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">Gefecht beenden?</h2>
      <p>Kampfrunde, INI-Wurf und Aktionsplan werden verworfen. Ressourcen, Wunden und aktive Effekte bleiben, wie sie sind.</p></div>
    <div class="dlg-aktionen">${abbrechen('Weiterkämpfen')}<button type="button" class="btn btn-gefahr" data-dlg="ende">${icon('flag')}Gefecht beenden</button></div>`, {
    ende: () => { dlg.close(); S.gefecht = null; S.ansicht = 'ruhe'; zeigeToast('Gefecht beendet.', 'flag'); render(); },
  });
}

function dialogRessource(key) {
  const r = RESSOURCEN.find((x) => x.key === key);
  const aktualisiere = () => {
    const { wert, max } = S.held.ressourcen[key];
    $('#res-wert').innerHTML = `${minus(wert)}<span class="bezug"> / ${max}</span>`;
    render();
  };
  const schritt = (d) => {
    const res = S.held.ressourcen[key];
    const vorher = res.wert;
    res.wert = Math.max(key === 'lep' ? -40 : 0, res.wert + d);
    if (key === 'lep') pruefeLage(vorher);
    aktualisiere();
  };
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">${r.name}</h2>
      <p class="wert-gross" id="res-wert" aria-live="polite"></p>
      <div class="aktionen-zeile">${[-5, -1, 1, 5].map((d) => `<button type="button" class="btn btn-sekundaer" data-dlg="s${d}">${vz(d)}</button>`).join('')}
        <button type="button" class="btn btn-leise" data-dlg="voll">Auf Maximum</button></div>
      <p class="legende">In der App: das vorhandene Ressourcenblatt, Schritte zählen immer vom gespeicherten Wert.</p></div>
    <div class="dlg-aktionen">${abbrechen('Fertig')}</div>`, {
    's-5': () => schritt(-5), 's-1': () => schritt(-1), s1: () => schritt(1), s5: () => schritt(5),
    voll: () => { S.held.ressourcen[key].wert = S.held.ressourcen[key].max; if (key === 'lep') pruefeLage(-1); aktualisiere(); },
  });
  aktualisiere();
}

function dialogSchaden() {
  const h = S.held;
  const g = S.gefecht;
  const v = berechne(h, g);
  let daten = { sp: 0, vorschlag: 0 };
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">Schaden erhalten</h2>
      <div class="formzeile"><label for="sch-tp">Trefferpunkte</label><input class="eingabe" id="sch-tp" type="number" min="0" inputmode="numeric" value="12" autofocus></div>
      <div class="formzeile"><label for="sch-zone">Trefferzone</label><select class="select" id="sch-zone">${ZONEN.map((z) => `<option>${z}</option>`).join('')}</select></div>
      <div class="formzeile"><label for="sch-wunden">Wunden</label><input class="eingabe" id="sch-wunden" type="number" min="0" max="3" inputmode="numeric"></div>
      <div class="ergebnis" id="sch-ergebnis"></div>
      ${g && g.handlung && (g.handlung.typ === 'zauber' || g.handlung.typ === 'liturgie') ? `<p class="obergrenze">${icon('alert')}<span>${esc(g.handlung.name)} läuft: danach Selbstbeherrschungs-Probe +SP${h.konzentrationsstaerke ? ' −7 (Konzentrationsstärke)' : ''}, sonst misslingt das Wirken (WdZ S. 15).</span></p>` : ''}
      <p class="legende">Vereinfacht. Die App öffnet den vorhandenen Schadensdialog mit TP(A), Zonen-RS, Zusatzwürfen und Unterdrücken.</p></div>
    <div class="dlg-aktionen">${abbrechen()}<button type="button" class="btn btn-primaer" data-dlg="ok">Übernehmen</button></div>`, {
    ok: () => {
      const zone = $('#sch-zone').value;
      const n = Math.max(0, Math.min(3, Number($('#sch-wunden').value) || 0));
      const vorher = h.ressourcen.lep.wert;
      h.ressourcen.lep.wert -= daten.sp;
      if (n) {
        h.wunden[zone] = Math.min(3, (h.wunden[zone] || 0) + n);
        if (zone === 'Kopf') h.kopfIni += wuerfel(6) + wuerfel(6);
      }
      protokolliere(`Schaden erhalten (${zone})`, `${daten.sp} SP`, n ? `${n} ${n === 1 ? 'Wunde' : 'Wunden'}` : '');
      pruefeLage(vorher);
      dlg.close();
      zeigeToast(`${daten.sp} SP${n ? `, ${n} ${n === 1 ? 'Wunde' : 'Wunden'} (${zone})` : ''}`, 'heart');
      render();
      if (g && g.handlung && (g.handlung.typ === 'zauber' || g.handlung.typ === 'liturgie') && daten.sp > 0) konzentrationHalten(daten.sp);
    },
  }, () => {
    const tp = Math.max(0, Number($('#sch-tp').value) || 0);
    const sp = Math.max(0, tp - v.rs);
    const vorschlag = h.wundschwellen.filter((ws) => sp > ws).length;
    const feld = $('#sch-wunden');
    if (daten.vorschlag !== vorschlag || feld.value === '') feld.value = vorschlag;
    daten = { sp, vorschlag };
    $('#sch-ergebnis').innerHTML = `RS ${v.rs} → <b>${sp} SP</b> · Wundschwellen ${h.wundschwellen.join(' · ')} → ${vorschlag} ${vorschlag === 1 ? 'Wunde' : 'Wunden'} vorgeschlagen`;
  });
}

// Störung während des Wirkens: Selbstbeherrschung +SP, mit Konzentrationsstärke −7 (WdZ S. 15, WdG S. 251).
function konzentrationHalten(sp) {
  const h = S.held;
  const g = S.gefecht;
  const zuschlag = sp - (h.konzentrationsstaerke ? 7 : 0);
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">Konzentration halten</h2>
      <p>${esc(g.handlung.name)} wird gestört. Selbstbeherrschung ${h.selbstbeherrschung} (MU/KO/KK), erschwert um ${zuschlag}.</p></div>
    <div class="dlg-aktionen"><button type="button" class="btn btn-primaer" data-dlg="los">${icon('dice')}Selbstbeherrschung würfeln</button></div>`, {
    los: () => {
      const r = talentProbe('Selbstbeherrschung', h.selbstbeherrschung, ['MU', 'KO', 'KK'], zuschlag);
      protokolliere('Konzentration halten', r.gelungen ? 'gelungen' : 'misslungen', `3W20 ${r.w.join('/')} · +${zuschlag}`);
      dlg.close();
      if (r.gelungen) { zeigeToast('Konzentration gehalten – das Wirken läuft weiter.', 'check'); render(); } else { zeigeToast('Konzentration verloren – das Wirken misslingt.', 'alert'); brichHandlungAb(true, true); }
    },
  });
}

function dialogManoever(id) {
  const h = S.held;
  const m = h.manoever.find((x) => x.id === id);
  const { v, plan } = aktuellerPlan();
  const g = S.gefecht;
  const option = manoeverOption(m, h, g, v);
  const art = m.abwehr ? 'pa' : 'at';
  const basisWert = m.abwehr ? v.pa : v.at;
  const ers = erschwernis(h, g, v, art);
  function ziel() {
    const gegner = m.proGegner ? Math.max(1, Number($('#m-gegner').value) || 1) : 1;
    return { basis: (m.basis || 0) * gegner, ansage: m.ansage ? Math.max(0, Number($('#m-ansage').value) || 0) : 0 };
  }
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">${esc(m.name)}</h2>
      <div class="aktionen-zeile"><span class="chip-marke">${esc(m.typ)}</span><span class="chip-marke">Haupthand</span></div>
      <p>${esc(m.text)}</p>
      <dl class="tabelle-kv"><dt>Erschwernis</dt><dd>${esc(m.erschwernis)}</dd><dt>Verbraucht</dt><dd>${VERBRAUCH_TEXT[m.verbrauch]}</dd></dl>
      <p class="legende">Misslingt ein Manöver mit Ansage, ist die nächste Aktion um die Ansage erschwert. Gegnerische Manöver prüfst du mit der Spielleitung.</p>
      ${m.nurAnsage ? `<div class="ergebnis">Parade ${v.pa} → 2 × PA ${v.klingenwand}. Ansage zu Rundenbeginn; nicht genutzte Paraden verfallen.</div>` : `
      ${m.proGegner ? '<div class="formzeile"><label for="m-gegner">Gegner</label><input class="eingabe" id="m-gegner" type="number" min="1" max="3" value="2"></div>' : ''}
      ${m.ansage ? '<div class="formzeile"><label for="m-ansage">Ansage</label><input class="eingabe" id="m-ansage" type="number" min="0" value="2"></div>' : ''}
      <div class="formzeile"><label for="m-dk">Aktuelle DK</label><select class="select" id="m-dk"><option value="">Bitte prüfen</option>${['H', 'N', 'S', 'P'].map((x) => `<option value="${x}" ${g.distanzklasse === x ? 'selected' : ''}>${x}</option>`).join('')}</select></div>
      ${m.zielPruefen ? `<label class="ziel-pruefung"><input type="checkbox" id="m-ziel">${esc(m.zielPruefen)} Voraussetzung geprüft.</label>` : ''}
      <div class="ergebnis" id="m-ergebnis"></div>`}
      ${option.grund ? `<p class="obergrenze">${icon('alert')}<span>${esc(option.grund)}</span></p>` : ''}
    </div>
    <div class="dlg-aktionen">${abbrechen(m.nurAnsage ? 'Schließen' : 'Abbrechen')}${m.nurAnsage ? '' : `<button type="button" class="btn btn-primaer" data-dlg="wuerfeln" disabled>${icon('dice')}Ansagen und würfeln</button>`}</div>`, {
    wuerfeln: () => {
      const z = ziel();
      const dk = $('#m-dk').value || null;
      const pruefung = manoeverOption(m, h, { ...g, distanzklasse: dk }, v);
      if (pruefung.grund || !dk || (m.zielPruefen && !$('#m-ziel').checked)) return;
      g.distanzklasse = dk;
      dlg.close();
      const sperre = kampfSperre(v, art);
      if (sperre) { zeigeToast(sperre, 'alert'); return; }
      mitUnterbrechung(m.name, () => {
        const res = kampfwurf({ art, titel: m.name, basis: basisWert, verbrauch: m.verbrauch, label: m.name, ansage: z.ansage, zusatz: z.basis });
        if (!res) return;
        zeigeWurfErgebnis(m.name, art, res);
        render();
      });
    },
  }, m.nurAnsage ? null : () => {
    const z = ziel();
    const dk = $('#m-dk').value || null;
    const pruefung = manoeverOption(m, h, { ...g, distanzklasse: dk }, v);
    const grund = pruefung.grund || (!dk ? 'Aktuelle Distanzklasse wählen.' : m.zielPruefen && !$('#m-ziel').checked ? 'Gegnervoraussetzung bestätigen.' : null);
    const zielwert = basisWert - z.basis - z.ansage - ers.summe - pruefung.zuschlag;
    $('#m-ergebnis').innerHTML = `${m.abwehr ? 'Parade' : 'Attacke'} ${basisWert} − ${z.basis + z.ansage}${ers.summe ? ` − ${ers.summe} (${esc(erschwernisText(ers))})` : ''}${pruefung.zuschlag ? ` − ${pruefung.zuschlag} (Umwandeln)` : ''} = Zielwert <b>${minus(zielwert)}</b>${grund ? `<br>${esc(grund)}` : ''}`;
    dlg.querySelector('[data-dlg="wuerfeln"]').disabled = Boolean(grund);
  });
}

// ---------------------------------------------------------------- Toast
function zeigeToast(text, sym = 'info') {
  toastEl.innerHTML = `${icon(sym)}<span>${esc(text)}</span>`;
  toastEl.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { toastEl.hidden = true; }, 3800);
}

// ---------------------------------------------------------------- Ereignisse
app.addEventListener('click', (e) => {
  const el = e.target.closest('[data-action]');
  if (!el || el.disabled) return;
  const a = el.dataset.action;
  const h = S.held;
  const g = S.gefecht;
  if (el.tagName === 'A') e.preventDefault();
  switch (a) {
    case 'gefecht-beginnen': dialogIni(); break;
    case 'zum-gefecht': S.ansicht = 'gefecht'; app.scrollTop = 0; render(); break;
    case 'zurueck': S.ansicht = 'ruhe'; app.scrollTop = 0; render(); break;
    case 'beenden': dialogBeenden(); break;
    case 'naechste-runde': naechsteRunde(); break;
    case 'takt-auf': S.taktOffen = !S.taktOffen; if (S.taktOffen) app.scrollTop = 0; render(); break;
    case 'takt-info': dialogTaktInfo(); break;
    case 'marke':
      if (g.verbraucht[el.dataset.id]) { delete g.verbraucht[el.dataset.id]; delete g.lang[el.dataset.id]; } else { fixiereIniBoni(); g.verbraucht[el.dataset.id] = 'von Hand'; }
      render(); break;
    case 'umwandeln': {
      const { plan } = aktuellerPlan();
      if (ansageGesperrt(h, g, plan)) break;
      g.umwandeln = el.dataset.wert;
      if (g.umwandeln === 'pa-at') g.zweiSchildparaden = false;
      render(); break;
    }
    case 'ausruestung': dialogAusruestung(el.dataset.bereich); break;
    case 'zwei-schild': g.zweiSchildparaden = !g.zweiSchildparaden; render(); break;
    case 'ini': g.iniVerlust = Math.max(0, g.iniVerlust + Number(el.dataset.wert)); render(); break;
    case 'haltung': g.haltung = el.dataset.wert; render(); break;
    case 'gegner': g.gegner = Number(el.dataset.wert); render(); break;
    case 'aktionen': dialogAktionen(); break;
    case 'aktion-direkt': fuehreAktionAus(el.dataset.akt); break;
    case 'position': aktionPosition(); break;
    case 'kf-ignorieren': dialogKampfunfaehigIgnorieren(); break;
    case 'wurf': wurf(el.dataset.art); break;
    case 'nachladen': fuehreAktionAus('laden'); break;
    case 'ziehen': fuehreAktionAus(`ziehen:${el.dataset.id}`); break;
    case 'entfernung': aktiveWaffe(h).entfernung = Number(el.dataset.i); render(); break;
    case 'geschoss-schritt': {
      const w = aktiveWaffe(h);
      const gs = w.geschosse[w.geschoss];
      gs.anzahl = Math.max(0, gs.anzahl + Number(el.dataset.wert));
      render(); break;
    }
    case 'ruestung': {
      const r = h.ruestung.find((x) => x.id === el.dataset.id);
      r.an = !r.an;
      render(); break;
    }
    case 'ressource': dialogRessource(el.dataset.key); break;
    case 'schaden': dialogSchaden(); break;
    case 'manoever': dialogManoever(el.dataset.id); break;
    case 'hinweis': zeigeToast(el.dataset.text, 'info'); break;
    case 'wirken': dialogWirken(el.dataset.typ, el.dataset.id); break;
    case 'karmal': dialogKarmal(el.dataset.id); break;
    case 'mirakel': fuehreAktionAus('mirakel'); break;
    case 'wirken-kurz': S.wirkenKurz = !S.wirkenKurz; render(); break;
    case 'handlung-weiter': setzeHandlungFort(); break;
    case 'handlung-abbruch': brichHandlungAb(true, true); break;
    case 'zu-wirken': {
      const zone = app.querySelector('#z-wirken');
      if (zone) {
        // Der klebende Kopf (samt laufender Handlung) darf den Bereichstitel nicht verdecken.
        const stapel = app.querySelector('.kopf-stapel');
        const versatz = (stapel ? stapel.offsetHeight : 0) + 8;
        app.scrollTop += zone.getBoundingClientRect().top - app.getBoundingClientRect().top - versatz;
        const suche = zone.querySelector('input');
        if (suche) suche.focus({ preventScroll: true });
      }
      break;
    }
    default: break;
  }
});
app.addEventListener('input', (e) => {
  if (e.target.dataset.input === 'wirken-suche') { S.wirkenSuche = e.target.value; filterWirken(); }
});
app.addEventListener('change', (e) => {
  const typ = e.target.dataset.change;
  const g = S.gefecht;
  if (typ === 'geschoss') aktiveWaffe(S.held).geschoss = Number(e.target.value);
  else if (typ === 'haltung') g.haltung = e.target.value;
  else if (typ === 'gegner') g.gegner = Number(e.target.value);
  else if (typ === 'distanzklasse') g.distanzklasse = e.target.value || null;
  else if (typ === 'umwandeln') {
    const { plan } = aktuellerPlan();
    if (!ansageGesperrt(S.held, g, plan)) {
      g.umwandeln = e.target.value;
      if (g.umwandeln === 'pa-at') g.zweiSchildparaden = false;
    }
  } else return;
  render();
});
document.addEventListener('keydown', (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k' && S.ansicht === 'gefecht' && !dlg.open) {
    e.preventDefault();
    zeigeToast('Öffnet die Probensuche der App (Strg K).', 'search');
  }
});

function neuStarten(key) {
  S.heldKey = key;
  S.held = structuredClone(HELDEN[key]);
  S.gefecht = null;
  S.ansicht = 'ruhe';
  S.taktOffen = false;
  app.scrollTop = 0;
}
$('#ctl-held').addEventListener('change', (e) => { neuStarten(e.target.value); render(); });
$('#ctl-reset').addEventListener('click', () => { neuStarten(S.heldKey); render(); });
$('#ctl-le').addEventListener('change', (e) => { S.optLe = e.target.checked; render(); });
$('#ctl-breite').addEventListener('click', (e) => {
  const b = e.target.closest('button');
  if (!b) return;
  S.breite = Number(b.dataset.breite);
  frame.style.width = `${S.breite}px`;
  frame.dataset.breite = String(S.breite);
  S.taktOffen = false;
  render();
});
$('#ctl-thema').addEventListener('click', (e) => {
  const b = e.target.closest('button');
  if (!b) return;
  S.thema = b.dataset.thema;
  frame.dataset.theme = S.thema;
  render();
});
window.addEventListener('resize', () => render());

// Startzustand aus der Adresse, z. B. gefecht.html#magier,390,dunkel,gefecht
(function start() {
  const teile = decodeURIComponent(location.hash.slice(1)).split(',').filter(Boolean);
  teile.forEach((t) => {
    if (HELDEN[t]) neuStarten(t);
    if (['390', '820', '1200', '1440'].includes(t)) S.breite = Number(t);
    if (t === 'hell' || t === 'dunkel') S.thema = t;
  });
  $('#ctl-held').value = S.heldKey;
  frame.style.width = `${S.breite}px`;
  frame.dataset.breite = String(S.breite);
  frame.dataset.theme = S.thema;
  if (teile.includes('gefecht')) beginneGefecht(S.held.aufmerksamkeit ? S.held.iniSeiten : 5);
  else render();
}());
