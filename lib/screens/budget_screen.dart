import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'historique_prix_screen.dart';

// ================================================================
// ÉCRAN BUDGET — prix estimés des articles + total par liste active
// ================================================================
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(articlesNotifierProvider);
    final listesAsync = ref.watch(listesNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budget courses')),
      body: articlesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (articles) {
          if (articles.isEmpty) {
            return Center(
              child: Text('Aucun article dans le catalogue',
                  style: Theme.of(context).textTheme.bodyMedium),
            );
          }

          final prixAsync = ref.watch(prixArticlesNotifierProvider);
          final prix = prixAsync.valueOrNull ?? [];
          final prixParArticle = <String, List<PrixArticle>>{};
          for (final p in prix) {
            (prixParArticle[p.articleId] ??= []).add(p);
          }
          final tries = [...articles]
            ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Estimation par liste',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              listesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (listes) {
                  final actives = listes.where((l) => !l.archivee).toList();
                  if (actives.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('Aucune liste active',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline)),
                    );
                  }
                  return Column(
                    children: actives
                        .map((liste) => _ListeTotalTile(liste: liste))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Prix des articles',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Renseigne un prix estimé pour suivre ton budget',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final a in tries)
                      _ArticlePrixTile(
                          article: a, prix: prixParArticle[a.id] ?? const []),
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

class _ListeTotalTile extends ConsumerWidget {
  final ListeCourses liste;
  const _ListeTotalTile({required this.liste});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(totalListeProvider(liste.id));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.shopping_cart_outlined),
        title: Text(liste.nom),
        trailing: Text(
          '${total.toStringAsFixed(2)} €',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ArticlePrixTile extends ConsumerWidget {
  final Article article;
  final List<PrixArticle> prix;
  const _ArticlePrixTile({required this.article, required this.prix});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tries = [...prix]..sort((a, b) => a.prix.compareTo(b.prix));
    final moinsCher = tries.firstOrNull;

    // Tant qu'aucun prix n'a été saisi/confirmé pour cet article, on va
    // chercher discrètement un prix indicatif en ligne (Open Prices) pour
    // donner un ordre de grandeur sans obliger à tout remplir à la main.
    final indicatifAsync =
        tries.isEmpty ? ref.watch(prixIndicatifProvider(article)) : null;
    final indicatif = indicatifAsync?.valueOrNull;

    return ExpansionTile(
      title: Text(article.nom),
      subtitle: tries.length > 1 ? Text('${tries.length} magasins comparés') : null,
      trailing: tries.isEmpty && indicatif != null
          ? Text(
              '~${indicatif.prix.toStringAsFixed(2)} €',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontStyle: FontStyle.italic),
            )
          : null,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        if (tries.isEmpty && indicatif != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.travel_explore,
                    size: 18, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prix indicatif : ${indicatif.prix.toStringAsFixed(2)} €',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => _editerPrix(context, ref,
                      prixSuggere: indicatif.prix),
                  child: const Text('Utiliser'),
                ),
              ],
            ),
          ),
        for (final p in tries)
          ListTile(
            dense: true,
            leading: Icon(
              p == moinsCher && tries.length > 1
                  ? Icons.star
                  : Icons.storefront_outlined,
              size: 18,
              color: p == moinsCher && tries.length > 1
                  ? Colors.amber[700]
                  : null,
            ),
            title: Text(p.magasin.isEmpty ? 'Prix générique' : p.magasin),
            trailing: TextButton(
              onPressed: () => _editerPrix(context, ref, magasin: p.magasin, prixActuel: p.prix),
              child: Text('${p.prix.toStringAsFixed(2)} €'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _editerPrix(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter un prix (magasin)'),
              ),
              if (tries.isNotEmpty)
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoriquePrixScreen(article: article),
                    ),
                  ),
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text('Voir l\'évolution'),
                ),
              TextButton.icon(
                onPressed: () => _chercherEnLigne(context, ref),
                icon: const Icon(Icons.travel_explore, size: 18),
                label: const Text('Chercher en ligne'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _chercherEnLigne(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // La plupart des articles ajoutés à la main (ajout rapide, dictée
    // vocale) n'ont pas de code-barres : on tente de retrouver le produit
    // par son nom via Open Food Facts pour en récupérer un avant de
    // chercher ses prix.
    var barcode = article.barcode;
    if (barcode == null) {
      final suggestions =
          await ref.read(offServiceProvider).searchByName(article.nom);
      barcode = suggestions.where((a) => a.barcode != null).firstOrNull?.barcode;
    }

    if (barcode == null) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${article.nom}" introuvable sur Open Food Facts — '
            'essaie de scanner le produit pour un résultat plus fiable'),
      ));
      return;
    }

    final resultats =
        await ref.read(openPricesServiceProvider).chercherParBarcode(barcode);

    if (!context.mounted) return;
    Navigator.pop(context); // ferme le loader

    if (resultats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucun prix trouvé en ligne pour ce produit '
            '(base communautaire Open Prices)'),
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prix trouvés pour ${article.nom}',
                  style: Theme.of(sheetCtx).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Source : Open Prices (communautaire, Open Food Facts)',
                  style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetCtx).colorScheme.outline)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in resultats)
                      ListTile(
                        title: Text(r.magasin),
                        subtitle: r.date != null
                            ? Text('Relevé le '
                                '${r.date!.day.toString().padLeft(2, '0')}/'
                                '${r.date!.month.toString().padLeft(2, '0')}/'
                                '${r.date!.year}')
                            : null,
                        trailing: Text('${r.prix.toStringAsFixed(2)} ${r.devise}'),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _editerPrix(context, ref,
                              magasin: r.magasin, prixSuggere: r.prix);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editerPrix(
    BuildContext context,
    WidgetRef ref, {
    String magasin = '',
    double? prixActuel,
    double? prixSuggere,
  }) {
    final ctrlPrix = TextEditingController(
      text: prixActuel != null
          ? prixActuel.toStringAsFixed(2)
          : (prixSuggere != null ? prixSuggere.toStringAsFixed(2) : ''),
    );
    final ctrlMagasin = TextEditingController(text: magasin);
    final estNouveau = prixActuel == null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: Text('Prix de ${article.nom}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrlMagasin,
              enabled: estNouveau,
              decoration: const InputDecoration(
                  labelText: 'Magasin (optionnel)', hintText: 'Ex: Carrefour'),
              maxLength: 40,
            ),
            TextField(
              controller: ctrlPrix,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: '€'),
            ),
          ],
        ),
        actions: [
          if (!estNouveau)
            TextButton(
              onPressed: () {
                ref
                    .read(prixArticlesNotifierProvider.notifier)
                    .supprimer(article.id, magasin: magasin);
                Navigator.pop(context);
              },
              child: const Text('Supprimer'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final valeur = double.tryParse(ctrlPrix.text.replaceAll(',', '.'));
              if (valeur != null && valeur >= 0) {
                ref.read(prixArticlesNotifierProvider.notifier).definir(
                      article.id,
                      valeur,
                      magasin: ctrlMagasin.text.trim(),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
