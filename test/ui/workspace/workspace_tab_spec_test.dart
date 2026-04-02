import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
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
      WorkspaceTabIds.reisebericht,
      WorkspaceTabIds.begleiter,
    ]);
  });

  test('notes workspace tab exposes adventure-focused label and helper', () {
    final tabs = buildWorkspaceTabs(
      heroId: 'demo',
      callbacksForTab: (_) => callbacks,
    );
    final notesTab = tabs.firstWhere((tab) => tab.id == WorkspaceTabIds.notes);

    expect(notesTab.label, 'Chroniken, Kontakte & Abenteuer');
    expect(notesTab.helper, contains('Abenteuer'));
  });

  test('magic workspace tab follows effective resource activation', () {
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
    final heroWithAutoMagic = heroWithoutMagic.copyWith(vorteileText: 'AE+2');
    final heroWithManualDisable = heroWithAutoMagic.copyWith(
      resourceActivationConfig: const HeroResourceActivationConfig(
        magicEnabledOverride: false,
      ),
    );
    final heroWithManualEnable = heroWithoutMagic.copyWith(
      resourceActivationConfig: const HeroResourceActivationConfig(
        magicEnabledOverride: true,
      ),
    );
    final tabs = buildWorkspaceTabs(
      heroId: 'demo',
      callbacksForTab: (_) => callbacks,
    );

    expect(
      visibleWorkspaceTabsForHero(
        hero: heroWithoutMagic,
        tabs: tabs,
      ).map((tab) => tab.id).toList(growable: false),
      isNot(contains(WorkspaceTabIds.magic)),
    );
    expect(
      visibleWorkspaceTabsForHero(
        hero: heroWithAutoMagic,
        tabs: tabs,
      ).map((tab) => tab.id),
      contains(WorkspaceTabIds.magic),
    );
    expect(
      visibleWorkspaceTabsForHero(
        hero: heroWithManualDisable,
        tabs: tabs,
      ).map((tab) => tab.id),
      isNot(contains(WorkspaceTabIds.magic)),
    );
    expect(
      visibleWorkspaceTabsForHero(
        hero: heroWithManualEnable,
        tabs: tabs,
      ).map((tab) => tab.id),
      contains(WorkspaceTabIds.magic),
    );
  });
}

void _noopBool(bool value) {}

void _noopDiscard(WorkspaceAsyncAction action) {}

void _noopEditActions(WorkspaceTabEditActions actions) {}
