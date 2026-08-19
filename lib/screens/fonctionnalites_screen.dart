import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/providers.dart';

// ================================================================
// ÉCRAN FONCTIONNALITÉS — quels onglets afficher dans la navigation
// ================================================================
class FonctionnalitesScreen extends ConsumerWidget {
  const FonctionnalitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final afficherBudget = ref.watch(afficherBudgetProvider);
    final afficherPrix = ref.watch(afficherPrixProvider);
    final afficherRecettes = ref.watch(afficherRecettesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fonctionnalités')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Afficher le budget'),
            subtitle: const Text(
                'Onglet Budget (avec les statistiques) dans la navigation'),
            value: afficherBudget,
            onChanged: (v) async {
              ref.read(afficherBudgetProvider.notifier).state = v;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('afficher_budget', v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Afficher les recettes'),
            subtitle: const Text('Onglet Recettes dans la navigation'),
            value: afficherRecettes,
            onChanged: (v) async {
              ref.read(afficherRecettesProvider.notifier).state = v;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('afficher_recettes', v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Afficher les prix'),
            subtitle: const Text(
                'Prix des articles dans les listes et le catalogue'),
            value: afficherPrix,
            onChanged: (v) async {
              ref.read(afficherPrixProvider.notifier).state = v;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('afficher_prix', v);
            },
          ),
        ],
      ),
    );
  }
}
