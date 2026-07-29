import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/erreur_utils.dart';

// ================================================================
// ÉCRAN RAYONS MAGASIN
// ================================================================
class RayonsScreen extends ConsumerWidget {
  const RayonsScreen({super.key});

  static const _couleursRayon = [
    Colors.green, Colors.red, Colors.blue, Colors.orange,
    Colors.cyan, Colors.purple, Colors.blueGrey, Colors.teal,
    Colors.pink, Colors.amber, Colors.indigo, Colors.brown,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rayAsync = ref.watch(rayonsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rayons magasin'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text('Glissez pour réordonner', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      body: rayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(messageErreurLisible(e, 'Erreur'))),
        data: (rayons) => Column(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                itemCount: rayons.length,
                onReorderItem: (oldIndex, newIndex) {
                  final liste = [...rayons];
                  final item = liste.removeAt(oldIndex);
                  liste.insert(newIndex, item);
                  ref.read(rayonsNotifierProvider.notifier).reordonner(liste);
                },
                itemBuilder: (_, i) {
                  final rayon = rayons[i];
                  return ListTile(
                    key: ValueKey(rayon.id),
                    leading: CircleAvatar(
                      backgroundColor: Color(rayon.couleur),
                      radius: 16,
                      child: Text(
                        '${rayon.ordre + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(rayon.nom),
                    subtitle: rayon.magasin != null ? Text(rayon.magasin!) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Modifier "${rayon.nom}"',
                          onPressed: () => _editerRayon(context, ref, rayon),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error),
                          tooltip: 'Supprimer "${rayon.nom}"',
                          onPressed: () {
                            final rayonSupprime = rayon;
                            ref
                                .read(rayonsNotifierProvider.notifier)
                                .supprimer(rayonSupprime.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Rayon "${rayonSupprime.nom}" supprimé'),
                                action: SnackBarAction(
                                  label: 'Annuler',
                                  onPressed: () => ref
                                      .read(rayonsNotifierProvider.notifier)
                                      .ajouter(rayonSupprime),
                                ),
                                duration: const Duration(seconds: 3),
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
                onPressed: () => _editerRayon(context, ref, null),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un rayon'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editerRayon(BuildContext context, WidgetRef ref, Rayon? existing) {
    final ctrlNom = TextEditingController(text: existing?.nom ?? '');
    final ctrlMagasin = TextEditingController(text: existing?.magasin ?? '');
    int selectedColor = existing?.couleur ?? _couleursRayon[6].toARGB32();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Nouveau rayon' : 'Modifier le rayon'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlNom,
                decoration: const InputDecoration(labelText: 'Nom du rayon'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlMagasin,
                decoration: const InputDecoration(
                  labelText: 'Magasin (optionnel)',
                  hintText: 'ex: Carrefour, Leclerc...',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Couleur')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _couleursRayon.asMap().entries.map((entry) {
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
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: c, shape: BoxShape.circle,
                            border: selected ? Border.all(color: Colors.black, width: 2.5) : null,
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
                if (ctrlNom.text.trim().isEmpty) return;
                final rayAsync = ref.read(rayonsNotifierProvider);
                final ordre = rayAsync.valueOrNull?.length ?? 0;
                final r = Rayon(
                  id: existing?.id ?? 'ray_${const Uuid().v4()}',
                  nom: ctrlNom.text.trim(),
                  ordre: existing?.ordre ?? ordre,
                  couleur: selectedColor,
                  magasin: ctrlMagasin.text.trim().isEmpty
                      ? null
                      : ctrlMagasin.text.trim(),
                );
                if (existing == null) {
                  ref.read(rayonsNotifierProvider.notifier).ajouter(r);
                } else {
                  ref.read(rayonsNotifierProvider.notifier).modifier(r);
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
