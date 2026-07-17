import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class CompteScreen extends ConsumerStatefulWidget {
  const CompteScreen({super.key});

  @override
  ConsumerState<CompteScreen> createState() => _CompteScreenState();
}

class _CompteScreenState extends ConsumerState<CompteScreen> {
  bool _syncing = false;
  String? _message;
  bool _messageOk = true;

  Future<void> _connecter() async {
    setState(() { _syncing = true; _message = null; });
    try {
      final user = await ref.read(authServiceProvider).connecterGoogle();
      if (user == null) {
        setState(() { _syncing = false; _message = 'Connexion annulée'; _messageOk = false; });
        return;
      }
      // Upload des données locales vers Firebase
      await ref.read(syncServiceProvider).uploadTout();
      setState(() {
        _syncing = false;
        _message = 'Connecté et données sauvegardées !';
        _messageOk = true;
      });
    } catch (e) {
      setState(() {
        _syncing = false;
        _message = 'Erreur : $e';
        _messageOk = false;
      });
    }
  }

  Future<void> _deconnecter() async {
    await ref.read(authServiceProvider).deconnecter();
    setState(() { _message = 'Déconnecté'; _messageOk = true; });
  }

  Future<void> _syncManuel() async {
    setState(() { _syncing = true; _message = null; });
    try {
      await ref.read(syncServiceProvider).uploadTout();
      // Invalider tous les providers pour rafraîchir l'UI
      ref.invalidate(articlesNotifierProvider);
      ref.invalidate(listesNotifierProvider);
      ref.invalidate(categoriesNotifierProvider);
      ref.invalidate(rayonsNotifierProvider);
      setState(() { _syncing = false; _message = 'Synchronisation réussie !'; _messageOk = true; });
    } catch (e) {
      setState(() { _syncing = false; _message = 'Erreur sync : $e'; _messageOk = false; });
    }
  }

  Future<void> _restaurer() async {
    setState(() { _syncing = true; _message = null; });
    try {
      await ref.read(syncServiceProvider).downloadTout();
      ref.invalidate(articlesNotifierProvider);
      ref.invalidate(listesNotifierProvider);
      ref.invalidate(categoriesNotifierProvider);
      ref.invalidate(rayonsNotifierProvider);
      setState(() { _syncing = false; _message = 'Données restaurées depuis le cloud !'; _messageOk = true; });
    } catch (e) {
      setState(() { _syncing = false; _message = 'Erreur restauration : $e'; _messageOk = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Compte & Sauvegarde')),
      body: authAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (user) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Carte statut compte ──────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (user != null) ...[
                      // Connecté
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: user.photoURL != null
                            ? NetworkImage(user.photoURL!)
                            : null,
                        child: user.photoURL == null
                            ? Text(
                                user.displayName?.substring(0, 1).toUpperCase() ?? '?',
                                style: const TextStyle(fontSize: 28),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.displayName ?? 'Utilisateur',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_done, color: Colors.green, size: 16),
                            SizedBox(width: 6),
                            Text('Synchronisation active',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Non connecté
                      Icon(Icons.account_circle_outlined,
                          size: 72,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(
                        'Non connecté',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connectez-vous pour sauvegarder vos données\net y accéder sur tous vos appareils.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Message feedback ─────────────────────────────
            if (_message != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_messageOk ? Colors.green : Colors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_messageOk ? Colors.green : Colors.red)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _messageOk ? Icons.check_circle : Icons.error,
                      color: _messageOk ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_message!)),
                  ],
                ),
              ),

            // ── Actions ──────────────────────────────────────
            if (user == null) ...[
              FilledButton.icon(
                onPressed: _syncing ? null : _connecter,
                icon: _syncing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login),
                label: Text(_syncing ? 'Connexion...' : 'Se connecter avec Google'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ] else ...[
              // Sync manuel
              OutlinedButton.icon(
                onPressed: _syncing ? null : _syncManuel,
                icon: _syncing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload),
                label: Text(_syncing ? 'Sauvegarde...' : 'Sauvegarder maintenant'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 10),
              // Restaurer depuis cloud
              OutlinedButton.icon(
                onPressed: _syncing ? null : _restaurer,
                icon: const Icon(Icons.cloud_download),
                label: const Text('Restaurer depuis le cloud'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              // Déconnexion
              TextButton.icon(
                onPressed: _deconnecter,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Se déconnecter',
                    style: TextStyle(color: Colors.red)),
              ),
            ],

            const SizedBox(height: 24),

            // ── Info sur ce qui est sauvegardé ───────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ce qui est sauvegardé',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 10),
                    ...[
                      (Icons.inventory_2, 'Catalogue d\'articles'),
                      (Icons.shopping_cart, 'Listes de courses'),
                      (Icons.home, 'Catégories maison'),
                      (Icons.store, 'Rayons magasin'),
                      (Icons.settings, 'Paramètres de l\'app'),
                    ].map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(item.$1,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 10),
                              Text(item.$2),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
