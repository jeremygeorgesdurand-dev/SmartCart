import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // Le widget écran d'accueil ouvre l'app en lui passant une action
    // (cocher un article, en ajouter un) via des extras d'intent — sans ce
    // pont, l'app s'ouvrait juste sur son dernier écran sans rien faire de
    // l'action demandée, ce qui donnait l'impression que le widget "ouvre
    // juste l'app" pour rien.
    WidgetService.ecouterIntents(_gererIntentWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final intent = await WidgetService.getWidgetIntent();
      final action = intent['action'] ?? '';
      if (action.isNotEmpty) {
        _gererIntentWidget(
            action, intent['liste_id'] ?? '', intent['article_liste_id'] ?? '');
      }
    });
  }

  Future<void> _gererIntentWidget(
      String action, String listeId, String articleListeId) async {
    if (listeId.isEmpty) return;

    if (action == 'cocher_article' && articleListeId.isNotEmpty) {
      final items = await ref.read(dbServiceProvider).getArticlesListe(listeId);
      final item = items.where((i) => i.id == articleListeId).firstOrNull;
      if (item != null) {
        await ref
            .read(articlesListeProvider(listeId).notifier)
            .cocher(item, !item.coche);
      }
      // On ne veut pas que cocher un article depuis le widget prenne toute
      // la place de l'app au premier plan : retour direct à l'écran
      // d'accueil du téléphone une fois l'action effectuée.
      SystemNavigator.pop();
    } else if (action == 'add_article') {
      final listes = await ref.read(listesNotifierProvider.future);
      final liste = listes.where((l) => l.id == listeId).firstOrNull;
      if (liste != null && mounted) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DetailListeScreen(liste: liste)));
      }
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
