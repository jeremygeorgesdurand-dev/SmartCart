import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/version_info.dart';
import '../widgets/background_logo.dart';
import 'budget_screen.dart';
import 'compte_screen.dart';
import 'widget_config_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/providers.dart';

class ParametresScreen extends ConsumerWidget {
  const ParametresScreen({super.key});

  String _nomTheme(String c) {
    const noms = {
      'vert': 'Vert', 'vert_fonce': 'Vert foncé', 'teal': 'Teal', 'olive': 'Olive',
      'bleu': 'Bleu', 'bleu_clair': 'Bleu ciel', 'indigo': 'Indigo', 'cyan': 'Cyan',
      'orange': 'Orange', 'ambre': 'Ambre', 'rouge': 'Rouge', 'rose': 'Rose',
      'violet': 'Violet', 'brun': 'Brun', 'gris': 'Gris ardoise', 'noir': 'Sombre',
    };
    return noms[c] ?? c;
  }

  Color _couleurTheme(String c) {
    const couleurs = {
      'vert': Color(0xFF1ABC9C), 'vert_fonce': Color(0xFF2E7D32),
      'teal': Color(0xFF00695C), 'olive': Color(0xFF827717),
      'bleu': Color(0xFF1565C0), 'bleu_clair': Color(0xFF0288D1),
      'indigo': Color(0xFF283593), 'cyan': Color(0xFF00838F),
      'orange': Color(0xFFE65100), 'ambre': Color(0xFFFF6F00),
      'rouge': Color(0xFFC62828), 'rose': Color(0xFFAD1457),
      'violet': Color(0xFF6A1B9A), 'brun': Color(0xFF4E342E),
      'gris': Color(0xFF455A64), 'noir': Color(0xFF212121),
    };
    return couleurs[c] ?? const Color(0xFF1ABC9C);
  }

  String _nomModeTheme(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Clair';
      case ThemeMode.dark: return 'Sombre';
      case ThemeMode.system: return 'Système';
    }
  }

  Future<void> _choisirModeTheme(BuildContext context, WidgetRef ref) async {
    final actuel = ref.read(themeModeProvider);
    Future<void> selectionner(BuildContext dialogCtx, ThemeMode v) async {
      ref.read(themeModeProvider.notifier).state = v;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', switch (v) {
        ThemeMode.light => 'clair',
        ThemeMode.dark => 'sombre',
        ThemeMode.system => 'systeme',
      });
      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Apparence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(_nomModeTheme(mode)),
                leading: Icon(actuel == mode
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                onTap: () => selectionner(dialogCtx, mode),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _choisirTheme(BuildContext context, WidgetRef ref) async {
    final themes = [
      ('vert', 'Vert', const Color(0xFF1ABC9C)),
      ('vert_fonce', 'Vert foncé', const Color(0xFF2E7D32)),
      ('teal', 'Teal', const Color(0xFF00695C)),
      ('olive', 'Olive', const Color(0xFF827717)),
      ('bleu', 'Bleu', const Color(0xFF1565C0)),
      ('bleu_clair', 'Bleu ciel', const Color(0xFF0288D1)),
      ('indigo', 'Indigo', const Color(0xFF283593)),
      ('cyan', 'Cyan', const Color(0xFF00838F)),
      ('orange', 'Orange', const Color(0xFFE65100)),
      ('ambre', 'Ambre', const Color(0xFFFF6F00)),
      ('rouge', 'Rouge', const Color(0xFFC62828)),
      ('rose', 'Rose', const Color(0xFFAD1457)),
      ('violet', 'Violet', const Color(0xFF6A1B9A)),
      ('brun', 'Brun', const Color(0xFF4E342E)),
      ('gris', 'Gris ardoise', const Color(0xFF455A64)),
      ('noir', 'Sombre', const Color(0xFF212121)),
    ];

    final actuel = ref.read(couleurThemeProvider);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Choisir un theme'),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: themes.map((t) {
              final (id, nom, couleur) = t;
              final selected = actuel == id;
              return GestureDetector(
                onTap: () async {
                  ref.read(couleurThemeProvider.notifier).state = id;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('couleur_theme', id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: couleur,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3)
                            : null,
                        boxShadow: selected
                            ? [BoxShadow(
                                color: couleur.withValues(alpha: 0.5),
                                blurRadius: 8, spreadRadius: 2)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 24)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(nom, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final afficherStats = ref.watch(afficherStatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Parametres')),
      body: ListView(
        children: [
          // ── Compte Google ─────────────────────────────────
          const _SectionCompte(),
          const Divider(),
          // Widget
          _SectionWidget(),
          const Divider(),
          // Budget
          const _SectionBudget(),
          const Divider(),
          // Preferences
          const _Section(titre: 'Preferences', child: SizedBox.shrink()),
          SwitchListTile(
            title: const Text('Afficher les statistiques'),
            subtitle: const Text('Onglet Stats dans la navigation'),
            value: afficherStats,
            onChanged: (v) async {
              ref.read(afficherStatsProvider.notifier).state = v;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('afficher_stats', v);
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Theme de couleur'),
            subtitle: Text(_nomTheme(ref.watch(couleurThemeProvider))),
            leading: CircleAvatar(
              backgroundColor: _couleurTheme(ref.watch(couleurThemeProvider)),
              radius: 14,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _choisirTheme(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Apparence'),
            subtitle: Text(_nomModeTheme(ref.watch(themeModeProvider))),
            leading: const Icon(Icons.brightness_6_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _choisirModeTheme(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Taille du texte'),
            subtitle: Slider(
              value: ref.watch(tailleTexteProvider),
              min: 0.85,
              max: 1.3,
              divisions: 9,
              label: '${(ref.watch(tailleTexteProvider) * 100).round()} %',
              onChanged: (v) =>
                  ref.read(tailleTexteProvider.notifier).state = v,
              onChangeEnd: (v) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('taille_texte', v);
              },
            ),
            leading: const Icon(Icons.text_fields),
          ),
          const Divider(),
          const _Section(titre: 'Categories maison', child: _CategoriesManager()),
          const Divider(),
          const _Section(titre: 'Rayons magasin', child: _RayonsManager()),
          const SectionFondLogo(),
          const _SectionSauvegarde(),
          const SectionAPropos(),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titre;
  final Widget child;
  const _Section({required this.titre, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Text(titre,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      )),
              const Spacer(),
              const Text('Glissez pour réordonner',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

// ================================================================
// GESTIONNAIRE DE CATÉGORIES
// ================================================================
class _CategoriesManager extends ConsumerWidget {
  const _CategoriesManager();

  static const _couleurs = [
    Colors.blue, Colors.cyan, Colors.green, Colors.purple,
    Colors.orange, Colors.grey, Colors.red, Colors.teal,
    Colors.pink, Colors.amber,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catAsync = ref.watch(categoriesNotifierProvider);

    return catAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (cats) => Column(
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
                children: _couleurs.map((c) {
                  final selected = selectedColor == c.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = c.toARGB32()),
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

// ================================================================
// GESTIONNAIRE DE RAYONS
// ================================================================
class _RayonsManager extends ConsumerWidget {
  const _RayonsManager();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rayAsync = ref.watch(rayonsNotifierProvider);

    return rayAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (rayons) => Column(
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
    );
  }

  static const _couleursRayon = [
    Colors.green, Colors.red, Colors.blue, Colors.orange,
    Colors.cyan, Colors.purple, Colors.blueGrey, Colors.teal,
    Colors.pink, Colors.amber, Colors.indigo, Colors.brown,
  ];

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
                children: _couleursRayon.map((c) {
                  final selected = selectedColor == c.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = c.toARGB32()),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: selected ? Border.all(color: Colors.black, width: 2.5) : null,
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


// ================================================================
// SECTION SAUVEGARDE / RESTAURATION MANUELLE
// ================================================================
class _SectionSauvegarde extends ConsumerStatefulWidget {
  const _SectionSauvegarde();

  @override
  ConsumerState<_SectionSauvegarde> createState() => _SectionSauvegardeState();
}

class _SectionSauvegardeState extends ConsumerState<_SectionSauvegarde> {
  bool _enCours = false;

  Future<void> _exporter() async {
    setState(() => _enCours = true);
    try {
      await ref.read(backupServiceProvider).exporter();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la sauvegarde : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _restaurer() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || !mounted) return;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: const Text(
            'Les catégories, rayons, articles, listes et prix du fichier '
            'seront ajoutés/mis à jour dans SmartCart. Rien ne sera '
            'supprimé de ce qui existe déjà.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() => _enCours = true);
    try {
      final contenu = String.fromCharCodes(bytes);
      final res = await ref.read(backupServiceProvider).restaurer(contenu);

      ref.invalidate(categoriesNotifierProvider);
      ref.invalidate(rayonsNotifierProvider);
      ref.invalidate(articlesNotifierProvider);
      ref.invalidate(listesNotifierProvider);
      ref.invalidate(prixArticlesNotifierProvider);
      ref.invalidate(recettesNotifierProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sauvegarde restaurée : ${res.total} éléments')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la restauration : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      titre: 'Sauvegarde',
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Exporter une sauvegarde'),
            subtitle: const Text('Catégories, rayons, articles, listes, prix'),
            trailing: _enCours
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _enCours ? null : _exporter,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Restaurer une sauvegarde'),
            subtitle: const Text('Depuis un fichier .json exporté'),
            onTap: _enCours ? null : _restaurer,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SECTION FOND LOGO
// ================================================================
class SectionFondLogo extends ConsumerWidget {
  const SectionFondLogo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actif = ref.watch(fondActiveProvider);
    final opacite = ref.watch(fondOpaciteProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Fond personnalisé',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Logo en arrière-plan'),
                subtitle: const Text('Affiche le logo SmartCart en filigrane'),
                value: actif,
                onChanged: (v) async {
                  ref.read(fondActiveProvider.notifier).state = v;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('fond_actif', v);
                },
              ),
              if (actif) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Opacité',
                              style: Theme.of(context).textTheme.bodyMedium),
                          Text('${(opacite * 100).toInt()}%',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context).colorScheme.primary)),
                        ],
                      ),
                      Slider(
                        value: opacite,
                        min: 0.02,
                        max: 0.20,
                        divisions: 18,
                        onChanged: (v) async {
                          ref.read(fondOpaciteProvider.notifier).state = v;
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setDouble('fond_opacite', v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SECTION À PROPOS
// ================================================================
class SectionAPropos extends StatelessWidget {
  const SectionAPropos({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('À propos',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Version actuelle'),
                trailing: Text(
                  'v${VersionInfo.version} (build ${VersionInfo.buildNumber})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Dernière mise à jour'),
                trailing: Text(
                  VersionInfo.dateMiseAJour,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Historique des versions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const _HistoriqueVersionsDialog(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _HistoriqueVersionsDialog extends StatelessWidget {
  const _HistoriqueVersionsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historique des versions',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: VersionInfo.historique.map((release) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v${release.version}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(release.date,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...release.changements.map((c) => Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('• ',
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary)),
                                  Expanded(
                                      child: Text(c,
                                          style: const TextStyle(fontSize: 13))),
                                ],
                              ),
                            )),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SECTION COMPTE GOOGLE
// ================================================================
class _SectionCompte extends ConsumerWidget {
  const _SectionCompte();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final user = authAsync.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Compte',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: ListTile(
            leading: user?.photoURL != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(user!.photoURL!),
                    radius: 20,
                  )
                : CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      user != null ? Icons.person : Icons.account_circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
            title: Text(
              user != null
                  ? (user.displayName ?? 'Compte connecté')
                  : 'Se connecter',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              user != null
                  ? (user.email ?? 'Synchronisation active')
                  : 'Sauvegarder vos données sur le cloud',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: user != null
                ? const Icon(Icons.cloud_done, color: Colors.green)
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompteScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SECTION WIDGET
// ================================================================
class _SectionWidget extends StatelessWidget {
  const _SectionWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Widget écran d\'accueil',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF006B5E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.widgets, color: Colors.white, size: 22),
            ),
            title: const Text('Configurer le widget',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Afficher une liste sur l\'écran d\'accueil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WidgetConfigScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SECTION BUDGET
// ================================================================
class _SectionBudget extends StatelessWidget {
  const _SectionBudget();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Budget',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF006B5E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.euro, color: Colors.white, size: 22),
            ),
            title: const Text('Prix et budget',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Suivre le coût estimé de vos listes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetScreen()),
            ),
          ),
        ),
      ],
    );
  }
}
