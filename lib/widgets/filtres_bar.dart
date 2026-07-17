import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class FiltresBar extends ConsumerWidget {
  const FiltresBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catAsync = ref.watch(categoriesNotifierProvider);
    final rayAsync = ref.watch(rayonsNotifierProvider);
    final filterCat = ref.watch(filterCategorieProvider);
    final filterRay = ref.watch(filterRayonProvider);

    final categories = catAsync.valueOrNull ?? [];
    final rayons = rayAsync.valueOrNull ?? [];

    if (categories.isEmpty && rayons.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          // ── Catégories maison ──────────────────────────────
          ...categories.map((cat) {
            final selected = filterCat == cat.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(cat.nom,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? Color(cat.couleur) : null,
                    )),
                selected: selected,
                selectedColor: Color(cat.couleur).withValues(alpha: 0.2),
                side: selected
                    ? BorderSide(color: Color(cat.couleur), width: 1.5)
                    : null,
                onSelected: (v) {
                  ref.read(filterCategorieProvider.notifier).state =
                      v ? cat.id : null;
                },
                avatar: CircleAvatar(
                    backgroundColor: Color(cat.couleur), radius: 6),
                showCheckmark: false,
              ),
            );
          }),

          // Séparateur
          if (categories.isNotEmpty && rayons.isNotEmpty)
            Container(
              width: 1, height: 24,
              color: Theme.of(context).colorScheme.outline,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),

          // ── Rayons magasin avec couleur ────────────────────
          ...rayons.map((ray) {
            final selected = filterRay == ray.id;
            final couleur = Color(ray.couleur);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(ray.nom,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? couleur : null,
                    )),
                selected: selected,
                selectedColor: couleur.withValues(alpha: 0.2),
                side: selected
                    ? BorderSide(color: couleur, width: 1.5)
                    : null,
                onSelected: (v) {
                  ref.read(filterRayonProvider.notifier).state =
                      v ? ray.id : null;
                },
                avatar: CircleAvatar(backgroundColor: couleur, radius: 6),
                showCheckmark: false,
              ),
            );
          }),
        ],
      ),
    );
  }
}
