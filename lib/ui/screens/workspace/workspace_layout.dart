part of 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';

/// Layout-Stufen fuer den Workspace je nach verfuegbarer Breite.
enum WorkspaceLayout {
  /// iPhone / schmales Fenster (< 744dp): TabBar oder Bottom Nav.
  compact,

  /// iPad Portrait / mittelbreit (744-1023dp): Collapsed Sidebar + Content.
  medium,

  /// iPad Landscape / breit (1024-1279dp): Ausgeklappte Sidebar + Content.
  expanded,

  /// Desktop / sehr breit (>= 1280dp): Drei-Spalten Helden-Deck.
  heroDeck,
}

/// Breite der ausgefahrenen Helden-Deck-Navigationsleiste in Pixeln.
const double _heroDeckNavigationWidth = 240;

/// Breite der eingeklappten Helden-Deck-Umschaltleiste in Pixeln.
const double _heroDeckCollapsedWidth = 56;

/// Breite des ausgefahrenen rechten Workspace-Panels in Pixeln.
const double _heroDeckInspectorWidth = 300;

/// Breite der eingeklappten rechten Workspace-Umschaltleiste in Pixeln.
const double _heroDeckInspectorCollapsedWidth = 56;
