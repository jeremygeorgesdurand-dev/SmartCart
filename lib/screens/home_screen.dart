import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../services/widget_service.dart';
import '../widgets/background_logo.dart';
import 'budget_screen.dart';
import 'catalogue_screen.dart';
import 'listes_screen.dart';
import 'parametres_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Le widget écran d'accueil ouvre l'app avec l'id de la liste tapée
    // (tap sur le nom/l'en-tête) via un extra d'intent : sans ce pont, on
    // atterrissait juste sur le dernier écran affiché, pas sur la liste
    // choisie.
    WidgetService.ecouterIntents((_, listeId, __) => _ouvrirListe(listeId));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final intent = await WidgetService.getWidgetIntent();
      final listeId = intent['liste_id'] ?? '';
      if (listeId.isNotEmpty) _ouvrirListe(listeId);
    });
  }

  Future<void> _ouvrirListe(String listeId) async {
    if (listeId.isEmpty) return;
    final listes = await ref.read(listesNotifierProvider.future);
    final liste = listes.where((l) => l.id == listeId).firstOrNull;
    if (liste != null && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DetailListeScreen(liste: liste)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Démarre la synchro temps réel avec Firestore pour toute la durée
    // de vie de l'app (voir realtimeSyncProvider).
    ref.watch(realtimeSyncProvider);

    final afficherStats = ref.watch(afficherStatsProvider);
    final afficherBudget = ref.watch(afficherBudgetProvider);
    final fondActif = ref.watch(fondActiveProvider);
    final fondOpacite = ref.watch(fondOpaciteProvider);

    final screens = [
      const ListesScreen(),
      const CatalogueScreen(),
      if (afficherBudget) const BudgetScreen(),
      if (afficherStats) const StatsScreen(),
      const ParametresScreen(),
    ];

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.shopping_cart_outlined),
        selectedIcon: Icon(Icons.shopping_cart),
        label: 'Mes listes',
      ),
      const NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: 'Catalogue',
      ),
      if (afficherBudget)
        const NavigationDestination(
          icon: Icon(Icons.euro_outlined),
          selectedIcon: Icon(Icons.euro),
          label: 'Budget',
        ),
      if (afficherStats)
        const NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: 'Stats',
        ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Paramètres',
      ),
    ];

    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: Stack(
        children: [
          // Contenu principal (en dessous)
          IndexedStack(
            index: safeIndex,
            children: screens,
          ),
          // Logo de fond — par dessus, non interactif
          if (fondActif)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: fondOpacite,
                  child: Center(
                    child: Image.asset(
                      'assets/background_icon.png',
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: destinations,
      ),
    );
  }
}
