import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Plattform-Erkennung (testbar ueber Theme.of, kein dart:io)
// ---------------------------------------------------------------------------

/// Prueft ob die aktuelle Plattform iOS oder macOS ist.
bool isApplePlatform(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS ||
      platform == TargetPlatform.macOS;
}

// ---------------------------------------------------------------------------
// Breakpoint-Konstanten
// ---------------------------------------------------------------------------

/// iPhone und kleine Fenster.
const double kCompactBreakpoint = 600;

/// iPad Mini Portrait.
const double kMediumBreakpoint = 744;

/// iPad Landscape / kleiner Desktop — Sidebar ausgeklappt.
const double kTabletBreakpoint = 1024;

/// Vollstaendiges Helden-Deck (drei Spalten).
const double kHeroDeckBreakpoint = 1280;

// ---------------------------------------------------------------------------
// Adaptive Touch-Targets (Apple HIG: min 44pt)
// ---------------------------------------------------------------------------

/// Minimale Touch-Target-Groesse: 44dp auf Apple, 28dp sonst.
double adaptiveMinTouchTarget(BuildContext context) =>
    isApplePlatform(context) ? 44.0 : 28.0;

/// MaterialTapTargetSize: padded auf Apple, shrinkWrap sonst.
MaterialTapTargetSize adaptiveTapTargetSize(BuildContext context) =>
    isApplePlatform(context)
        ? MaterialTapTargetSize.padded
        : MaterialTapTargetSize.shrinkWrap;

// ---------------------------------------------------------------------------
// Adaptive Scroll-Physik
// ---------------------------------------------------------------------------

/// BouncingScrollPhysics auf Apple, ClampingScrollPhysics sonst.
ScrollPhysics adaptiveScrollPhysics(BuildContext context) =>
    isApplePlatform(context)
        ? const BouncingScrollPhysics()
        : const ClampingScrollPhysics();
