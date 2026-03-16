/// Sentinel-Objekt fuer nullable copyWith-Parameter.
///
/// Wird als Defaultwert in `copyWith`-Methoden verwendet, um zwischen
/// "nicht uebergeben" (Sentinel) und "explizit null" unterscheiden zu koennen.
/// Vergleich stets mit [identical], nicht mit `==`.
const Object keepFieldValue = Object();
