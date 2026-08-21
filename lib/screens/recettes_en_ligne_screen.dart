import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recettes_en_ligne_provider.dart';
import '../services/recettes_dataset_service.dart';
import '../utils/erreur_utils.dart';
import 'frigo_screen.dart';
import 'recette_en_ligne_detail_screen.dart';

// ================================================================
// EXPLORER LES RECETTES (dataset français local) — recherche +
// filtres par catégorie. Contenu intégré comme onglet (pas de
// Scaffold propre : la page Recettes fournit l'AppBar/TabBar).
// ================================================================
class ExplorerRecettesTab extends ConsumerStatefulWidget {
  const ExplorerRecettesTab({super.key});

  @override
  ConsumerState<ExplorerRecettesTab> createState() =>
      _ExplorerRecettesTabState();
}

class _ExplorerRecettesTabState extends ConsumerState<ExplorerRecettesTab> {
  final _rechercheCtrl = TextEditingController();

  static const _categories = [
    ('Plats', 'Plat'),
    ('Desserts', 'Dessert'),
    ('Entrées', 'Entrée'),
    ('Accompagnements', 'Accompagnement'),
    ('Boissons', 'Boisson'),
  ];

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtres = ref.watch(filtresRecettesProvider);
    final resultats = ref.watch(rechercheRecettesProvider);
    final notifier = ref.read(filtresRecettesProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _rechercheCtrl,
            decoration: InputDecoration(
              hintText: 'Rechercher (nom, ingrédient…)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _rechercheCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _rechercheCtrl.clear();
                        notifier.update((f) => f.copyWith(requete: ''));
                        setState(() {});
                      },
                    ),
            ),
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              notifier.update((f) => f.copyWith(requete: v));
              setState(() {});
            },
          ),
        ),
        // Accès au « frigo » (suggestions à partir de ce qu'on a) : ce n'est
        // plus un onglet séparé, mais un bouton ici (allégement de la barre).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FrigoScreen())),
            icon: const Icon(Icons.kitchen_outlined, size: 20),
            label: const Text('Cuisiner avec mon frigo'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40)),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // Filtre « avec photo » : beaucoup de recettes du dataset n'ont
              // pas d'image, l'activer ne garde que les plus appétissantes.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: FilterChip(
                  avatar: Icon(Icons.photo_outlined,
                      size: 18,
                      color: filtres.avecPhoto
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).colorScheme.outline),
                  label: const Text('Avec photo'),
                  selected: filtres.avecPhoto,
                  onSelected: (_) => notifier
                      .update((f) => f.copyWith(avecPhoto: !f.avecPhoto)),
                ),
              ),
              for (final (label, val) in _categories)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: FilterChip(
                    label: Text(label),
                    selected: filtres.categorie == val,
                    onSelected: (_) => notifier.update((f) =>
                        f.copyWith(categorie: f.categorie == val ? null : val)),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: resultats.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(messageErreurLisible(e, 'Erreur'),
                    textAlign: TextAlign.center),
              ),
            ),
            data: (recettes) {
              if (recettes.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Aucune recette trouvée.',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  childAspectRatio: 0.82,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: recettes.length,
                itemBuilder: (_, i) => _CarteRecette(recette: recettes[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CarteRecette extends StatelessWidget {
  final RecetteDataset recette;
  const _CarteRecette({required this.recette});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecetteEnLigneDetailScreen(id: recette.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Vignette(recette: recette)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recette.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${recette.categorie} · ${recette.ingredients.length} ingrédients',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Vignette : image réseau si disponible, sinon une illustration colorée
// selon la catégorie (325 recettes sur ~980 ont une photo).
class _Vignette extends StatelessWidget {
  final RecetteDataset recette;
  const _Vignette({required this.recette});

  @override
  Widget build(BuildContext context) {
    if (recette.image == null) return _placeholder(context);
    return Image.network(
      recette.image!,
      fit: BoxFit.cover,
      loadingBuilder: (c, child, progress) => progress == null
          ? child
          : Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest),
      errorBuilder: (c, _, __) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    IconData icone;
    switch (recette.categorie) {
      case 'Dessert':
        icone = Icons.cake_outlined;
      case 'Boisson':
        icone = Icons.local_bar_outlined;
      case 'Entrée':
        icone = Icons.ramen_dining_outlined;
      case 'Accompagnement':
        icone = Icons.rice_bowl_outlined;
      default:
        icone = Icons.restaurant_outlined;
    }
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(icone,
          size: 40, color: Theme.of(context).colorScheme.outline),
    );
  }
}
