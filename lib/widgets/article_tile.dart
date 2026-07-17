import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
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
      onDismissed: (_) =>
          ref.read(articlesNotifierProvider.notifier).supprimer(article.id),
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
