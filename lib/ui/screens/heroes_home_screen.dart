import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';

class HeroesHomeScreen extends ConsumerWidget {
  const HeroesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroesAsync = ref.watch(heroListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('DSA Helden')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final navigator = Navigator.of(context);
          final id = await ref.read(heroActionsProvider).createHero();
          if (!context.mounted) {
            return;
          }
          navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => HeroWorkspaceScreen(heroId: id)),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Neuer Held'),
      ),
      body: heroesAsync.when(
        data: (heroes) {
          if (heroes.isEmpty) {
            return const Center(
              child: Text('Noch keine Helden angelegt. Erstelle deinen ersten Helden.'),
            );
          }

          return ListView.separated(
            itemCount: heroes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final hero = heroes[index];
              return ListTile(
                title: Text(hero.name),
                subtitle: Text('Level ${hero.level}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ref.read(selectedHeroIdProvider.notifier).state = hero.id;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => HeroWorkspaceScreen(heroId: hero.id)),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
      ),
    );
  }
}
