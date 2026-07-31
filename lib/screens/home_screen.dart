import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../services/widget_service.dart';
import '../widgets/background_logo.dart';
import 'budget_screen.dart';
import 'catalogue_screen.dart';
import 'frigo_screen.dart';
import 'listes_screen.dart';
import 'parametres_screen.dart';
import 'recettes_en_ligne_screen.dart';
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

    void allerAFlat(int i) {
      if (i == _currentIndex) return;
      setState(() => _currentIndex = i);
      _pageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Recettes est composé de 3 sous-onglets. Plutôt que de les imbriquer
    // dans un TabBarView (dont le glissement entrait en conflit avec le
    // glissement principal), on les met À PLAT : chaque sous-onglet est une
    // page consécutive du défilement principal. Ainsi glisser sur Recettes
    // fait défiler Explorer → Frigo → Mes recettes, puis continue vers
    // l'écran voisin — comme partout ailleurs. Listes(0) + Catalogue(1)
    // étant toujours présents, la 1re page Recettes est à l'index 2.
    const recettesDebut = 2;
    Widget pageRecette(int sousIndex) {
      const contenus = [
        ExplorerRecettesTab(),
        FrigoTab(),
        MesRecettesTab(),
      ];
      return Scaffold(
        appBar: AppBar(
          title: const Text('Recettes'),
          bottom: EnTeteSousOngletsRecettes(
            actif: sousIndex,
            onTap: (i) => allerAFlat(recettesDebut + i),
          ),
        ),
        floatingActionButton: sousIndex == 2
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecetteFormScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle recette'),
              )
            : null,
        body: contenus[sousIndex],
      );
    }

    // Chaque "section" = une entrée de la barre de navigation + ses pages
    // (Recettes en a 3, les autres une seule).
    final sections = <({NavigationDestination dest, List<Widget> pages})>[
      (
        dest: const NavigationDestination(
          icon: Icon(Icons.shopping_cart_outlined),
          selectedIcon: Icon(Icons.shopping_cart),
          label: 'Listes',
        ),
        pages: [const ListesScreen()],
      ),
      (
        dest: const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Catalogue',
        ),
        pages: [const CatalogueScreen()],
      ),
      if (afficherRecettes)
        (
          dest: const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Recettes',
          ),
          pages: [pageRecette(0), pageRecette(1), pageRecette(2)],
        ),
      if (afficherBudget)
        (
          dest: const NavigationDestination(
            icon: Icon(Icons.euro_outlined),
            selectedIcon: Icon(Icons.euro),
            label: 'Budget',
          ),
          pages: [const BudgetScreen()],
        ),
      if (afficherStats)
        (
          dest: const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          pages: [const StatsScreen()],
        ),
      (
        dest: const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Réglages',
        ),
        pages: [const ParametresScreen()],
      ),
    ];

    // Aplatissement : liste de toutes les pages + pour chacune la section
    // (donc l'onglet de barre) à laquelle elle appartient, et l'index de la
    // 1re page de chaque section (cible d'un tap sur la barre).
    final flatPages = <Widget>[];
    final navDePage = <int>[];
    final debutDeNav = <int>[];
    for (var s = 0; s < sections.length; s++) {
      debutDeNav.add(flatPages.length);
      for (final p in sections[s].pages) {
        navDePage.add(s);
        flatPages.add(p);
      }
    }
    final destinations = [for (final s in sections) s.dest];
    final safeFlat = _currentIndex.clamp(0, flatPages.length - 1);

    return Scaffold(
      body: Stack(
        children: [
          // Défilement principal à plat : glisser change de page (y compris
          // entre les sous-onglets Recettes) ; la barre du bas permet aussi
          // de sauter directement à une section.
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            children: flatPages,
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
        selectedIndex: navDePage[safeFlat],
        onDestinationSelected: (navIndex) => allerAFlat(debutDeNav[navIndex]),
        destinations: destinations,
      ),
    );
  }
}
