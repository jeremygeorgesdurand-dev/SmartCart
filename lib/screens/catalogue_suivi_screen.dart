import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/theme_utils.dart';

// Affichage SÉPARÉ et en lecture seule d'un catalogue SUIVI (partage temps
// réel). Ses articles/catégories ne se mélangent pas au catalogue perso : on
// peut les consulter, en sélectionner pour les ajouter à une liste (ils sont
// alors copiés dans son propre catalogue), tout copier, ou arrêter de suivre.
class CatalogueSuiviScreen extends ConsumerStatefulWidget {
  final String catalogueId;
  final String nom;
  const CatalogueSuiviScreen(
      {super.key, required this.catalogueId, required this.nom});

  @override
  ConsumerState<CatalogueSuiviScreen> createState() =>
      _CatalogueSuiviScreenState();
}

class _CatalogueSuiviScreenState extends ConsumerState<CatalogueSuiviScreen> {
  // Ids (du catalogue suivi) des articles sélectionnés.
  final Set<String> _selection = {};
  // Mêmes filtres que le catalogue perso : recherche + catégorie choisie.
  String _recherche = '';
  String? _categorieFiltre; // null = toutes les catégories

  Future<void> _toutAjouter() async {
    final db = ref.read(dbServiceProvider);
    final res = await ref.read(backupServiceProvider).fusionnerCatalogue(
          categories: await db.getCategoriesParSource(widget.catalogueId),
          rayons: await db.getRayonsParSource(widget.catalogueId),
          articles: await db.getArticlesParSource(widget.catalogueId),
        );
    ref.invalidate(articlesNotifierProvider);
    ref.invalidate(categoriesNotifierProvider);
    ref.invalidate(rayonsNotifierProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Ajouté à ton catalogue : ${res.articles} article(s), '
          '${res.categories} catégorie(s)'),
      backgroundColor: couleurSucces(context),
    ));
  }

  // Copie les articles sélectionnés dans MON catalogue (fusion par nom) puis
  // les ajoute à la liste choisie.
  Future<void> _ajouterALaListe() async {
    final db = ref.read(dbServiceProvider);
    final tousArticles = await db.getArticlesParSource(widget.catalogueId);
    final choisis =
        tousArticles.where((a) => _selection.contains(a.id)).toList();
    if (choisis.isEmpty) return;

    // Choix de la liste cible (existante ou nouvelle).
    final listeId = await _choisirListe();
    if (listeId == null) return;

    // 1) Copier les articles choisis dans mon catalogue (par nom, avec leurs
    //    catégories/rayons rattachés aux miens). On passe toutes les
    //    catégories/rayons du catalogue suivi pour un bon rattachement.
    await ref.read(backupServiceProvider).fusionnerCatalogue(
          categories: await db.getCategoriesParSource(widget.catalogueId),
          rayons: await db.getRayonsParSource(widget.catalogueId),
          articles: choisis,
        );
    ref.invalidate(articlesNotifierProvider);

    // 2) Retrouver les articles (désormais dans MON catalogue) par nom et les
    //    ajouter à la liste.
    final miens = await db.getArticles();
    String norm(String s) => s.trim().toLowerCase();
    final parNom = {for (final a in miens) norm(a.nom): a};
    final notifier = ref.read(articlesListeProvider(listeId).notifier);
    var ajoutes = 0;
    for (final c in choisis) {
      final local = parNom[norm(c.nom)];
      if (local == null) continue;
      await notifier.ajouter(ArticleListe(
        id: 'al_${const Uuid().v4()}',
        listeId: listeId,
        articleId: local.id,
      ));
      ajoutes++;
    }

    if (!mounted) return;
    setState(() => _selection.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$ajoutes article(s) ajouté(s) à la liste'),
      backgroundColor: couleurSucces(context),
    ));
  }

  // Feuille de choix : une liste existante (non archivée) ou une nouvelle.
  Future<String?> _choisirListe() async {
    final listes = (await ref.read(listesNotifierProvider.future))
        .where((l) => !l.archivee)
        .toList();
    if (!mounted) return null;
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Ajouter à…',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Nouvelle liste'),
              onTap: () async {
                final id = 'liste_${const Uuid().v4()}';
                await ref.read(listesNotifierProvider.notifier).ajouter(
                    ListeCourses(id: id, nom: 'Liste ${widget.nom}'));
                if (sheetCtx.mounted) Navigator.pop(sheetCtx, id);
              },
            ),
            const Divider(height: 1),
            for (final l in listes)
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: Text(l.nom),
                onTap: () => Navigator.pop(sheetCtx, l.id),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _arreter() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Arrêter de suivre ?'),
        content: Text('« ${widget.nom} » sera retiré de tes catalogues '
            'suivis. Ton catalogue personnel n\'est pas touché.'),
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
    await ref
        .read(syncServiceProvider)
        .arreterDeSuivreCatalogue(widget.catalogueId);
    ref.invalidate(cataloguesSuivisProvider);
    // On est dans l'onglet Catalogue (pas une fenêtre poussée) : revenir à
    // « Mon catalogue » = remettre la sélection à null.
    ref.read(catalogueSelectionneProvider.notifier).state = null;
  }

  // Sélecteur de catalogue affiché comme titre (identique à celui du
  // catalogue perso) : permet de revenir à « Mon catalogue » ou de basculer
  // sur un autre catalogue suivi sans changer de fenêtre.
  Widget _titreSelecteur() {
    final suivis = ref.watch(cataloguesSuivisProvider).valueOrNull ?? [];
    return PopupMenuButton<String?>(
      onSelected: (id) =>
          ref.read(catalogueSelectionneProvider.notifier).state = id,
      itemBuilder: (_) => [
        const PopupMenuItem<String?>(
            value: null, child: Text('Mon catalogue')),
        const PopupMenuDivider(),
        for (final s in suivis)
          PopupMenuItem<String?>(value: s.id, child: Text(s.nom)),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(widget.nom, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contenuAsync =
        ref.watch(contenuCatalogueSuiviProvider(widget.catalogueId));
    return Scaffold(
      appBar: AppBar(
        title: _titreSelecteur(),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'arreter') _arreter();
              if (v == 'tout') _toutAjouter();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'tout',
                  child: Text('Tout ajouter à mon catalogue')),
              PopupMenuItem(
                  value: 'arreter', child: Text('Arrêter de suivre')),
            ],
          ),
        ],
      ),
      floatingActionButton: _selection.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _ajouterALaListe,
              icon: const Icon(Icons.playlist_add),
              label: Text('Ajouter à une liste (${_selection.length})'),
            ),
      body: contenuAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (contenu) {
          if (contenu.articles.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                  'Ce catalogue est vide pour l\'instant (ou pas encore reçu).',
                  textAlign: TextAlign.center),
            ));
          }
          final catParId = {for (final c in contenu.categories) c.id: c};
          // Catégories triées pour les chips de filtre.
          final categoriesTriees = [...contenu.categories]
            ..sort((a, b) => a.ordre.compareTo(b.ordre));
          // Filtre recherche + catégorie (comme le catalogue perso).
          final articlesFiltres = contenu.articles.where((a) {
            if (_recherche.isNotEmpty &&
                !a.nom.toLowerCase().contains(_recherche.toLowerCase())) {
              return false;
            }
            if (_categorieFiltre != null &&
                a.categorieId != _categorieFiltre) {
              return false;
            }
            return true;
          }).toList();
          // Groupe les articles filtrés par catégorie (du catalogue suivi).
          final groupes = <String, List<Article>>{};
          for (final a in articlesFiltres) {
            final cle = a.categorieId ?? '__aucune__';
            groupes.putIfAbsent(cle, () => []).add(a);
          }
          final cles = groupes.keys.toList()
            ..sort((x, y) {
              if (x == '__aucune__') return 1;
              if (y == '__aucune__') return -1;
              return (catParId[x]?.ordre ?? 99)
                  .compareTo(catParId[y]?.ordre ?? 99);
            });
          return Column(
            children: [
              // Recherche
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setState(() => _recherche = v),
                ),
              ),
              // Chips de catégories (Toutes + chaque catégorie du catalogue suivi)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: FilterChip(
                        label: const Text('Toutes'),
                        selected: _categorieFiltre == null,
                        onSelected: (_) =>
                            setState(() => _categorieFiltre = null),
                      ),
                    ),
                    for (final c in categoriesTriees)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: FilterChip(
                          avatar: CircleAvatar(
                              radius: 6,
                              backgroundColor: Color(c.couleur)),
                          label: Text(c.nom),
                          selected: _categorieFiltre == c.id,
                          onSelected: (_) => setState(() =>
                              _categorieFiltre =
                                  _categorieFiltre == c.id ? null : c.id),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Coche des articles pour les ajouter à une liste (ils seront '
                  'copiés dans ton catalogue).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline),
                ),
              ),
              for (final cle in cles) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(
                    children: [
                      if (catParId[cle] != null) ...[
                        CircleAvatar(
                            radius: 6,
                            backgroundColor: Color(catParId[cle]!.couleur)),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        catParId[cle]?.nom ?? 'Sans catégorie',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (final a in groupes[cle]!)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _selection.contains(a.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selection.add(a.id);
                      } else {
                        _selection.remove(a.id);
                      }
                    }),
                    title: Text(a.nom),
                  ),
              ],
            ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
