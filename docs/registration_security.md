# Geschützte Registrierung

Stand: 17. Oktober 2026. Neue Konten werden erst nach einem serverseitig
geprüften Registrierungs-Keyword zugelassen. Das Keyword wird weder in einen
Client-Build geschrieben noch in Firestore gespeichert.

## Ablauf

1. Der Client sendet normalisierte E-Mail und eingegebenes Keyword zusammen
   mit einem frischen App-Check-Token an `registrationInviteApi`.
2. Die Function begrenzt Versuche pro IP-Schlüssel und pro E-Mail auf fünf je
   Stunde und vergleicht das Keyword zeitkonstant mit dem Secret
   `REGISTRATION_KEYWORD`.
3. Bei Erfolg schreibt sie unter `registration_invites/<sha256(email)>` ein
   zehn Minuten gültiges Ticket. Gespeichert werden normalisierte E-Mail,
   Ablaufzeit, Erstellzeit, Keyword-Version und Verwendungsstatus, niemals das
   Keyword selbst.
4. Der Client ruft erst danach Firebase Authentication auf. Die
   Auth-Blocking-Function `registrationGate` verbraucht das E-Mail-Ticket in
   einer Firestore-Transaktion. Fehlende, abgelaufene oder bereits verwendete
   Tickets lehnen die Kontoerstellung ab.

Die Collections `registration_invites` und `registration_invite_limits` fallen
unter die abschließende Deny-Regel in `firestore.rules` und sind für Clients
nicht les- oder schreibbar. Für `expiresAt` ist zusätzlich eine Firestore-TTL
zu konfigurieren; die fachliche Gültigkeitsprüfung hängt nicht von der späteren
TTL-Bereinigung ab.

## Sichere Inbetriebnahme

Die Functions dürfen nicht vor ihren Voraussetzungen veröffentlicht werden:

1. Identity Platform und Auth-Blocking-Functions für das Projekt aktivieren.
2. App Check für Web/Mobile registrieren und den Client mit
   `REGISTRATION_INVITE_API_URL` sowie gültigem Site-Key bauen.
3. Keyword interaktiv setzen:
   `firebase functions:secrets:set REGISTRATION_KEYWORD`.
4. `registrationInviteApi` und `registrationGate` gezielt in die Testfreigabe
   deployen und fehlendes, falsches, abgelaufenes und wiederverwendetes Ticket
   prüfen.
5. Erst danach den Client veröffentlichen. Bestehende Logins werden von
   `registrationGate` nicht verändert.

Das Keyword wird nach Verdacht und planmäßig rotiert. Bereits ausgestellte
Tickets bleiben höchstens zehn Minuten gültig; für einen sofortigen Widerruf
werden die privaten Ticketdokumente administrativ invalidiert.
