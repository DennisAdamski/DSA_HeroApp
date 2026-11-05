part of 'combat_rules_test.dart';

void _combatNebenhand() {
  // ---------------------------------------------------------------------------
  // OffhandCombatPreview
  // ---------------------------------------------------------------------------

  group('OffhandCombatPreview', () {
    test('keine Nebenhand -> offhandPreview ist null', () {
      final sheet = hero(
        combatConfig: const CombatConfig(
          weapons: <MainWeaponSlot>[
            MainWeaponSlot(name: 'Schwert', kkBase: 12, kkThreshold: 4),
          ],
          selectedWeaponIndex: 0,
        ),
      );
      final result = preview(sheet);
      expect(result.offhandPreview, isNull);
    });

    test('Zweihandwaffe -> offhandPreview ist null', () {
      final sheet = hero(
        combatConfig: const CombatConfig(
          weapons: <MainWeaponSlot>[
            MainWeaponSlot(
              name: 'Zweihaender',
              isOneHanded: false,
              kkBase: 12,
              kkThreshold: 4,
            ),
          ],
          selectedWeaponIndex: 0,
        ),
      );
      final result = preview(sheet);
      expect(result.offhandPreview, isNull);
    });

    test('Einhandwaffe + zweite Einhandwaffe -> volle Nebenhand-Werte', () {
      final sheet = hero(
        combatConfig: CombatConfig(
          weapons: const <MainWeaponSlot>[
            MainWeaponSlot(
              name: 'Schwert',
              kkBase: 12,
              kkThreshold: 4,
              tpFlat: 3,
            ),
            MainWeaponSlot(
              name: 'Dolch',
              kkBase: 10,
              kkThreshold: 3,
              tpFlat: 1,
            ),
          ],
          selectedWeaponIndex: 0,
          offhandAssignment: const OffhandAssignment(weaponIndex: 1),
        ),
      );
      final result = preview(sheet);
      expect(result.offhandPreview, isNotNull);
      expect(result.offhandPreview!.isWeapon, isTrue);
      expect(result.offhandPreview!.displayName, 'Dolch');
      expect(result.offhandPreview!.at, isNotNull);
      expect(result.offhandPreview!.pa, isNotNull);
      expect(result.offhandPreview!.tpExpression, isNotNull);
      expect(result.offhandPreview!.ebe, isNotNull);
      expect(result.offhandPreview!.isRangedWeapon, isFalse);
    });

    test('Einhandwaffe + Schild -> Nebenhand-Schild-PA', () {
      final sheet = hero(
        combatConfig: CombatConfig(
          weapons: const <MainWeaponSlot>[
            MainWeaponSlot(name: 'Schwert', kkBase: 12, kkThreshold: 4),
          ],
          selectedWeaponIndex: 0,
          offhandEquipment: const <OffhandEquipmentEntry>[
            OffhandEquipmentEntry(
              name: 'Rundschild',
              type: OffhandEquipmentType.shield,
              paMod: 2,
            ),
          ],
          offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
        ),
      );
      final result = preview(sheet);
      expect(result.offhandPreview, isNotNull);
      expect(result.offhandPreview!.isShield, isTrue);
      expect(result.offhandPreview!.isWeapon, isFalse);
      expect(result.offhandPreview!.shieldPa, isNotNull);
      expect(result.offhandPreview!.displayName, 'Rundschild');
      // Schild hat keine eigene AT/TP
      expect(result.offhandPreview!.at, isNull);
      expect(result.offhandPreview!.tpExpression, isNull);
    });

    test('Einhandwaffe + Parierwaffe -> PA-Mod und Linkhand-Warnung', () {
      final sheet = hero(
        combatConfig: CombatConfig(
          weapons: const <MainWeaponSlot>[
            MainWeaponSlot(name: 'Schwert', kkBase: 12, kkThreshold: 4),
          ],
          selectedWeaponIndex: 0,
          offhandEquipment: const <OffhandEquipmentEntry>[
            OffhandEquipmentEntry(
              name: 'Linkhand',
              type: OffhandEquipmentType.parryWeapon,
              paMod: -4,
            ),
          ],
          offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
        ),
      );
      final result = preview(sheet);
      expect(result.offhandPreview, isNotNull);
      expect(result.offhandPreview!.isParryWeapon, isTrue);
      expect(result.offhandPreview!.isWeapon, isFalse);
      // Ohne Linkhand-SF -> Warnung
      expect(result.offhandPreview!.requiresLinkhandViolation, isTrue);
    });

    test('INI-Maximum aus beiden Haenden', () {
      // Nebenhand mit hoeherem INI-Mod
      final sheet = hero(
        combatConfig: CombatConfig(
          weapons: const <MainWeaponSlot>[
            MainWeaponSlot(
              name: 'Schwert',
              kkBase: 12,
              kkThreshold: 4,
              iniMod: -1,
            ),
            MainWeaponSlot(
              name: 'Dolch',
              kkBase: 10,
              kkThreshold: 3,
              iniMod: 2,
            ),
          ],
          selectedWeaponIndex: 0,
          offhandAssignment: const OffhandAssignment(weaponIndex: 1),
        ),
      );
      final result = preview(sheet);
      // kampfInitiative nutzt das Maximum beider Waffen-INIs
      expect(result.offhandWeaponInitiative, isNotNull);
      expect(
        result.kampfInitiative,
        greaterThanOrEqualTo(result.kombinierteHeldenWaffenIni),
      );
    });

    test('eBE divergiert bei verschiedenen Talenten', () {
      const talentSchwert = TalentDef(
        id: 'tal_schwert',
        name: 'Schwerter',
        group: 'Kampftalent',
        steigerung: 'D',
        attributes: <String>['GE', 'GE', 'KK'],
        be: '-2',
      );
      const talentDolch = TalentDef(
        id: 'tal_dolch',
        name: 'Dolche',
        group: 'Kampftalent',
        steigerung: 'C',
        attributes: <String>['GE', 'FF', 'KK'],
        be: '-',
      );
      final sheet = hero(
        combatConfig: CombatConfig(
          weapons: const <MainWeaponSlot>[
            MainWeaponSlot(
              name: 'Schwert',
              talentId: 'tal_schwert',
              kkBase: 12,
              kkThreshold: 4,
            ),
            MainWeaponSlot(
              name: 'Dolch',
              talentId: 'tal_dolch',
              kkBase: 10,
              kkThreshold: 3,
            ),
          ],
          selectedWeaponIndex: 0,
          offhandAssignment: const OffhandAssignment(weaponIndex: 1),
          armor: const ArmorConfig(
            pieces: <ArmorPiece>[
              ArmorPiece(name: 'Leder', rs: 2, be: 3, isActive: true),
            ],
          ),
        ),
      );
      final result = preview(
        sheet,
        catalogTalents: <TalentDef>[talentSchwert, talentDolch],
      );
      // Hauptwaffe Schwert hat BE-Mod -2, Nebenhand Dolch hat BE-Mod 0
      // -> verschiedene eBE-Werte
      expect(result.ebe, isNot(equals(result.offhandPreview!.ebe)));
    });

    test('Fernkampf-Nebenhand hat Ladezeit und Distanz', () {
      final sheet = hero(
        combatConfig: CombatConfig(
          weapons: const <MainWeaponSlot>[
            MainWeaponSlot(name: 'Schwert', kkBase: 12, kkThreshold: 4),
            MainWeaponSlot(
              name: 'Wurfmesser',
              combatType: WeaponCombatType.ranged,
              kkBase: 10,
              kkThreshold: 3,
              tpFlat: 1,
            ),
          ],
          selectedWeaponIndex: 0,
          offhandAssignment: const OffhandAssignment(weaponIndex: 1),
        ),
      );
      final result = preview(sheet);
      expect(result.offhandPreview, isNotNull);
      expect(result.offhandPreview!.isWeapon, isTrue);
      expect(result.offhandPreview!.isRangedWeapon, isTrue);
      // Hauptwaffe ist Nahkampf
      expect(result.isRangedWeapon, isFalse);
    });
  });
}
