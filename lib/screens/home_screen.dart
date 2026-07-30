import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../services/widget_service.dart';
import '../widgets/background_logo.dart';
import 'budget_screen.dart';
import 'catalogue_screen.dart';
import 'listes_screen.dart';
import 'parametres_screen.dart';
import 'recettes_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Le "+" du widget écran d'accueil écrit un article/liste directement en
    // SQLite depuis du code natif (QuickAddActivity), sans jamais passer par
    // le moteur Flutter : les providers Riverpod (catalogue, articles d'une
    // liste) ne le savent pas et continuent de servir leurs données mises en
    // cache depuis avant la mise en arrière-plan. Sans invalidation ici, un
    // article ajouté par le widget peut être compté (une liste jamais visitée
    // depuis reconstruit son provider à jour) mais rester invisible dans le
    // détail de la liste (dont le provider catalogue était déjà construit,
    // donc périmé). Invalider au retour au premier plan force une relecture
    // fraîche de la base dans tous les cas.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(articlesNotifierProvider);
      ref.invalidate(listesNotifierProvider);
      ref.invalidate(articlesListeProvider);
    }
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
    final afficherRecettes = ref.watch(afficherRecettesProvider);
    final fondActif = ref.watch(fondActiveProvider);
    final fondOpacite = ref.watch(fondOpaciteProvider);

    final screens = [
      const ListesScreen(),
      const CatalogueScreen(),
      if (afficherRecettes) const RecettesScreen(),
      if (afficherBudget) const BudgetScreen(),
      if (afficherStats) const StatsScreen(),
      const ParametresScreen(),
    ];

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.shopping_cart_outlined),
        selectedIcon: Icon(Icons.shopping_cart),
        label: 'Listes',
      ),
      const NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: 'Catalogue',
      ),
      if (afficherRecettes)
        const NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Recettes',
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
        label: 'Réglages',
      ),
    ];

    final safeIndex = _currentIndex.clamp(0, screens.length - 1);
    // L'onglet Recettes (quand affiché) est à l'index 2 et possède son
    // propre TabBar horizontal : on désactive le glissement inter-onglets
    // principal quand on est dessus, sinon les deux gestes horizontaux
    // s'annulent.
    final indexRecettes = afficherRecettes ? 2 : -1;

    void changerDePage(int index) {
      final cible = index.clamp(0, screens.length - 1);
      if (cible == _currentIndex) return;
      setState(() => _currentIndex = cible);
      _pageController.animateToPage(
        cible,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Contenu principal (en dessous) — PageView plutôt qu'IndexedStack
          // pour permettre de changer d'onglet en glissant n'importe où, en
          // plus des boutons de la barre de navigation. Le conflit avec la
          // suppression par glissement des articles du Catalogue est réglé
          // côté ArticleTile (zone de déclenchement limitée à la flèche),
          // pas ici.
          PageView(
            controller: _pageController,
            physics: safeIndex == indexRecettes
                ? const NeverScrollableScrollPhysics()
                : null,
            onPageChanged: (i) => setState(() => _currentIndex = i),
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
        onDestinationSelected: changerDePage,
        destinations: destinations,
      ),
    );
  }
}
