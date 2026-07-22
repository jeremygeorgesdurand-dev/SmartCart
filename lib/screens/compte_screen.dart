import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

// Message lisible à partir d'une erreur réseau/Firebase, plutôt que
// d'afficher tel quel un `Exception: ...` technique à l'utilisateur.
String _messageErreur(Object e, String contexte) {
  if (e is SocketException ||
      (e is FirebaseException &&
          (e.code == 'unavailable' || e.code == 'network-request-failed'))) {
    return 'Pas de connexion internet. Réessaie plus tard.';
  }
  if (e is FirebaseException) {
    return '$contexte : ${e.message ?? e.code}';
  }
  return '$contexte : $e';
}

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
        if (!mounted) return;
        setState(() { _syncing = false; _message = 'Connexion annulée'; _messageOk = false; });
        return;
      }
      // Se connecter ne synchronise plus AUCUNE donnée automatiquement : en
      // changeant de compte sur le même appareil sans avoir vidé la base
      // locale au préalable, un download+upload automatique mélangeait
      // silencieusement les données du compte précédent dans le nouveau
      // (et vice-versa), les deux comptes finissant avec le même contenu.
      // La synchro reste disponible, mais seulement via les boutons
      // "Sauvegarder maintenant"/"Restaurer depuis le cloud" ci-dessous,
      // que l'utilisateur déclenche lui-même en connaissance de cause.
      await ref.read(syncServiceProvider).publierProfil();
      // Notifications push : best-effort, un refus ne doit pas bloquer
      // la connexion.
      try {
        final token = await ref
            .read(fcmServiceProvider)
            .demanderPermissionEtObtenirToken();
        if (token != null) {
          await ref.read(syncServiceProvider).enregistrerTokenFcm(token);
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _message = 'Connecté ! Utilisez "Sauvegarder" ou "Restaurer" '
            'ci-dessous pour synchroniser vos données.';
        _messageOk = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _message = _messageErreur(e, 'Erreur de connexion');
        _messageOk = false;
      });
    }
  }

  Future<void> _deconnecter() async {
    // Retirer le token AVANT de se déconnecter : après, on n'est plus
    // authentifié pour écrire dans users/{uid}.
    try {
      final token = await ref.read(fcmServiceProvider).tokenActuel;
      if (token != null) {
        await ref.read(syncServiceProvider).supprimerTokenFcm(token);
      }
    } catch (_) {}
    await ref.read(authServiceProvider).deconnecter();
    if (!mounted) return;
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
      if (!mounted) return;
      setState(() { _syncing = false; _message = 'Synchronisation réussie !'; _messageOk = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _syncing = false; _message = _messageErreur(e, 'Erreur sync'); _messageOk = false; });
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
      if (!mounted) return;
      setState(() { _syncing = false; _message = 'Données restaurées depuis le cloud !'; _messageOk = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _syncing = false; _message = _messageErreur(e, 'Erreur restauration'); _messageOk = false; });
    }
  }

  Future<void> _supprimerCompte() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: const Text(
          'Toutes vos données cloud seront définitivement supprimées '
          '(catalogue, listes, prix). Vous quitterez aussi vos listes '
          'collaboratives. Vos données locales sur cet appareil restent '
          'intactes. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogCtx).colorScheme.error),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() { _syncing = true; _message = null; });
    try {
      await ref.read(syncServiceProvider).supprimerToutesLesDonneesCloud();
      await ref.read(authServiceProvider).supprimerCompte();
      if (!mounted) return;
      setState(() { _syncing = false; _message = 'Compte supprimé'; _messageOk = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _syncing = false; _message = _messageErreur(e, 'Erreur suppression'); _messageOk = false; });
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
                      const _IndicateurSynchro(),
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
              TextButton.icon(
                onPressed: _syncing ? null : _supprimerCompte,
                icon: Icon(Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error),
                label: Text('Supprimer mon compte',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
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

// ── Indicateur d'état de synchro ─────────────────────────────────
// S'appuie sur snapshotsInSync() : émet un événement à chaque fois que
// le cache local Firestore est à jour avec le serveur (écritures
// confirmées comprises). Entre deux événements, on considère qu'une
// synchro est en cours.
class _IndicateurSynchro extends StatefulWidget {
  const _IndicateurSynchro();

  @override
  State<_IndicateurSynchro> createState() => _IndicateurSynchroState();
}

class _IndicateurSynchroState extends State<_IndicateurSynchro> {
  bool _synchronise = true;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance.snapshotsInSync().listen((_) {
      if (mounted) setState(() => _synchronise = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final couleur = _synchronise ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_synchronise ? Icons.cloud_done : Icons.cloud_sync,
              color: couleur, size: 16),
          const SizedBox(width: 6),
          Text(
            _synchronise ? 'Synchronisation active' : 'Synchronisation...',
            style: TextStyle(
                color: couleur, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
