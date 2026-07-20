import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/off_details_provider.dart';
import 'ajouter_article_dialog.dart';

class ArticleTile extends ConsumerWidget {
  final Article article;
  const ArticleTile({super.key, required this.article});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorie = ref.watch(categoriesNotifierProvider).valueOrNull
        ?.where((c) => c.id == article.categorieId).firstOrNull;
    final rayon = ref.watch(rayonsNotifierProvider).valueOrNull
        ?.where((r) => r.id == article.rayonId).firstOrNull;

    return Dismissible(
      key: Key('article_${article.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 2),
            Text('Supprimer',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Supprimer ?'),
              content: Text('Supprimer "${article.nom}" du catalogue ?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler')),
                FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Supprimer'),
                ),
              ],
            ),
          ) ??
          false,
      onDismissed: (_) {
        final articleSupprime = article;
        ref
            .read(articlesNotifierProvider.notifier)
            .supprimer(articleSupprime.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${articleSupprime.nom}" supprimé du catalogue'),
            action: SnackBarAction(
              label: 'Annuler',
              onPressed: () => ref
                  .read(articlesNotifierProvider.notifier)
                  .ajouter(articleSupprime),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showDialog(
            context: context,
            builder: (_) => AjouterArticleDialog(articleExistant: article),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Nom + chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.nom,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (article.marque != null)
                        Text(article.marque!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline)),
                      if (categorie != null || rayon != null) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 5,
                          children: [
                            if (categorie != null)
                              _Chip(
                                label: categorie.nom,
                                color: Color(categorie.couleur),
                              ),
                            if (rayon != null)
                              _Chip(
                                label: rayon.nom,
                                color: Color(rayon.couleur),
                                icon: Icons.store_outlined,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                if (article.barcode != null)
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20),
                    tooltip: 'Infos nutritionnelles',
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () => _afficherInfosNutritionnelles(
                        context, article.barcode!),
                  ),

                // Icône modifier
                Icon(Icons.chevron_right,
                    color:
                        Theme.of(context).colorScheme.outlineVariant,
                    size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _afficherInfosNutritionnelles(BuildContext context, String barcode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NutritionSheet(barcode: barcode),
    );
  }
}

class _NutritionSheet extends ConsumerWidget {
  final String barcode;
  const _NutritionSheet({required this.barcode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(offDetailsProvider(barcode));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: details.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const _NutritionMessage(
            icon: Icons.error_outline,
            texte: 'Impossible de récupérer les informations pour le moment.',
          ),
          data: (produit) {
            if (produit == null || !produit.aDesInfos) {
              return const _NutritionMessage(
                icon: Icons.info_outline,
                texte: 'Aucune information nutritionnelle disponible pour ce produit.',
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Infos nutritionnelles',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                if (produit.nutriscore != null) ...[
                  Row(
                    children: [
                      _NutriscoreBadge(lettre: produit.nutriscore!),
                      const SizedBox(width: 10),
                      const Text('Nutri-Score', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                if (produit.quantite != null) ...[
                  Text('Quantité',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 2),
                  Text(produit.quantite!),
                  const SizedBox(height: 14),
                ],
                if (produit.ingredients != null) ...[
                  Text('Ingrédients',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 2),
                  Text(produit.ingredients!),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NutritionMessage extends StatelessWidget {
  final IconData icon;
  final String texte;
  const _NutritionMessage({required this.icon, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 10),
          Text(texte, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _NutriscoreBadge extends StatelessWidget {
  final String lettre;
  const _NutriscoreBadge({required this.lettre});

  static const _couleurs = {
    'a': Color(0xFF038141),
    'b': Color(0xFF85BB2F),
    'c': Color(0xFFFECB02),
    'd': Color(0xFFEE8100),
    'e': Color(0xFFE63E11),
  };

  @override
  Widget build(BuildContext context) {
    final couleur = _couleurs[lettre] ?? Colors.grey;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        lettre.toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Chip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
