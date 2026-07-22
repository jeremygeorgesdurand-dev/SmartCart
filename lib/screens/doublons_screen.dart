import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';

// Signale les articles du catalogue qui semblent être des doublons (même
// nom, ou noms très proches) pour que l'utilisateur puisse nettoyer
// facilement les entrées créées séparément (scan, dictée, saisie manuelle).
class DoublonsScreen extends ConsumerWidget {
  const DoublonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupes = ref.watch(doublonsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Doublons du catalogue')),
      body: groupes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('Aucun doublon détecté'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: groupes.length,
              itemBuilder: (_, i) => _GroupeCard(articles: groupes[i]),
            ),
    );
  }
}

class _GroupeCard extends ConsumerWidget {
  final List<Article> articles;
  const _GroupeCard({required this.articles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                '${articles.length} articles similaires',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
            for (final a in articles)
              ListTile(
                dense: true,
                title: Text(a.nom),
                subtitle: a.marque != null ? Text(a.marque!) : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Supprimer cet article du catalogue',
                  onPressed: () => _confirmerSuppression(context, ref, a),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmerSuppression(BuildContext context, WidgetRef ref, Article a) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text(
            'Supprimer "${a.nom}" du catalogue ? Il sera aussi retiré des listes où il apparaît.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(articlesNotifierProvider.notifier).supprimer(a.id);
              Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
