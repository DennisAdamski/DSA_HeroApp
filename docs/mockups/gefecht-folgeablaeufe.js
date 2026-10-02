/* Separater Bedienprototyp der Folgepakete. Keine produktive Regelengine,
 * keine Speicherung und kein Eingriff in die Beispiel-Kampfsitzung. */
'use strict';

function dialogFolgeablaeufe(art = 'orientieren', schritt = 0, fehler = false) {
  const h = S.held;
  const titel = { orientieren: 'Orientieren', kontext: 'Angriff / Verteidigung',
    ziehen: 'Geführtes Ziehen', wirken: 'Wirken und Abschluss' }[art];
  const navigation = Object.entries({ orientieren: 'Orientieren', kontext: 'Kontext',
    ziehen: 'Ziehen', wirken: 'Wirken' }).map(([key, name]) =>
    `<button type="button" data-dlg="ablauf" data-typ="${key}">${name}</button>`).join('');
  let inhalt = '';
  let weiter = 'Bestätigen';
  if (art === 'orientieren') {
    const bonus = Math.floor(Math.max(0, h.kriegskunst) / 2);
    inhalt = `<dl class="tabelle-kv"><dt>Dauer</dt><dd>${h.aufmerksamkeit ? 1 : 2} reguläre Aktionen</dd>
      <dt>Probe</dt><dd>${h.aufmerksamkeit ? 'Aufmerksamkeit: keine Probe' : `IN ${h.eigenschaften.IN} + Kriegskunst ${bonus}`}</dd>
      <dt>INI</dt><dd>Vorher → Maximum nach Erfolg; nur rückgewinnbare Kampfverluste</dd></dl>
      <p>Ungeklärte INI-Korrekturen zuerst zuordnen. Geschützte Wund-/Zaubermali bleiben erhalten.
      Position + Orientieren nach freiem Ausweichen: eine Aktion; eine erforderliche IN-Probe bleibt.</p>
      <label><input type="checkbox" id="folge-geprueft"> Wahrnehmung und Bewegung ungestört</label>
      <details><summary>Quelle / App-Abweichung</summary>WdS 56 (6973), Hausregel S.2–3
      (25817–25818). Maximale 12 bei Klingentänzer und Aufmerksamkeit-Start bleiben App-Konvention.</details>`;
    weiter = 'Ungestört beginnen';
  } else if (art === 'kontext') {
    inhalt = `<div class="formzeile"><label>Aktiver Gegnerkontakt</label><input class="eingabe" placeholder="Name / Beschreibung"></div>
      <div class="formzeile"><label>Tatsächliche DK</label><select class="eingabe"><option>Unbekannt</option><option>H</option><option>N</option><option>S</option><option>P</option></select></div>
      <div class="formzeile"><label>Angriff gegen mich</label><select class="eingabe"><option>Unbekannt</option><option>Nahkampf</option><option>Fernkampf: manuell prüfen</option></select></div>
      <div class="formzeile"><label>Finte dieses Angriffs</label><input class="eingabe" type="number" placeholder="0 erlaubt"></div>
      <p>AW fragt zusätzlich Gegnerzahl, Umstelltsein und Platz. Fernkampf fragt Entfernung,
      Zielgröße/Bewegung/Sicht/Deckung, Getümmel und Ladezustand.</p>
      <p><b>Zielwertanteile:</b> Heldenwert · Haltung/BE · DK · Finte · weitere bestätigte Zuschläge.</p>
      <p>Kontaktwechsel verwirft Angriffsdaten. Distanzänderung verursacht keinen Treffer;
      Annäherung wartet auf die gegnerische Abwehrbestätigung.</p>
      <label><input type="checkbox" id="folge-geprueft"> Fehlende relevante Angaben ergänzt</label>
      <details><summary>Quellen</summary>WdS 67–68,80 (7006–7007,7040–7041), Hausregel 25818.</details>`;
  } else if (art === 'ziehen') {
    inhalt = `<p>${h.schnellziehen ? 'Schnellziehen aktiv' : 'Ohne Schnellziehen'} · SF automatisch aus dem Helden</p>
      <div class="formzeile"><label>Trageposition</label><select class="eingabe"><option>Gürtel / Arm / Brust</option><option>Rücken</option><option>Schild vom Rücken</option></select></div>
      <p>Kosten ohne SF: 1 / 2 / 5 Aktionen. Mit Schnellziehen:
      <b>eine freie Marke</b> / 1 / 3 Aktionen.</p>
      <label><input type="checkbox" id="folge-geprueft"> Geeignete Scheide, griffbereit, Hände frei</label>
      <p>Wegstecken/Aufheben sind separate bestätigte Teilhandlungen. Der Ausrüstungswechsel
      erfolgt erst nach vollständiger Dauer; bei Schreibfehler bleibt der Abschluss offen.</p>
      <details><summary>Quelle</summary>WdS 55 (6972). Rüstungsschalter bleiben Statuskorrekturen.</details>`;
    weiter = 'Wechsel beginnen';
  } else if (schritt === 0) {
    inhalt = `<p>Gelernten Zauber und tatsächliche Repräsentation wählen; Mirakel/Liturgie getrennt führen.</p>
      <dl class="tabelle-kv"><dt>Beispiel</dt><dd>Zauber · 5 Aktionen · 7 AsP</dd>
      <dt>Probe</dt><dd>Zu Beginn genau einmal, danach eingefroren</dd></dl>
      <p>Erfolg bindet volle Dauer. Scheitern: halbe Dauer, angebrochene Aktionen aufrunden
      (App-Konvention); Zauberkontrolle: eine Aktion.</p>
      <label><input type="checkbox" id="folge-geprueft"> Zeitpunkt, Dauer, Modifikatoren und Folgen geprüft</label>
      <details><summary>Quellen / offene Fälle</summary>WdZ 13–17 (4972–4976), LL 9–14 (25843–25845).
      Liturgiezeitpunkt, permanente Kosten, AW-Mirakelbonus und Rundung weiterhin bestätigen.</details>`;
    weiter = 'Probe einmal auswerten (Beispiel)';
  } else if (schritt === 1) {
    inhalt = `<p class="ergebnis">Probe eingefroren: Beispiel gelungen, ZfP* 8</p>
      <p>Restdauer: 4 Aktionen. Navigation und Fortsetzen erzeugen keine neue Probe.</p>
      <button class="btn btn-sekundaer" data-dlg="stoerung">Störung prüfen</button>
      <button class="btn btn-leise" data-dlg="abbruch">Abbruch ausdrücklich bestätigen</button>
      <p>Selbstbeherrschung: bestätigte SP/Zuschläge, Konzentrationsstärke −7.
      Weitere ZfP*-Folgen am Spieltisch prüfen.</p>`;
    weiter = 'Restdauer fortsetzen (Beispiel)';
  } else {
    inhalt = `<p class="ergebnis">Eingefrorene Probe · Kosten 7 AsP · Folgen offen</p>
      ${fehler ? '<p class="ergebnis gefahr">Speicherfehler: Ergebnis und offene Folgen bleiben erhalten.</p>' : ''}
      <p>Ressourcen und unterstützte eigene Effekte gemeinsam frisch übernehmen. Bestehende
      Effektbearbeitung verwenden; fremde Zielwirkungen am Spieltisch bestätigen.</p>
      <label><input type="checkbox" id="folge-geprueft"> Folgen bestätigt</label>
      <button class="btn btn-leise" data-dlg="fehler">Speicherfehler darstellen</button>
      <p>Bereits übernommene Kosten werden bei späterem Folgenabschluss nicht erneut gebucht.</p>`;
    weiter = fehler ? 'Übernahme erneut versuchen' : 'Kosten und Folgen übernehmen';
  }
  oeffneDialog(`<div class="dlg-inhalt"><h2 id="dlg-titel">${titel} · Folgeablauf</h2>
    <p class="legende">Bedienprototyp · Beispiele, keine produktive Rechnung oder Speicherung</p>
    <div class="seg">${navigation}</div>${inhalt}</div><div class="dlg-aktionen">${abbrechen('Schließen')}
    <button class="btn btn-primaer" data-dlg="weiter">${weiter}</button></div>`, {
    ablauf: (b) => dialogFolgeablaeufe(b.dataset.typ),
    weiter: () => {
      const geprueft = $('#folge-geprueft');
      if (geprueft && !geprueft.checked) return;
      if (art === 'wirken' && schritt < 2) dialogFolgeablaeufe(art, schritt + 1);
      else { dlg.close(); zeigeToast('Bestätigter Bedienablauf · nur Prototyp', 'check'); }
    },
    fehler: () => dialogFolgeablaeufe('wirken', 2, true),
    stoerung: () => dialogFolgeablaeufe('wirken', 1),
    abbruch: () => dialogFolgeablaeufe('wirken', 2),
  });
}
$('#ctl-flow').addEventListener('click', () => dialogFolgeablaeufe());
