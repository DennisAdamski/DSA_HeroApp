import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/app_build_info.dart';

void main() {
  test('ohne Commit gilt der Build als lokaler Entwicklungsstand', () {
    expect(const AppBuildInfo().anzeige, 'Lokaler Entwicklungsstand');
  });

  test('kürzt den Commit auf sieben Zeichen und behält einen Zusatz', () {
    const info = AppBuildInfo(
      commit: 'e92ff9f0123456789abcdef0123456789abcdef0-dirty',
    );
    expect(info.kurzerCommit, 'e92ff9f-dirty');
    expect(info.anzeige, 'e92ff9f-dirty');
  });

  test('zeigt die Bauzeit in lokaler Zeit', () {
    const zeit = '2026-10-05T14:32:07Z';
    final lokal = DateTime.parse(zeit).toLocal();
    String zwei(int wert) => wert.toString().padLeft(2, '0');

    expect(
      const AppBuildInfo(commit: 'e92ff9f0123', zeit: zeit).anzeige,
      'e92ff9f · ${zwei(lokal.day)}.${zwei(lokal.month)}.${lokal.year} '
      '${zwei(lokal.hour)}:${zwei(lokal.minute)}',
    );
  });

  test('eine unlesbare Bauzeit lässt nur den Commit stehen', () {
    expect(
      const AppBuildInfo(commit: 'abc1234', zeit: 'gestern').anzeige,
      'abc1234',
    );
  });
}
