import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/reisebericht_def.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisebericht_rules.dart';

part 'reisebericht_vollstaendigkeit_cases.dart';
part 'reisebericht_belohnungen_cases.dart';
part 'reisebericht_buchung_cases.dart';
part 'reisebericht_kategorien_cases.dart';

void main() {
  _reiseberichtVollstaendigkeit();
  _reiseberichtBelohnungen();
  _reiseberichtBuchung();
  _reiseberichtKategorien();
}
