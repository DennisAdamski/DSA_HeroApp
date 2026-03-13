import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

void main() {
  const callbacks = WorkspaceTabCallbacks(
    onDirtyChanged: _noopBool,
    onEditingChanged: _noopBool,
    onRegisterDiscard: _noopDiscard,
    onRegisterEditActions: _noopEditActions,
  );

  test('buildWorkspaceTabs exposes stable tab ids in registry order', () {
    final tabs = buildWorkspaceTabs(
      heroId: 'demo',
      callbacksForTab: (_) => callbacks,
    );

    expect(tabs.map((tab) => tab.id).toList(growable: false), <String>[
      WorkspaceTabIds.overview,
      WorkspaceTabIds.talents,
      WorkspaceTabIds.combat,
      WorkspaceTabIds.magic,
      WorkspaceTabIds.inventory,
      WorkspaceTabIds.notes,
      WorkspaceTabIds.begleiter,
    ]);
  });

  test('visibleWorkspaceTabsForHero filters hidden tabs and keeps order', () {
    final heroWithoutMagic = HeroSheet(
      id: 'mundane',
      name: 'Alrik',
      level: 1,
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      ),
    );
    final heroWithMagic = heroWithoutMagic.copyWith(
      spells: const <String, HeroSpellEntry>{
        'spell_axxeleratus': HeroSpellEntry(spellValue: 8),
      },
    );
    final tabs = <WorkspaceTabSpec>[
      WorkspaceTabSpec(
        id: 'overview',
        label: 'Uebersicht',
        icon: Icons.looks_one_outlined,
        helper: 'Immer sichtbar',
        buildContent: ({required heroId, required callbacks}) =>
            const SizedBox.shrink(),
      ),
      WorkspaceTabSpec(
        id: 'magic',
        label: 'Magie',
        icon: Icons.looks_two_outlined,
        helper: 'Nur fuer magische Helden',
        isVisible: (hero) => hero.spells.isNotEmpty,
        buildContent: ({required heroId, required callbacks}) =>
            const SizedBox.shrink(),
      ),
      WorkspaceTabSpec(
        id: 'notes',
        label: 'Notizen',
        icon: Icons.looks_3_outlined,
        helper: 'Immer sichtbar',
        buildContent: ({required heroId, required callbacks}) =>
            const SizedBox.shrink(),
      ),
    ];

    expect(
      visibleWorkspaceTabsForHero(
        hero: heroWithoutMagic,
        tabs: tabs,
      ).map((tab) => tab.id).toList(growable: false),
      <String>['overview', 'notes'],
    );
    expect(
      visibleWorkspaceTabsForHero(
        hero: heroWithMagic,
        tabs: tabs,
      ).map((tab) => tab.id).toList(growable: false),
      <String>['overview', 'magic', 'notes'],
    );
  });
}

void _noopBool(bool value) {}

void _noopDiscard(WorkspaceAsyncAction action) {}

void _noopEditActions(WorkspaceTabEditActions actions) {}
