import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/hero_trait_effect.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
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
      WorkspaceTabIds.gruppe,
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

  test('Magie-Tab folgt einem umbenannten Vorteil nur über den Katalog '
      '(ARCH-02)', () {
    const umbenannt = HeroTraitDef(
      id: 'adv_astralmacht',
      name: 'Astrale Fülle',
      traitType: 'advantage',
      valueKind: 'points',
      selectionTemplate: 'Astrale Fülle {value}',
      wirkungen: <HeroTraitEffect>[
        HeroTraitEffect(art: HeroTraitEffectArt.basiswert, ziel: 'asp', max: 6),
      ],
    );
    const catalog = RulesCatalog(
      version: 'test',
      source: 'test',
      talents: [],
      spells: [],
      weapons: [],
      advantages: <HeroTraitDef>[umbenannt],
    );
    final held = HeroSheet(
      id: 'astral',
      name: 'Alrike',
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
      vorteileText: 'Astrale Fülle 2',
      vorteilEintraege: const <HeroMerkmal>[
        HeroMerkmal(
          katalogId: 'adv_astralmacht',
          text: 'Astrale Fülle 2',
          wert: 2,
        ),
      ],
    );
    final tabs = buildWorkspaceTabs(
      heroId: 'astral',
      callbacksForTab: (_) => callbacks,
    );

    expect(
      visibleWorkspaceTabsForHero(
        hero: held,
        tabs: tabs,
        catalog: catalog,
      ).map((tab) => tab.id),
      contains(WorkspaceTabIds.magic),
    );
    expect(
      visibleWorkspaceTabsForHero(
        hero: held,
        tabs: tabs,
        catalog: null,
      ).map((tab) => tab.id),
      isNot(contains(WorkspaceTabIds.magic)),
      reason: 'ohne Katalog kennt der Namensweg den neuen Namen nicht',
    );
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
        catalog: null,
      ).map((tab) => tab.id).toList(growable: false),
      isNot(contains(WorkspaceTabIds.magic)),
    );
    expect(
      visibleWorkspaceTabsForHero(
        hero: heroWithAutoMagic,
        tabs: tabs,
        catalog: null,
      ).map((tab) => tab.id),
      contains(WorkspaceTabIds.magic),
    );
    expect(
      visibleWorkspaceTabsForHero(
        hero: heroWithManualDisable,
        tabs: tabs,
        catalog: null,
      ).map((tab) => tab.id),
      isNot(contains(WorkspaceTabIds.magic)),
    );
    expect(
      visibleWorkspaceTabsForHero(
        hero: heroWithManualEnable,
        tabs: tabs,
        catalog: null,
      ).map((tab) => tab.id),
      contains(WorkspaceTabIds.magic),
    );
  });
}

void _noopBool(bool value) {}

void _noopDiscard(WorkspaceAsyncAction action) {}

void _noopEditActions(WorkspaceTabEditActions actions) {}
