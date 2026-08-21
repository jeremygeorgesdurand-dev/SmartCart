import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recettes_en_ligne_provider.dart';
import '../utils/erreur_utils.dart';
import 'recette_en_ligne_detail_screen.dart';

// ================================================================
// FRIGO — l'utilisateur saisit ses ingrédients, l'app propose les
// recettes du dataset qui les utilisent le plus. 100% local.
// Contenu intégré comme onglet (pas de Scaffold propre).
// ================================================================
class FrigoTab extends ConsumerStatefulWidget {
  const FrigoTab({super.key});

  @override
  ConsumerState<FrigoTab> createState() => _FrigoTabState();
}

// Écran dédié « Cuisiner avec mon frigo » : le contenu du frigo n'est plus un
// sous-onglet des Recettes (allégement), on y accède par un bouton depuis
// Explorer.
class FrigoScreen extends StatelessWidget {
  const FrigoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuisiner avec mon frigo')),
      body: const FrigoTab(),
    );
  }
}

class _FrigoTabState extends ConsumerState<FrigoTab> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ajouter() {
    final texte = _ctrl.text.trim();
    if (texte.isEmpty) return;
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
    final ingredients = ref.watch(frigoIngredientsProvider);
    final suggestions = ref.watch(suggestionsFrigoProvider);

    return Column(
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
                        label: Text(ing), onDeleted: () => _retirer(ing)),
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
                  data: (brut) {
                    if (brut.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                              'Aucune recette trouvée avec ces ingrédients.',
                              textAlign: TextAlign.center),
                        ),
                      );
                    }
                    final tri = ref.watch(frigoTriProvider);
                    final recettes = [...brut];
                    recettes.sort((a, b) {
                      if (tri == FrigoTri.moinsAAcheter) {
                        return a.manquants.compareTo(b.manquants);
                      }
                      return b.dispo.compareTo(a.dispo);
                    });
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                          child: Row(
                            children: [
                              Text('Trier :',
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(width: 8),
                              _BoutonTri(
                                label: 'Plus d\'ingrédients',
                                actif: tri == FrigoTri.plusUtilises,
                                onTap: () => ref
                                    .read(frigoTriProvider.notifier)
                                    .state = FrigoTri.plusUtilises,
                              ),
                              const SizedBox(width: 6),
                              _BoutonTri(
                                label: 'Moins à acheter',
                                actif: tri == FrigoTri.moinsAAcheter,
                                onTap: () => ref
                                    .read(frigoTriProvider.notifier)
                                    .state = FrigoTri.moinsAAcheter,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: recettes.length,
                            itemBuilder: (_, i) =>
                                _LigneSuggestion(suggestion: recettes[i]),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BoutonTri extends StatelessWidget {
  final String label;
  final bool actif;
  final VoidCallback onTap;
  const _BoutonTri(
      {required this.label, required this.actif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: actif,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _LigneSuggestion extends StatelessWidget {
  final SuggestionFrigo suggestion;
  const _LigneSuggestion({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final r = suggestion.recette;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: r.image == null
              ? Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.restaurant,
                      color: Theme.of(context).colorScheme.outline))
              : Image.network(
                  r.image!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.restaurant,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ),
        ),
        title: Text(r.titre, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          suggestion.manquants == 0
              ? '${suggestion.dispo} ingrédient(s) — tu as tout !'
              : '${suggestion.dispo} dispo · ${suggestion.manquants} à acheter',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecetteEnLigneDetailScreen(id: r.id),
          ),
        ),
      ),
    );
  }
}
