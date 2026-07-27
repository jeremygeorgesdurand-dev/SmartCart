import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../utils/theme_utils.dart';
import 'a_propos_screen.dart';
import 'apparence_screen.dart';
import 'categories_screen.dart';
import 'compte_screen.dart';
import 'fonctionnalites_screen.dart';
import 'rayons_screen.dart';
import 'sauvegarde_screen.dart';
import 'widget_config_screen.dart';

// ================================================================
// ÉCRAN PARAMÈTRES — menu principal : chaque ligne ouvre son propre
// sous-écran plutôt que d'empiler tous les réglages sur une seule
// page à faire défiler.
// ================================================================
class ParametresScreen extends ConsumerWidget {
  const ParametresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _SectionCompte(),
          const Divider(),

          const _SectionTitre(titre: 'Apparence'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: _MenuTile(
              icone: Icons.palette_outlined,
              titre: 'Thème, mode et taille du texte',
              sousTitre: 'Couleur, clair/sombre, fond personnalisé',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ApparenceScreen())),
            ),
          ),
          const Divider(),

          const _SectionTitre(titre: 'Organisation'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                _MenuTile(
                  icone: Icons.home_outlined,
                  titre: 'Catégories maison',
                  sousTitre: 'Regrouper les articles par pièce/usage',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                ),
                const Divider(height: 1),
                _MenuTile(
                  icone: Icons.store_outlined,
                  titre: 'Rayons magasin',
                  sousTitre: 'Ordre des rayons pour les courses',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RayonsScreen())),
                ),
              ],
            ),
          ),
          const Divider(),

          const _SectionTitre(titre: 'Fonctionnalités'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                _MenuTile(
                  icone: Icons.view_list_outlined,
                  titre: 'Onglets affichés',
                  sousTitre: 'Statistiques, budget, prix',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const FonctionnalitesScreen())),
                ),
                const Divider(height: 1),
                _MenuTile(
                  icone: Icons.widgets_outlined,
                  titre: 'Widget écran d\'accueil',
                  sousTitre: 'Afficher une liste sur l\'écran d\'accueil',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const WidgetConfigScreen())),
                ),
              ],
            ),
          ),
          const Divider(),

          const _SectionTitre(titre: 'Données'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: _MenuTile(
              icone: Icons.save_outlined,
              titre: 'Sauvegarde',
              sousTitre: 'Exporter/restaurer un fichier local',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SauvegardeScreen())),
            ),
          ),
          const Divider(),

          const _SectionTitre(titre: 'À propos'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: _MenuTile(
              icone: Icons.info_outline,
              titre: 'À propos',
              sousTitre: 'Version et historique des mises à jour',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AProposScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitre extends StatelessWidget {
  final String titre;
  const _SectionTitre({required this.titre});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(titre,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              )),
    );
  }
}

// Ligne de menu générique : icône dans un badge de couleur, titre,
// sous-titre, chevron — utilisée par toutes les entrées qui ouvrent
// un sous-écran de paramètres.
class _MenuTile extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String sousTitre;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icone,
            color: texteContrastant(Theme.of(context).colorScheme.primary),
            size: 22),
      ),
      title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(sousTitre),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
        const _SectionTitre(titre: 'Compte'),
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
                ? Icon(Icons.cloud_done, color: couleurSucces(context))
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
