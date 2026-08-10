import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../providers/recettes_en_ligne_provider.dart';
import '../utils/erreur_utils.dart';
import '../utils/theme_utils.dart';

// ================================================================
// ÉCRAN SAUVEGARDE / RESTAURATION MANUELLE (fichier .json local)
// ================================================================
class SauvegardeScreen extends ConsumerStatefulWidget {
  const SauvegardeScreen({super.key});

  @override
  ConsumerState<SauvegardeScreen> createState() => _SauvegardeScreenState();
}

class _SauvegardeScreenState extends ConsumerState<SauvegardeScreen> {
  bool _enCours = false;
  bool _majRecettes = false;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde')),
      body: ListView(
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
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.restaurant_menu_outlined),
            title: const Text('Mettre à jour les recettes'),
            subtitle: const Text(
                'Télécharge la dernière version du catalogue de recettes'),
            trailing: _majRecettes
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _majRecettes ? null : _mettreAJourRecettes,
          ),
        ],
      ),
    );
  }

  Future<void> _mettreAJourRecettes() async {
    setState(() => _majRecettes = true);
    try {
      final n = await ref.read(recettesDatasetServiceProvider).mettreAJour();
      // Recharge les recettes affichées avec la nouvelle version.
      ref.invalidate(toutesRecettesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Recettes à jour ($n recettes)'),
        backgroundColor: couleurSucces(context),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreurLisible(e, 'Mise à jour impossible')),
      ));
    } finally {
      if (mounted) setState(() => _majRecettes = false);
    }
  }
}
