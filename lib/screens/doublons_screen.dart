import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/theme_utils.dart';

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
    final categories = ref.watch(categoriesNotifierProvider).valueOrNull ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '${articles.length} articles similaires — gardez-en un',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
            for (final a in articles)
              ListTile(
                dense: true,
                title: Text(a.nom),
                // La catégorie (couleur + nom) et la marque distinguent des
                // articles au nom proche mais bien différents (« Pâtes » en
                // Épicerie vs « Paté » au Frigo) : de quoi décider lesquels
                // sont vraiment des doublons avant d'en supprimer.
                subtitle: _sousTitre(context, a, categories),
                // Un seul geste par choix : « Garder » supprime tous les autres
                // du groupe d'un coup ; la corbeille supprime juste celui-ci.
                // Pas de dialogue de confirmation — une action Annuler dans le
                // message suffit et va beaucoup plus vite.
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (articles.length > 2)
                      TextButton(
                        onPressed: () => _garderSeulement(context, ref, a),
                        child: const Text('Garder'),
                      ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: couleurDanger(context)),
                      tooltip: 'Supprimer cet article',
                      onPressed: () => _supprimer(context, ref, [a],
                          '"${a.nom}" supprimé'),
                    ),
                  ],
                ),
              ),
            if (articles.length == 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.merge_type, size: 18),
                    label: Text('Garder « ${articles.first.nom} »'),
                    onPressed: () =>
                        _garderSeulement(context, ref, articles.first),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Pastille de catégorie (couleur + nom) puis marque. null si l'article n'a
  // ni catégorie ni marque.
  Widget? _sousTitre(
      BuildContext context, Article a, List<Categorie> categories) {
    final cat = a.categorieId == null
        ? null
        : categories.where((c) => c.id == a.categorieId).firstOrNull;
    if (cat == null && a.marque == null) return null;
    return Row(
      children: [
        if (cat != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: Color(cat.couleur), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(cat.nom, overflow: TextOverflow.ellipsis)),
        ],
        if (cat != null && a.marque != null) const Text(' · '),
        if (a.marque != null)
          Flexible(child: Text(a.marque!, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  void _garderSeulement(BuildContext context, WidgetRef ref, Article garde) {
    final aSupprimer = articles.where((a) => a.id != garde.id).toList();
    _supprimer(context, ref, aSupprimer,
        '${aSupprimer.length} doublon(s) supprimé(s), « ${garde.nom} » conservé');
  }

  // Supprime la liste d'articles et propose de tout annuler via le SnackBar,
  // en réinsérant les articles supprimés tels quels (mêmes id).
  void _supprimer(BuildContext context, WidgetRef ref, List<Article> articles,
      String message) {
    final notifier = ref.read(articlesNotifierProvider.notifier);
    for (final a in articles) {
      notifier.supprimer(a.id);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            for (final a in articles) {
              notifier.ajouter(a);
            }
          },
        ),
      ));
  }
}
