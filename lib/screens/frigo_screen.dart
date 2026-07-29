import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../providers/recettes_en_ligne_provider.dart';
import '../services/spoonacular_service.dart';
import '../utils/erreur_utils.dart';
import 'recette_en_ligne_detail_screen.dart';

// ================================================================
// FRIGO — l'utilisateur saisit ce qu'il a, l'app propose des recettes
// qui utilisent au mieux ces ingrédients (Spoonacular findByIngredients).
// ================================================================
class FrigoScreen extends ConsumerStatefulWidget {
  const FrigoScreen({super.key});

  @override
  ConsumerState<FrigoScreen> createState() => _FrigoScreenState();
}

class _FrigoScreenState extends ConsumerState<FrigoScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ajouter() {
    final texte = _ctrl.text.trim();
    if (texte.isEmpty) return;
    // Permet de coller "tomate, oignon, riz" d'un coup.
    final nouveaux = texte
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    final actuel = [...ref.read(frigoIngredientsProvider)];
    for (final n in nouveaux) {
      if (!actuel.any((e) => e.toLowerCase() == n.toLowerCase())) {
        actuel.add(n);
      }
    }
    ref.read(frigoIngredientsProvider.notifier).state = actuel;
    _ctrl.clear();
  }

  void _retirer(String ingredient) {
    ref.read(frigoIngredientsProvider.notifier).state = [
      for (final e in ref.read(frigoIngredientsProvider))
        if (e != ingredient) e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.spoonacularConfigure) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dans mon frigo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Ajoute une clé Spoonacular gratuite dans '
              'lib/config/api_config.dart pour activer les suggestions de '
              'recettes à partir de ton frigo.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
      );
    }

    final ingredients = ref.watch(frigoIngredientsProvider);
    final suggestions = ref.watch(suggestionsFrigoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dans mon frigo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Ex : tomate, œufs, riz…',
                      prefixIcon: Icon(Icons.kitchen),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _ajouter(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _ajouter, child: const Text('Ajouter')),
              ],
            ),
          ),
          if (ingredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final ing in ingredients)
                      InputChip(
                        label: Text(ing),
                        onDeleted: () => _retirer(ing),
                      ),
                  ],
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ingredients.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.kitchen_outlined,
                              size: 56,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'Ajoute ce que tu as sous la main,\n'
                            'on te propose des recettes.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : suggestions.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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
                            child: Text(
                                'Aucune recette trouvée avec ces ingrédients.',
                                textAlign: TextAlign.center),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: recettes.length,
                        itemBuilder: (_, i) =>
                            _LigneSuggestion(recette: recettes[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LigneSuggestion extends StatelessWidget {
  final RecetteEnLigneResume recette;
  const _LigneSuggestion({required this.recette});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: recette.image == null
              ? Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.restaurant,
                      color: Theme.of(context).colorScheme.outline),
                )
              : Image.network(
                  recette.image!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.restaurant,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ),
        ),
        title: Text(recette.titre,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: recette.ingredientsManquants == null
            ? null
            : Text(recette.ingredientsManquants == 0
                ? 'Tu as tout ce qu\'il faut'
                : '${recette.ingredientsManquants} ingrédient(s) à acheter'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecetteEnLigneDetailScreen(id: recette.id),
          ),
        ),
      ),
    );
  }
}
