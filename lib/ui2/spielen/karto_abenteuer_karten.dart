import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Raster gleich breiter Karten, deren Zeilen gleich hoch sind.
///
/// Die Spaltenzahl folgt aus der verfuegbaren Breite und [mindestbreite]; so
/// stehen Personen auf dem Telefon untereinander und im breiten Blatt zu
/// dritt. Jede Zeile streckt ihre Karten auf die hoechste, damit kurze und
/// lange Beschreibungen keine ausgefranste Kante ergeben.
class KartoKartenraster extends StatelessWidget {
  /// Erstellt ein Raster aus [kinder].
  const KartoKartenraster({
    super.key,
    required this.mindestbreite,
    required this.kinder,
  });

  /// Schmalste Breite, die eine Karte bekommen darf.
  final double mindestbreite;

  /// Karten in Lesereihenfolge.
  final List<Widget> kinder;

  @override
  Widget build(BuildContext context) {
    const luecke = Abstand.weit;
    return LayoutBuilder(
      builder: (context, constraints) {
        final spalten = math.max(
          1,
          ((constraints.maxWidth + luecke) / (mindestbreite + luecke)).floor(),
        );
        final zeilen = <Widget>[];
        for (var start = 0; start < kinder.length; start += spalten) {
          final zellen = <Widget>[];
          for (var spalte = 0; spalte < spalten; spalte++) {
            if (spalte > 0) zellen.add(const SizedBox(width: luecke));
            final index = start + spalte;
            // Leere Zellen halten die Spaltenbreite der letzten Zeile gleich.
            zellen.add(
              Expanded(
                child: index < kinder.length
                    ? kinder[index]
                    : const SizedBox.shrink(),
              ),
            );
          }
          if (zeilen.isNotEmpty) zeilen.add(const SizedBox(height: luecke));
          zeilen.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: zellen,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: zeilen,
        );
      },
    );
  }
}

/// Person des Abenteuers als Figur: Siegel mit Initiale, Name, Rolle.
///
/// Das Siegel traegt dieselbe Ringfassung wie die Heldenmarke der
/// Navigation. Begegnungen stehen damit als Figuren auf derselben Karte wie
/// der Held, statt als Adressbuchzeilen darunter.
class KartoFigurenkarte extends StatelessWidget {
  /// Erstellt die Karte einer Person.
  const KartoFigurenkarte({
    super.key,
    required this.name,
    required this.beschreibung,
    this.onTap,
  });

  /// Name der Person; leer erscheint ein Platzhalter.
  final String name;

  /// Rolle oder Zusammenhang, auf wenige Zeilen gekuerzt.
  final String beschreibung;

  /// Oeffnet die Bearbeitung; `null` zeigt die Karte nur an.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final anzeige = name.trim().isEmpty ? 'Ohne Namen' : name.trim();
    final rolle = beschreibung.trim();

    return _TippbareKarte(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Siegel(name: name),
          const SizedBox(width: Abstand.weit),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anzeige,
                  style: texte.abschnitt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (rolle.isNotEmpty) ...[
                  const SizedBox(height: Abstand.eng),
                  Text(
                    rolle,
                    style: texte.fliess.copyWith(color: karto.schriftLeise),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Notiz des Abenteuers: Titel in der Titelschrift, Text gekuerzt.
///
/// Der volle Text steht im Bearbeitungsdialog; die Karte ist eine
/// Gedaechtnisstuetze am Tisch, keine Leseflaeche.
class KartoNotizkarte extends StatelessWidget {
  /// Erstellt die Karte einer Notiz.
  const KartoNotizkarte({
    super.key,
    required this.titel,
    required this.text,
    this.onTap,
  });

  /// Titel der Notiz; leer erscheint ein Platzhalter.
  final String titel;

  /// Notiztext.
  final String text;

  /// Oeffnet die Bearbeitung; `null` zeigt die Karte nur an.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final ueberschrift = titel.trim();
    final inhalt = text.trim();

    return _TippbareKarte(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ueberschrift.isEmpty ? 'Ohne Titel' : ueberschrift,
            style: ueberschrift.isEmpty
                ? texte.abschnitt.copyWith(color: karto.schriftLeise)
                : texte.abschnitt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (inhalt.isNotEmpty) ...[
            const SizedBox(height: Abstand.knapp),
            Text(
              inhalt,
              style: texte.fliess,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Freier Platz im Raster, der zum Anlegen einlaedt.
///
/// Sitzt als Senke eine Stufe unter den Karten: eine Vertiefung, in die noch
/// etwas gehoert. Nur mit der schwaechsten Kante und niedrig, damit sie neben
/// den Karten leiser bleibt als deren Inhalt. Die Beschriftung nennt die
/// Aktion woertlich.
class KartoFreieKachel extends StatelessWidget {
  /// Erstellt die Kachel mit [beschriftung].
  const KartoFreieKachel({
    super.key,
    required this.beschriftung,
    required this.symbol,
    required this.onTap,
    this.mindesthoehe = 56,
  });

  /// Aktion, etwa `Person hinzufügen`.
  final String beschriftung;

  /// Symbol vor der Beschriftung.
  final IconData symbol;

  /// Legt einen neuen Eintrag an; `null` sperrt die Kachel.
  final VoidCallback? onTap;

  /// Hoehe, wenn die Zeile sonst keine vorgibt.
  final double mindesthoehe;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final farbe = onTap == null ? karto.schriftStumm : karto.meer;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: mindesthoehe),
      child: KartoFlaeche(
        stufe: KartoFlaechenstufe.senke,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(kKartoRadius),
            child: Padding(
              padding: const EdgeInsets.all(Abstand.block),
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Abstand.knapp,
                  children: [
                    Icon(symbol, size: 20, color: farbe),
                    Text(
                      beschriftung,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.wert
                          .copyWith(color: farbe),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hervortretende Karte mit Tippflaeche ueber die ganze Kante.
class _TippbareKarte extends StatelessWidget {
  const _TippbareKarte({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return KartoFlaeche(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kKartoRadius),
          child: Padding(
            padding: const EdgeInsets.all(Abstand.block),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Ringgefasste Initiale, gefuellt mit der Senke.
///
/// Dieselbe Fassung wie in `KartoHeldenmarke`, nur kleiner und auf hellem
/// Grund: der Ring ist die Konstante, die Figuren als zusammengehoerig zeigt.
class _Siegel extends StatelessWidget {
  const _Siegel({required this.name});

  final String name;

  static const double _groesse = 44;

  String get _initiale {
    final getrimmt = name.trim();
    if (getrimmt.isEmpty) return '?';
    return getrimmt.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    return Container(
      width: _groesse,
      height: _groesse,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: karto.senke,
        border: Border.all(color: karto.grat, width: Strich.grat),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(Abstand.knapp),
      // Grosse Systemschrift darf die Initiale verkleinern, nie den Ring
      // sprengen.
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _initiale,
            style: Theme.of(context).textTheme.titel
                .copyWith(color: karto.schrift, height: 1),
          ),
        ),
      ),
    );
  }
}
