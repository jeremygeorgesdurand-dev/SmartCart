import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/erreur_utils.dart';

// ================================================================
// ÉCRAN CATÉGORIES MAISON
// ================================================================
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const _couleurs = [
    Colors.blue, Colors.cyan, Colors.green, Colors.purple,
    Colors.orange, Colors.grey, Colors.red, Colors.teal,
    Colors.pink, Colors.amber,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catAsync = ref.watch(categoriesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories maison'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text('Glissez pour réordonner', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      body: catAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(messageErreurLisible(e, 'Erreur'))),
        data: (cats) => Column(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                itemCount: cats.length,
                onReorderItem: (oldIndex, newIndex) {
                  final liste = [...cats];
                  final item = liste.removeAt(oldIndex);
                  liste.insert(newIndex, item);
                  ref.read(categoriesNotifierProvider.notifier).reordonner(liste);
                },
                itemBuilder: (_, i) {
                  final cat = cats[i];
                  return ListTile(
                    key: ValueKey(cat.id),
                    leading: CircleAvatar(
                      backgroundColor: Color(cat.couleur),
                      radius: 16,
                    ),
                    title: Text(cat.nom),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Modifier "${cat.nom}"',
                          onPressed: () =>
                              _editerCategorie(context, ref, cat),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error),
                          tooltip: 'Supprimer "${cat.nom}"',
                          onPressed: () {
                            final catSupprimee = cat;
                            ref
                                .read(categoriesNotifierProvider.notifier)
                                .supprimer(catSupprimee.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Catégorie "${catSupprimee.nom}" supprimée'),
                                action: SnackBarAction(
                                  label: 'Annuler',
                                  onPressed: () => ref
                                      .read(categoriesNotifierProvider.notifier)
                                      .ajouter(catSupprimee),
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                        ),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () => _editerCategorie(context, ref, null),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une catégorie'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editerCategorie(BuildContext context, WidgetRef ref, Categorie? existing) {
    final ctrl = TextEditingController(text: existing?.nom ?? '');
    int selectedColor = existing?.couleur ?? _couleurs[0].toARGB32();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Nouvelle catégorie' : 'Modifier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'Nom'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              const Text('Couleur'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _couleurs.asMap().entries.map((entry) {
                  final c = entry.value;
                  final selected = selectedColor == c.toARGB32();
                  return Semantics(
                    label: 'Couleur ${entry.key + 1}',
                    selected: selected,
                    button: true,
                    child: InkWell(
                      onTap: () => setState(() => selectedColor = c.toARGB32()),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: Colors.black, width: 2.5)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                final catAsync = ref.read(categoriesNotifierProvider);
                final ordre = catAsync.valueOrNull?.length ?? 0;
                final c = Categorie(
                  id: existing?.id ?? 'cat_${const Uuid().v4()}',
                  nom: ctrl.text.trim(),
                  couleur: selectedColor,
                  ordre: existing?.ordre ?? ordre,
                );
                if (existing == null) {
                  ref.read(categoriesNotifierProvider.notifier).ajouter(c);
                } else {
                  ref.read(categoriesNotifierProvider.notifier).modifier(c);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
