import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';

// ================================================================
// ÉCRAN RECETTES — liste, création, et génération de liste de courses
// ================================================================
class RecettesScreen extends ConsumerWidget {
  const RecettesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recettesAsync = ref.watch(recettesNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recettes')),
      body: recettesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (recettes) {
          if (recettes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('Aucune recette'),
                  const SizedBox(height: 8),
                  const Text('Crée une recette pour générer sa liste de courses'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: recettes.length,
            itemBuilder: (_, i) {
              final r = recettes[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(r.nom),
                  subtitle: Text(
                      '${r.ingredients.length} ingrédient(s) · ${r.portions} portions'),
                  onTap: () => _ouvrirDetail(context, ref, r),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      switch (action) {
                        case 'modifier':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RecetteFormScreen(recette: r)),
                          );
                        case 'supprimer':
                          ref.read(recettesNotifierProvider.notifier).supprimer(r.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                      PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecetteFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle recette'),
      ),
    );
  }

  void _ouvrirDetail(BuildContext context, WidgetRef ref, Recette r) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (_) => _RecetteDetailSheet(recette: r),
    );
  }
}

// ================================================================
// DÉTAIL D'UNE RECETTE + GÉNÉRER LA LISTE
// ================================================================
class _RecetteDetailSheet extends ConsumerWidget {
  final Recette recette;
  const _RecetteDetailSheet({required this.recette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recette.nom, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${recette.portions} portions',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final ing in recette.ingredients)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.circle, size: 8),
                    title: Text(ing.nom),
                    trailing: Text(ing.unite != null
                        ? '${ing.quantite} ${ing.unite}'
                        : '${ing.quantite}'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                try {
                  await ref
                      .read(recettesNotifierProvider.notifier)
                      .genererListe(recette);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Une erreur est survenue : $e')),
                    );
                  }
                  return;
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Liste "${recette.nom}" créée avec ${recette.ingredients.length} ingrédient(s)'),
                    backgroundColor: Colors.green,
                  ));
                }
              },
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('Générer une liste de courses'),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// FORMULAIRE CRÉATION / ÉDITION D'UNE RECETTE
// ================================================================
class RecetteFormScreen extends ConsumerStatefulWidget {
  final Recette? recette;
  const RecetteFormScreen({super.key, this.recette});

  @override
  ConsumerState<RecetteFormScreen> createState() => _RecetteFormScreenState();
}

class _RecetteFormScreenState extends ConsumerState<RecetteFormScreen> {
  late final TextEditingController _nomCtrl;
  late int _portions;
  late List<_LigneIngredient> _lignes;

  @override
  void initState() {
    super.initState();
    final r = widget.recette;
    _nomCtrl = TextEditingController(text: r?.nom ?? '');
    _portions = r?.portions ?? 4;
    _lignes = r != null && r.ingredients.isNotEmpty
        ? r.ingredients
            .map((i) => _LigneIngredient(
                nom: TextEditingController(text: i.nom),
                quantite: TextEditingController(text: '${i.quantite}'),
                unite: TextEditingController(text: i.unite ?? '')))
            .toList()
        : [_LigneIngredient.vide()];
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    for (final l in _lignes) {
      l.nom.dispose();
      l.quantite.dispose();
      l.unite.dispose();
    }
    super.dispose();
  }

  void _enregistrer() {
    final nom = _nomCtrl.text.trim();
    if (nom.isEmpty) return;

    final ingredients = _lignes
        .map((l) => (
              nom: l.nom.text.trim(),
              quantite: int.tryParse(l.quantite.text.trim()) ?? 1,
              unite: l.unite.text.trim(),
            ))
        .where((i) => i.nom.isNotEmpty)
        .map((i) => IngredientRecette(
            nom: i.nom, quantite: i.quantite, unite: i.unite.isEmpty ? null : i.unite))
        .toList();

    final recette = Recette(
      id: widget.recette?.id ?? 'recette_${DateTime.now().millisecondsSinceEpoch}',
      nom: nom,
      portions: _portions,
      ingredients: ingredients,
    );

    final notifier = ref.read(recettesNotifierProvider.notifier);
    if (widget.recette == null) {
      notifier.ajouter(recette);
    } else {
      notifier.modifier(recette);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recette == null ? 'Nouvelle recette' : 'Modifier la recette'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Enregistrer',
            onPressed: _enregistrer,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nomCtrl,
            decoration: const InputDecoration(labelText: 'Nom de la recette'),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 60,
          ),
          Row(
            children: [
              const Text('Portions : '),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _portions > 1
                    ? () => setState(() => _portions--)
                    : null,
              ),
              Text('$_portions', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _portions++),
              ),
            ],
          ),
          const Divider(),
          Text('Ingrédients', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < _lignes.length; i++) _buildLigne(i),
          TextButton.icon(
            onPressed: () => setState(() => _lignes.add(_LigneIngredient.vide())),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un ingrédient'),
          ),
        ],
      ),
    );
  }

  Widget _buildLigne(int i) {
    final ligne = _lignes[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: ligne.nom,
              decoration: const InputDecoration(hintText: 'Ingrédient', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ligne.quantite,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Qté', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ligne.unite,
              decoration: const InputDecoration(hintText: 'Unité', isDense: true),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _lignes.length > 1
                ? () => setState(() => _lignes.removeAt(i))
                : null,
          ),
        ],
      ),
    );
  }
}

class _LigneIngredient {
  final TextEditingController nom;
  final TextEditingController quantite;
  final TextEditingController unite;

  _LigneIngredient({required this.nom, required this.quantite, required this.unite});

  factory _LigneIngredient.vide() => _LigneIngredient(
        nom: TextEditingController(),
        quantite: TextEditingController(text: '1'),
        unite: TextEditingController(),
      );
}
