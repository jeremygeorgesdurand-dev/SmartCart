import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/article_tile.dart';
import '../widgets/prix_article_badge.dart';
import '../widgets/ajouter_article_dialog.dart' show AjouterArticleDialog, AjoutRapideDialog;
import '../widgets/filtres_bar.dart';
import '../widgets/vocal_button.dart';
import '../widgets/animated_list_item.dart';
import 'scanner_screen.dart';
import '../widgets/import_liste_dialog.dart' show ImportListeDialog, ExportDialog;
import 'doublons_screen.dart';

class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({super.key});

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  final _searchController = TextEditingController();
  bool _searchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _ouvrirVocal() {
    ouvrirVocal(context);
  }

  Future<void> _ajouterSelectionAListe() async {
    final liste = ref.read(listeSelectionneeProvider);
    final selection = ref.read(articlesSelectionnesProvider);
    if (liste == null || selection.isEmpty) return;

    final catalogue = ref.read(articlesNotifierProvider).valueOrNull ?? [];
    int nbAjoutes = 0;

    // Charger une seule fois les articles déjà dans la liste
    final itemsExistants = await ref.read(dbServiceProvider).getArticlesListe(liste.id);
    final idsDejaPresents = itemsExistants.map((i) => i.articleId).toSet();

    for (final articleId in selection) {
      final article = catalogue.where((a) => a.id == articleId).firstOrNull;
      if (article == null) continue;
      // Vérification dans le Set (inclut les ajouts de cette session)
      if (idsDejaPresents.contains(articleId)) continue;
      await ref.read(articlesListeProvider(liste.id).notifier).ajouter(
            ArticleListe(
              id: 'al_${const Uuid().v4()}',
              listeId: liste.id,
              articleId: articleId,
            ),
          );
      idsDejaPresents.add(articleId); // éviter doublons dans la même sélection
      nbAjoutes++;
    }

    // Une fois l'ajout fait, on quitte complètement le mode sélection
    // (sinon la liste reste sélectionnée et le catalogue reste affiché en
    // mode "cocher des articles", ce qui prête à confusion).
    ref.read(articlesSelectionnesProvider.notifier).state = {};
    ref.read(listeSelectionneeProvider.notifier).state = null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          nbAjoutes == 0
              ? 'Articles déjà présents dans la liste'
              : '$nbAjoutes article(s) ajouté(s) à "${liste.nom}"',
        ),
        backgroundColor: nbAjoutes > 0 ? Colors.green : null,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(articlesFiltresProvider);
    final listesAsync = ref.watch(listesNotifierProvider);
    final listeSelectionnee = ref.watch(listeSelectionneeProvider);
    final selection = ref.watch(articlesSelectionnesProvider);
    final sort = ref.watch(sortModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).state = v,
              )
            : const Text('Catalogue'),
        actions: [
          // Recherche
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            tooltip: _searchVisible ? 'Fermer la recherche' : 'Rechercher',
            onPressed: () {
              setState(() => _searchVisible = !_searchVisible);
              if (!_searchVisible) {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              }
            },
          ),
          // Vocal
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Saisie vocale',
            onPressed: _ouvrirVocal,
          ),
          // Scanner
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scanner un code-barres',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScannerScreen())),
          ),
          // Menu
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'tri_alpha':
                  ref.read(sortModeProvider.notifier).state =
                      SortMode.alphabetique;
                case 'tri_cat':
                  ref.read(sortModeProvider.notifier).state =
                      SortMode.categorie;
                case 'tri_rayon':
                  ref.read(sortModeProvider.notifier).state = SortMode.rayon;
                case 'exporter':
                  showDialog(
                      context: context,
                      builder: (_) => const ExportDialog());
                case 'importer':
                  showDialog(
                      context: context,
                      builder: (_) => const ImportListeDialog());
                case 'doublons':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DoublonsScreen()));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'tri_alpha',
                  child: Row(children: [
                    Icon(Icons.sort_by_alpha, size: 18),
                    SizedBox(width: 10),
                    Text('A → Z')
                  ])),
              const PopupMenuItem(
                  value: 'tri_cat',
                  child: Row(children: [
                    Icon(Icons.home_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Par catégorie')
                  ])),
              const PopupMenuItem(
                  value: 'tri_rayon',
                  child: Row(children: [
                    Icon(Icons.store_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Par rayon')
                  ])),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'exporter',
                  child: Row(children: [
                    Icon(Icons.download, size: 18),
                    SizedBox(width: 10),
                    Text('Exporter le catalogue')
                  ])),
              const PopupMenuItem(
                  value: 'importer',
                  child: Row(children: [
                    Icon(Icons.upload_file, size: 18),
                    SizedBox(width: 10),
                    Text('Importer des articles')
                  ])),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'doublons',
                  child: Row(children: [
                    const Icon(Icons.content_copy, size: 18),
                    const SizedBox(width: 10),
                    const Text('Détecter les doublons'),
                    if (ref.watch(doublonsProvider).isNotEmpty) ...[
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.orange,
                        child: Text(
                          '${ref.watch(doublonsProvider).length}',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Sélecteur de liste ────────────────────────────────
          listesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (listes) {
              if (listes.isEmpty) return const SizedBox.shrink();
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: listeSelectionnee != null
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.5)
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      listeSelectionnee != null
                          ? Icons.shopping_cart
                          : Icons.shopping_cart_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ListeCourses?>(
                          value: listeSelectionnee,
                          isDense: true,
                          // Explicite plutôt que de compter sur la petite
                          // flèche grise par défaut (facile à manquer) :
                          // signale clairement qu'on peut dérouler un menu.
                          // La liste déroulée défile déjà automatiquement
                          // si elle dépasse la hauteur de l'écran (comportement
                          // natif de DropdownButton, rien à faire de plus).
                          icon: Icon(Icons.expand_more,
                              color: Theme.of(context).colorScheme.primary),
                          hint: Text(
                            'Ajouter à une liste...',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 13,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text('Aucune liste sélectionnée')),
                            ...listes.map((l) =>
                                DropdownMenuItem(value: l, child: Text(l.nom))),
                          ],
                          onChanged: (l) {
                            ref.read(listeSelectionneeProvider.notifier).state =
                                l;
                            ref
                                .read(articlesSelectionnesProvider.notifier)
                                .state = {};
                          },
                        ),
                      ),
                    ),
                    if (listeSelectionnee != null && selection.isNotEmpty)
                      FilledButton.icon(
                        onPressed: _ajouterSelectionAListe,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text('Ajouter (${selection.length})'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // ── Filtres par catégorie / rayon ─────────────────────
          const FiltresBar(),

          // ── Compteur + tri actif ──────────────────────────────
          articlesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (articles) => articles.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(
                      children: [
                        Text(
                          '${articles.length} article${articles.length > 1 ? "s" : ""}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.outline),
                        ),
                        const Spacer(),
                        if (sort != SortMode.alphabetique)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              sort == SortMode.categorie
                                  ? 'Par catégorie'
                                  : 'Par rayon',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),

          // ── Liste des articles ────────────────────────────────
          Expanded(
            child: articlesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (articles) {
                if (articles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.inventory_2_outlined,
                              size: 44,
                              color:
                                  Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 24),
                        Text('Catalogue vide',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          'Ajoutez vos premiers articles\nvia le bouton + ou le scanner',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.outline),
                        ),
                      ],
                    ),
                  );
                }

                if (listeSelectionnee != null) {
                  return _buildSelectionList(articles, sort);
                }

                if (sort == SortMode.alphabetique) {
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
                    itemCount: articles.length,
                    itemBuilder: (_, i) => AnimatedListItem(
                      index: i,
                      child: ArticleTile(article: articles[i]),
                    ),
                  );
                }
                return _buildGroupedList(articles, sort);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Ajout avec options
          FloatingActionButton.small(
            heroTag: 'add_full',
            onPressed: () => showDialog(
                context: context,
                builder: (_) => const AjouterArticleDialog()),
            tooltip: 'Ajout avec options',
            child: const Icon(Icons.tune),
          ),
          const SizedBox(width: 10),
          // Ajout rapide
          FloatingActionButton.extended(
            heroTag: 'add_quick',
            onPressed: () async {
              // Le contexte de cet écran reste stable même après la
              // fermeture du dialogue d'ajout rapide : c'est lui qui doit
              // ouvrir le dialogue "avec options" suivant, pas le dialogue
              // qu'on vient de fermer (son contexte serait déjà invalide).
              final nom = await showDialog<String>(
                  context: context,
                  builder: (_) => const AjoutRapideDialog());
              if (nom == null || !context.mounted) return;
              showDialog(
                  context: context,
                  builder: (_) => AjouterArticleDialog(nomInitial: nom));
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajout rapide'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionList(List<Article> articles, SortMode sort) {
    final selection = ref.watch(articlesSelectionnesProvider);

    Widget buildTile(Article article, int index) {
      final selectionne = selection.contains(article.id);
      return AnimatedListItem(
        index: index,
        child: ListTile(
          onTap: () {
            final current =
                Set<String>.from(ref.read(articlesSelectionnesProvider));
            if (selectionne) {
              current.remove(article.id);
            } else {
              current.add(article.id);
            }
            ref.read(articlesSelectionnesProvider.notifier).state = current;
          },
          leading: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              selectionne
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              key: ValueKey(selectionne),
              color: selectionne
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          title: Text(article.nom,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: selectionne
                    ? Theme.of(context).colorScheme.primary
                    : null,
              )),
          subtitle: article.marque != null ? Text(article.marque!) : null,
          // Prix visible directement dans la sélection : avant, il fallait
          // ajouter l'article puis ouvrir la liste pour savoir combien il
          // coûtait.
          trailing: PrixArticleBadge(article: article),
          tileColor: selectionne
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3)
              : null,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    if (sort == SortMode.alphabetique) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 100),
        itemCount: articles.length,
        itemBuilder: (_, i) => buildTile(articles[i], i),
      );
    }
    return _buildGroupedListWithSelection(articles, sort, buildTile);
  }

  Widget _buildGroupedListWithSelection(List<Article> articles, SortMode sort,
      Widget Function(Article, int) buildTile) {
    return _buildGroupedBase(articles, sort, buildTile);
  }

  Widget _buildGroupedList(List<Article> articles, SortMode sort) {
    return _buildGroupedBase(
      articles,
      sort,
      (article, idx) => AnimatedListItem(
        index: idx,
        child: ArticleTile(article: article),
      ),
    );
  }

  Widget _buildGroupedBase(List<Article> articles, SortMode sort,
      Widget Function(Article, int) buildTile) {
    final catAsync = ref.watch(categoriesNotifierProvider);
    final rayAsync = ref.watch(rayonsNotifierProvider);

    return catAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (categories) => rayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (rayons) {
          final Map<String, List<Article>> groupes = {};
          for (final a in articles) {
            final cle = sort == SortMode.categorie
                ? (a.categorieId ?? '__aucun__')
                : (a.rayonId ?? '__aucun__');
            groupes.putIfAbsent(cle, () => []).add(a);
          }

          final cles = groupes.keys.toList();
          int globalIndex = 0;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
            itemCount: cles.length,
            itemBuilder: (_, i) {
              final cle = cles[i];
              final articlesGroupe = groupes[cle]!;
              final label = _labelPour(cle, sort, categories, rayons);
              final cat = sort == SortMode.categorie
                  ? categories.where((c) => c.id == cle).firstOrNull
                  : null;
              final ray = sort == SortMode.rayon
                  ? rayons.where((r) => r.id == cle).firstOrNull
                  : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GroupHeader(
                    label: label,
                    count: articlesGroupe.length,
                    couleur: cat != null
                        ? Color(cat.couleur)
                        : ray != null
                            ? Color(ray.couleur)
                            : Theme.of(context).colorScheme.primary,
                    isRayon: sort == SortMode.rayon,
                  ),
                  ...articlesGroupe.asMap().entries.map((e) {
                    final idx = globalIndex++;
                    return buildTile(e.value, idx);
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _labelPour(String cle, SortMode sort, List<Categorie> cats,
      List<Rayon> rayons) {
    if (cle == '__aucun__') {
      return sort == SortMode.categorie ? 'Sans catégorie' : 'Sans rayon';
    }
    if (sort == SortMode.categorie) {
      return cats.where((c) => c.id == cle).firstOrNull?.nom ?? cle;
    }
    return rayons.where((r) => r.id == cle).firstOrNull?.nom ?? cle;
  }
}

// En-tête de groupe amélioré
class _GroupHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color couleur;
  final bool isRayon;

  const _GroupHeader({
    required this.label,
    required this.count,
    required this.couleur,
    this.isRayon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: couleur,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            isRayon ? Icons.store_outlined : Icons.home_outlined,
            size: 14,
            color: couleur,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: couleur,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: couleur,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
