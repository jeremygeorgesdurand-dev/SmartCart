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
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'scanner_screen.dart';
import '../widgets/import_liste_dialog.dart' show ImportListeDialog, ExportDialog;
import '../utils/erreur_utils.dart';
import '../utils/messages.dart';
import '../utils/theme_utils.dart';
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

    final sel = ref.read(catalogueSelectionneProvider);
    // Depuis un catalogue SUIVI : les articles ne sont pas à MON catalogue. On
    // les copie d'abord (fusion par nom, avec leurs catégories/rayons) puis on
    // les retrouve par nom dans mon catalogue pour les ajouter à la liste.
    if (sel != null) {
      await _ajouterSelectionSuivieAListe(sel, liste, selection);
      return;
    }

    final catalogue = ref.read(articlesNotifierProvider).valueOrNull ?? [];
    final quantites = ref.read(articlesQuantitesProvider);
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
              quantite: quantites[articleId] ?? 1,
            ),
          );
      idsDejaPresents.add(articleId); // éviter doublons dans la même sélection
      nbAjoutes++;
    }

    // On vide la sélection d'articles et les quantités, mais on GARDE la liste
    // sélectionnée pour pouvoir enchaîner d'autres ajouts sans la re-choisir.
    ref.read(articlesSelectionnesProvider.notifier).state = {};
    ref.read(articlesQuantitesProvider.notifier).state = {};

    if (mounted) {
      afficherMessage(
        context,
        nbAjoutes == 0
            ? 'Articles déjà présents dans la liste'
            : '$nbAjoutes article(s) ajouté(s) à "${liste.nom}"',
        couleur: nbAjoutes > 0 ? couleurSucces(context) : null,
      );
    }
  }

  // Ajoute à une liste des articles COCHÉS dans un catalogue SUIVI : ils sont
  // d'abord copiés dans mon catalogue (fusion par nom, avec leurs catégories et
  // rayons), puis retrouvés par nom et ajoutés à la liste.
  Future<void> _ajouterSelectionSuivieAListe(
      String catId, ListeCourses liste, Set<String> selection) async {
    final db = ref.read(dbServiceProvider);
    final contenu =
        ref.read(contenuCatalogueSuiviProvider(catId)).valueOrNull;
    if (contenu == null) return;
    final choisis =
        contenu.articles.where((a) => selection.contains(a.id)).toList();
    if (choisis.isEmpty) return;

    await ref.read(backupServiceProvider).fusionnerCatalogue(
          categories: contenu.categories,
          rayons: contenu.rayons,
          articles: choisis,
        );
    ref.invalidate(articlesNotifierProvider);

    final quantites = ref.read(articlesQuantitesProvider);
    final miens = await db.getArticles();
    String norm(String s) => s.trim().toLowerCase();
    final parNom = {for (final a in miens) norm(a.nom): a};
    final notifier = ref.read(articlesListeProvider(liste.id).notifier);
    final itemsExistants = await db.getArticlesListe(liste.id);
    final idsDejaPresents = itemsExistants.map((i) => i.articleId).toSet();
    var nbAjoutes = 0;
    for (final c in choisis) {
      final local = parNom[norm(c.nom)];
      if (local == null || idsDejaPresents.contains(local.id)) continue;
      await notifier.ajouter(ArticleListe(
        id: 'al_${const Uuid().v4()}',
        listeId: liste.id,
        articleId: local.id,
        quantite: quantites[c.id] ?? 1,
      ));
      idsDejaPresents.add(local.id);
      nbAjoutes++;
    }

    // On garde la liste sélectionnée (enchaîner les ajouts) ; on ne vide que
    // la sélection d'articles et les quantités.
    ref.read(articlesSelectionnesProvider.notifier).state = {};
    ref.read(articlesQuantitesProvider.notifier).state = {};
    if (mounted) {
      afficherMessage(
        context,
        nbAjoutes == 0
            ? 'Articles déjà présents dans la liste'
            : '$nbAjoutes article(s) ajouté(s) à "${liste.nom}"',
        couleur: nbAjoutes > 0 ? couleurSucces(context) : null,
      );
    }
  }

  // « Tout ajouter à mon catalogue » (depuis un catalogue suivi).
  Future<void> _toutAjouterCatalogueSuivi() async {
    final catId = ref.read(catalogueSelectionneProvider);
    if (catId == null) return;
    final contenu =
        ref.read(contenuCatalogueSuiviProvider(catId)).valueOrNull;
    if (contenu == null) return;
    final res = await ref.read(backupServiceProvider).fusionnerCatalogue(
          categories: contenu.categories,
          rayons: contenu.rayons,
          articles: contenu.articles,
        );
    ref.invalidate(articlesNotifierProvider);
    ref.invalidate(categoriesNotifierProvider);
    ref.invalidate(rayonsNotifierProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ajouté à ton catalogue : ${res.articles} article(s), '
            '${res.categories} catégorie(s)'),
        backgroundColor: couleurSucces(context),
      ));
    }
  }

  // « Arrêter de suivre » : on revient à mon catalogue (même écran).
  Future<void> _arreterCatalogueSuivi() async {
    final catId = ref.read(catalogueSelectionneProvider);
    if (catId == null) return;
    final nom = (ref.read(cataloguesSuivisProvider).valueOrNull ?? [])
            .where((s) => s.id == catId)
            .firstOrNull
            ?.nom ??
        'ce catalogue';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Arrêter de suivre ?'),
        content: Text('« $nom » sera retiré de tes catalogues suivis. '
            'Ton catalogue personnel n\'est pas touché.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Arrêter')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(syncServiceProvider).arreterDeSuivreCatalogue(catId);
    ref.read(catalogueSelectionneProvider.notifier).state = null;
    ref.invalidate(cataloguesSuivisProvider);
  }

  // Titre du Catalogue : simple texte, ou un sélecteur « Mon catalogue ▾ » si
  // l'utilisateur suit des catalogues partagés (il peut alors basculer sur
  // l'un d'eux, affiché à part en lecture seule).
  Widget _titreAvecSelecteur(BuildContext context) {
    final suivis = ref.watch(cataloguesSuivisProvider).valueOrNull ?? [];
    if (suivis.isEmpty) return const Text('Catalogue');
    final sel = ref.watch(catalogueSelectionneProvider);
    final nomActif = sel == null
        ? 'Mon catalogue'
        : (suivis.where((s) => s.id == sel).firstOrNull?.nom ?? 'Mon catalogue');
    // Bascule DANS le même écran : seule la liste d'articles change. On remet
    // les filtres/recherche à zéro car les catégories diffèrent d'un catalogue
    // à l'autre (un id de filtre n'a pas de sens dans l'autre catalogue).
    // IMPORTANT : PopupMenuButton considère une valeur NULLE comme une
    // ANNULATION (il n'appelle jamais onSelected) — « Mon catalogue » ne faisait
    // donc rien. On utilise une sentinelle non-nulle et on la retraduit en null.
    const sentinelleMien = '__mien__';
    return PopupMenuButton<String>(
      onSelected: (v) {
        final id = v == sentinelleMien ? null : v;
        ref.read(catalogueSelectionneProvider.notifier).state = id;
        ref.read(filterCategorieProvider.notifier).state = null;
        ref.read(filterRayonProvider.notifier).state = null;
        ref.read(searchQueryProvider.notifier).state = '';
        ref.read(listeSelectionneeProvider.notifier).state = null;
        ref.read(articlesSelectionnesProvider.notifier).state = {};
        if (_searchVisible) setState(() => _searchVisible = false);
        _searchController.clear();
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem<String>(
            value: sentinelleMien,
            checked: sel == null,
            child: const Text('Mon catalogue')),
        const PopupMenuDivider(),
        for (final s in suivis)
          CheckedPopupMenuItem<String>(
              value: s.id, checked: sel == s.id, child: Text(s.nom)),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(nomActif, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  // Partage temps réel du catalogue : QR + code.
  Future<void> _partagerCatalogueDirect() async {
    try {
      final code = await ref.read(syncServiceProvider).partagerMonCatalogue();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Partager mon catalogue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Fais scanner ce QR code (ou donne le code) à qui '
                  'veut suivre ton catalogue en direct.'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.white,
                child: QrImageView(data: code, size: 200),
              ),
              const SizedBox(height: 12),
              SelectableText(code,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Échec : $e')));
      }
    }
  }

  // Suivre un catalogue : scan QR ou saisie du code.
  Future<void> _suivreCatalogue() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Suivre un catalogue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  hintText: 'Code à 6 caractères',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner un QR code'),
              onPressed: () async {
                final scanned = await Navigator.push<String>(
                    dctx,
                    MaterialPageRoute(
                        builder: (_) => const _ScanQrScreen()));
                if (scanned != null && dctx.mounted) {
                  Navigator.pop(dctx, scanned);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
              child: const Text('Suivre')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      final ok = await ref.read(syncServiceProvider).suivreCatalogue(code);
      if (!mounted) return;
      if (ok) ref.invalidate(cataloguesSuivisProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Catalogue suivi : « Mon catalogue ▾ » en haut pour le voir'
            : 'Code invalide'),
        backgroundColor: ok ? couleurSucces(context) : null,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Échec : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(catalogueArticlesFiltresProvider);
    final listesAsync = ref.watch(listesNotifierProvider);
    final listeSelectionnee = ref.watch(listeSelectionneeProvider);
    final selection = ref.watch(articlesSelectionnesProvider);
    final sort = ref.watch(sortModeProvider);
    // Vrai quand on affiche un catalogue SUIVI (lecture seule) : on masque
    // alors les outils d'édition (ajout, vocal, scanner) et on rend les tuiles
    // non modifiables. Le reste de l'interface (recherche, filtres, sélecteur,
    // ajout à une liste) est identique à mon catalogue.
    final suivi = ref.watch(catalogueSuiviAffiche);

    return Scaffold(
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                    color: Theme.of(context).appBarTheme.foregroundColor ??
                        Theme.of(context).colorScheme.onPrimary),
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(
                      color: (Theme.of(context).appBarTheme.foregroundColor ??
                              Theme.of(context).colorScheme.onPrimary)
                          .withValues(alpha: 0.7)),
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).state = v,
              )
            : _titreAvecSelecteur(context),
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
          // Vocal + scanner : seulement sur MON catalogue (édition).
          if (!suivi) ...[
            IconButton(
              icon: const Icon(Icons.mic),
              tooltip: 'Saisie vocale',
              onPressed: _ouvrirVocal,
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scanner un code-barres',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ScannerScreen())),
            ),
          ],
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
                case 'partager_cat':
                  _partagerCatalogueDirect();
                case 'suivre_cat':
                  _suivreCatalogue();
                case 'tout_ajouter':
                  _toutAjouterCatalogueSuivi();
                case 'arreter_suivi':
                  _arreterCatalogueSuivi();
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
              // Catalogue SUIVI : actions de lecture seule. Mon catalogue :
              // outils d'édition/partage.
              if (suivi) ...[
                const PopupMenuItem(
                    value: 'tout_ajouter',
                    child: Row(children: [
                      Icon(Icons.library_add, size: 18),
                      SizedBox(width: 10),
                      Text('Tout ajouter à mon catalogue')
                    ])),
                const PopupMenuItem(
                    value: 'arreter_suivi',
                    child: Row(children: [
                      Icon(Icons.unpublished_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Arrêter de suivre')
                    ])),
              ] else ...[
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
                        Builder(builder: (context) {
                          final fond = couleurAvertissement(context);
                          return CircleAvatar(
                            radius: 9,
                            backgroundColor: fond,
                            child: Text(
                              '${ref.watch(doublonsProvider).length}',
                              style: TextStyle(
                                  fontSize: 10, color: texteContrastant(fond)),
                            ),
                          );
                        }),
                      ],
                    ])),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'partager_cat',
                    child: Row(children: [
                      Icon(Icons.qr_code_2, size: 18),
                      SizedBox(width: 10),
                      Text('Partager mon catalogue')
                    ])),
                const PopupMenuItem(
                    value: 'suivre_cat',
                    child: Row(children: [
                      Icon(Icons.rss_feed, size: 18),
                      SizedBox(width: 10),
                      Text('Suivre un catalogue')
                    ])),
              ],
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
            data: (toutes) {
              final listes = toutes.where((l) => !l.archivee).toList();
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
                          // La valeur DOIT être une instance PRÉSENTE dans
                          // `items`, comparée par `==` : on la retrouve par id
                          // dans `listes` plutôt que d'utiliser l'instance
                          // stockée (qui peut être une copie périmée après un
                          // rechargement du provider) — sinon DropdownButton
                          // lève une assertion et fait planter l'écran.
                          value: listes
                              .where((l) => l.id == listeSelectionnee?.id)
                              .firstOrNull,
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
              error: (e, _) =>
                  Center(child: Text(messageErreurLisible(e, 'Erreur'))),
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
                      child: ArticleTile(
                          article: articles[i], lectureSeule: suivi),
                    ),
                  );
                }
                return _buildGroupedList(articles, sort, suivi);
              },
            ),
          ),
        ],
      ),
      // Catalogue suivi (lecture seule) : pas de boutons d'ajout d'article.
      floatingActionButton: suivi
          ? null
          : Row(
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
    final quantites = ref.watch(articlesQuantitesProvider);

    Widget buildTile(Article article, int index) {
      final selectionne = selection.contains(article.id);
      final qte = quantites[article.id] ?? 1;
      return AnimatedListItem(
        index: index,
        child: ListTile(
          selected: selectionne,
          onTap: () {
            final current =
                Set<String>.from(ref.read(articlesSelectionnesProvider));
            if (selectionne) {
              current.remove(article.id);
              // Décocher remet sa quantité à 1 (retirée de la map).
              final m = Map<String, int>.from(
                  ref.read(articlesQuantitesProvider))
                ..remove(article.id);
              ref.read(articlesQuantitesProvider.notifier).state = m;
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
          // Article coché : sélecteur de quantité (− n +). Sinon, simple prix
          // indicatif (visible directement dans la sélection).
          trailing: selectionne
              ? _SelecteurQuantite(
                  quantite: qte,
                  onChange: (v) {
                    final m = Map<String, int>.from(
                        ref.read(articlesQuantitesProvider));
                    if (v <= 1) {
                      m.remove(article.id);
                    } else {
                      m[article.id] = v;
                    }
                    ref.read(articlesQuantitesProvider.notifier).state = m;
                  },
                )
              : PrixArticleBadge(article: article),
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

  Widget _buildGroupedList(List<Article> articles, SortMode sort, bool suivi) {
    return _buildGroupedBase(
      articles,
      sort,
      (article, idx) => AnimatedListItem(
        index: idx,
        child: ArticleTile(article: article, lectureSeule: suivi),
      ),
    );
  }

  Widget _buildGroupedBase(List<Article> articles, SortMode sort,
      Widget Function(Article, int) buildTile) {
    // Catégories/rayons du catalogue AFFICHÉ (mien ou suivi).
    final catAsync = ref.watch(catalogueCategoriesAffichees);
    final rayAsync = ref.watch(catalogueRayonsAffiches);

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

// Sélecteur de quantité compact (− n +) affiché sur un article coché, pour
// choisir combien on en ajoute à la liste.
class _SelecteurQuantite extends StatelessWidget {
  final int quantite;
  final ValueChanged<int> onChange;
  const _SelecteurQuantite({required this.quantite, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final couleur = Theme.of(context).colorScheme.primary;
    // On englobe tout le sélecteur dans un absorbeur de tap : sans lui, taper
    // dans les espaces entre les boutons (ou sur le nombre) traversait jusqu'au
    // ListTile parent et DÉ-sélectionnait l'article (remettant la quantité à 1),
    // donnant l'impression que « choisir le nombre » ne marchait pas.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              iconSize: 24,
              icon: Icon(Icons.remove_circle, color: couleur),
              onPressed: quantite > 1 ? () => onChange(quantite - 1) : null,
              tooltip: 'Moins',
            ),
            SizedBox(
              width: 24,
              child: Text('$quantite',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              iconSize: 24,
              icon: Icon(Icons.add_circle, color: couleur),
              onPressed: () => onChange(quantite + 1),
              tooltip: 'Plus',
            ),
          ],
        ),
      ),
    );
  }
}

// Petit écran de scan d'un QR code (partage de catalogue). Renvoie le contenu
// scanné une seule fois via Navigator.pop.
class _ScanQrScreen extends StatefulWidget {
  const _ScanQrScreen();
  @override
  State<_ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<_ScanQrScreen> {
  bool _fait = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner le QR code')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_fait) return;
          final code = capture.barcodes.isNotEmpty
              ? capture.barcodes.first.rawValue
              : null;
          if (code != null && code.isNotEmpty) {
            _fait = true;
            Navigator.pop(context, code);
          }
        },
      ),
    );
  }
}
