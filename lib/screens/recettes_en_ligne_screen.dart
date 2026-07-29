import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../providers/recettes_en_ligne_provider.dart';
import '../services/spoonacular_service.dart';
import '../utils/erreur_utils.dart';
import 'recette_en_ligne_detail_screen.dart';

// ================================================================
// EXPLORER DES RECETTES EN LIGNE (Spoonacular) — recherche + filtres.
// Contenu conçu pour être intégré comme onglet dans l'écran Recettes
// (pas de Scaffold ni d'AppBar propre : la page hôte les fournit).
// ================================================================
class ExplorerRecettesTab extends ConsumerStatefulWidget {
  const ExplorerRecettesTab({super.key});

  @override
  ConsumerState<ExplorerRecettesTab> createState() =>
      _ExplorerRecettesTabState();
}

class _ExplorerRecettesTabState
    extends ConsumerState<ExplorerRecettesTab> {
  final _rechercheCtrl = TextEditingController();

  static const _types = [
    ('Plats', 'main course'),
    ('Desserts', 'dessert'),
    ('Petit-déj', 'breakfast'),
    ('Salades', 'salad'),
    ('Entrées', 'appetizer'),
    ('Soupes', 'soup'),
  ];
  static const _regimes = [
    ('Végétarien', 'vegetarian'),
    ('Vegan', 'vegan'),
    ('Sans gluten', 'gluten free'),
  ];

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.spoonacularConfigure) {
      return const _MessageConfiguration();
    }

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
                hintText: 'Rechercher une recette…',
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
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) =>
                  notifier.update((f) => f.copyWith(requete: v)),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _Filtre(
                  label: 'Protéiné',
                  actif: filtres.proteine,
                  onTap: () => notifier
                      .update((f) => f.copyWith(proteine: !f.proteine)),
                ),
                const _Separateur(),
                for (final (label, val) in _types)
                  _Filtre(
                    label: label,
                    actif: filtres.type == val,
                    onTap: () => notifier.update((f) =>
                        f.copyWith(type: f.type == val ? null : val)),
                  ),
                const _Separateur(),
                for (final (label, val) in _regimes)
                  _Filtre(
                    label: label,
                    actif: filtres.regime == val,
                    onTap: () => notifier.update((f) =>
                        f.copyWith(regime: f.regime == val ? null : val)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: resultats.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _MessageErreur(erreur: e),
              data: (recettes) {
                if (recettes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Aucune recette trouvée. Essaie d\'autres '
                          'mots-clés ou filtres.',
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: recettes.length,
                  itemBuilder: (_, i) =>
                      _CarteRecette(recette: recettes[i]),
                );
              },
            ),
          ),
        ],
    );
  }
}

class _Filtre extends StatelessWidget {
  final String label;
  final bool actif;
  final VoidCallback onTap;
  const _Filtre(
      {required this.label, required this.actif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: FilterChip(
        label: Text(label),
        selected: actif,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _Separateur extends StatelessWidget {
  const _Separateur();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: VerticalDivider(width: 1),
      );
}

class _CarteRecette extends StatelessWidget {
  final RecetteEnLigneResume recette;
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
            Expanded(
              child: recette.image == null
                  ? Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.restaurant,
                          color: Theme.of(context).colorScheme.outline),
                    )
                  : Image.network(
                      recette.image!,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, child, progress) => progress == null
                          ? child
                          : Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                            ),
                      errorBuilder: (c, _, __) => Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Icon(Icons.restaurant,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
            ),
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
                  if (recette.tempsMinutes != null ||
                      recette.ingredientsManquants != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (recette.tempsMinutes != null) ...[
                          Icon(Icons.schedule,
                              size: 13,
                              color: Theme.of(context).colorScheme.outline),
                          const SizedBox(width: 3),
                          Text('${recette.tempsMinutes} min',
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(context).colorScheme.outline)),
                        ],
                        if (recette.ingredientsManquants != null) ...[
                          const Spacer(),
                          Text(
                            recette.ingredientsManquants == 0
                                ? 'Tout dispo'
                                : '${recette.ingredientsManquants} manquant(s)',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.outline),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageErreur extends StatelessWidget {
  final Object erreur;
  const _MessageErreur({required this.erreur});

  @override
  Widget build(BuildContext context) {
    if (erreur is SpoonacularNonConfigure) return const _MessageConfiguration();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(messageErreurLisible(erreur, 'Erreur'),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MessageConfiguration extends StatelessWidget {
  const _MessageConfiguration();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.key_off,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Recettes en ligne non configurées',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Ajoute une clé Spoonacular gratuite (150 recettes/jour) dans '
              'le fichier lib/config/api_config.dart pour activer la '
              'recherche de recettes en ligne.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
