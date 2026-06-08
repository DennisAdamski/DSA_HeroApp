import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Erwartet fuer ListTile-Familienwidgets einen lokalen Material-Layer vor farbigen Panels.
void expectListTileFamilyWidgetHasLocalMaterial(
  WidgetTester tester,
  Finder finder,
) {
  expect(finder, findsOneWidget);

  final blockingAncestors = <Widget>[];
  var foundMaterial = false;
  final element = tester.element(finder);

  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Material) {
      foundMaterial = true;
      return false;
    }
    if (_paintsBackground(widget)) {
      blockingAncestors.add(widget);
    }
    return true;
  });

  expect(
    foundMaterial,
    isTrue,
    reason: 'ListTile-Familienwidgets benoetigen einen lokalen Material-Layer.',
  );
  expect(
    blockingAncestors,
    isEmpty,
    reason:
        'Farbige Panels duerfen Ink- und Tile-Hintergruende nicht verdecken.',
  );
}

bool _paintsBackground(Widget widget) {
  if (widget is ColoredBox) {
    return true;
  }

  if (widget is DecoratedBox) {
    final decoration = widget.decoration;
    if (decoration is BoxDecoration) {
      return decoration.color != null || decoration.gradient != null;
    }
  }

  return false;
}
