import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../utils/theme_utils.dart';

// Affichage SÉPARÉ et en lecture seule d'un catalogue SUIVI (partage temps
// réel). Ses articles/catégories ne se mélangent pas au catalogue perso : on
// peut les consulter, tout copier dans le sien, ou arrêter de suivre.
class CatalogueSuiviScreen extends ConsumerWidget {
  final String catalogueId;
  final String nom;
  const CatalogueSuiviScreen(
      {super.key, required this.catalogueId, required this.nom});

  Future<void> _toutAjouter(BuildContext context, WidgetRef ref) async {
    final db = ref.read(dbServiceProvider);
    final res = await ref.read(backupServiceProvider).fusionnerCatalogue(
          categories: await db.getCategoriesParSource(catalogueId),
          rayons: await db.getRayonsParSource(catalogueId),
          articles: await db.getArticlesParSource(catalogueId),
        );
    ref.invalidate(articlesNotifierProvider);
    ref.invalidate(categoriesNotifierProvider);
    ref.invalidate(rayonsNotifierProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Ajouté à ton catalogue : ${res.articles} article(s), '
          '${res.categories} catégorie(s)'),
      backgroundColor: couleurSucces(context),
    ));
  }

  Future<void> _arreter(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Arrêter de suivre ?'),
        content: Text('« $nom » sera retiré de tes catalogues suivis. Ton '
            'catalogue personnel n\'est pas touché.'),
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
    await ref.read(syncServiceProvider).arreterDeSuivreCatalogue(catalogueId);
    ref.invalidate(cataloguesSuivisProvider);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contenuAsync = ref.watch(contenuCatalogueSuiviProvider(catalogueId));
    return Scaffold(
      appBar: AppBar(
        title: Text(nom),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'arreter') _arreter(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'arreter', child: Text('Arrêter de suivre')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _toutAjouter(context, ref),
        icon: const Icon(Icons.library_add_outlined),
        label: const Text('Tout ajouter à mon catalogue'),
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
          // Groupe les articles par catégorie (du catalogue suivi).
          final groupes = <String, List<String>>{};
          for (final a in contenu.articles) {
            final cle = a.categorieId ?? '__aucune__';
            groupes.putIfAbsent(cle, () => []).add(a.nom);
          }
          final cles = groupes.keys.toList()
            ..sort((x, y) {
              if (x == '__aucune__') return 1;
              if (y == '__aucune__') return -1;
              return (catParId[x]?.ordre ?? 99)
                  .compareTo(catParId[y]?.ordre ?? 99);
            });
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
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
                for (final nom in groupes[cle]!)
                  ListTile(
                    dense: true,
                    title: Text(nom),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
