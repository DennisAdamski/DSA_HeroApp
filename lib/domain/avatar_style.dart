/// Stilvorlagen fuer die KI-Bildgenerierung.
enum AvatarStyle {
  fantasyIllustration(
    'Fantasy-Illustration',
    'detailed fantasy book illustration, rich colors, dramatic lighting',
  ),
  realisticOil(
    'Realistische Oelmalerei',
    'realistic oil painting, detailed brushwork, rich colors, '
        'classical portrait style',
  ),
  watercolor(
    'Aquarell',
    'watercolor painting, soft edges, atmospheric, delicate colors',
  ),
  penAndInk(
    'Tusche-Zeichnung',
    'detailed pen and ink drawing, fine line art, cross-hatching',
  ),
  medievalPortrait(
    'Mittelalterliches Portraet',
    'medieval portrait painting, illuminated manuscript style, '
        'gold leaf accents',
  );

  const AvatarStyle(this.displayName, this.promptFragment);

  final String displayName;

  /// Englischer Prompt-Baustein fuer den jeweiligen Stil.
  final String promptFragment;
}
