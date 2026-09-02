import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/erreur_utils.dart';
import '../utils/messages.dart';
import '../utils/theme_utils.dart';
import 'rayons_screen.dart';

// Profils magasin : chaque profil a SON organisation de rayons (ordre + couleurs
// + affectation des articles) et une liste associée. Le profil actif est celui
// reflété « en direct » dans l'app. On peut créer/activer/renommer/supprimer un
// profil, lier une liste, et partager/suivre un profil (QR ou code).
class ProfilsScreen extends ConsumerWidget {
  const ProfilsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilsAsync = ref.watch(profilsNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profils magasin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Suivre un profil partagé',
            onPressed: () => _suivreProfil(context, ref),
          ),
        ],
      ),
      body: profilsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(messageErreurLisible(e, 'Erreur'))),
        data: (profils) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Un profil enregistre l\'ordre et les couleurs de tes rayons, '
                  'l\'aisle de chaque article et une liste associée — un par '
                  'magasin. Choisis-en un pour l\'appliquer partout.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline),
                ),
              ),
              for (final p in profils) _tuileProfil(context, ref, p, profils),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _creerProfil(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau profil'),
      ),
    );
  }

  Widget _tuileProfil(
      BuildContext context, WidgetRef ref, Profil p, List<Profil> tous) {
    final listesAsync = ref.watch(listesNotifierProvider);
    final listeNom = p.listeId == null
        ? null
        : listesAsync.valueOrNull
            ?.where((l) => l.id == p.listeId)
            .firstOrNull
            ?.nom;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          p.actif ? Icons.check_circle : Icons.storefront_outlined,
          color: p.actif
              ? couleurSucces(context)
              : Theme.of(context).colorScheme.outline,
        ),
        title: Text(p.nom,
            style: TextStyle(
                fontWeight: p.actif ? FontWeight.bold : FontWeight.w500)),
        subtitle: Text([
          if (p.actif) 'Profil actif' else 'Toucher pour activer',
          if (listeNom != null) 'Liste : $listeNom',
        ].join(' · ')),
        onTap: p.actif
            ? null
            : () async {
                await ref.read(profilsNotifierProvider.notifier).activer(p.id);
                if (context.mounted) {
                  afficherMessage(context, 'Profil « ${p.nom} » activé',
                      couleur: couleurSucces(context));
                }
              },
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _action(context, ref, v, p, tous),
          itemBuilder: (_) => [
            if (p.actif)
              const PopupMenuItem(
                  value: 'rayons',
                  child: Row(children: [
                    Icon(Icons.store_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Modifier les rayons')
                  ])),
            const PopupMenuItem(
                value: 'liste',
                child: Row(children: [
                  Icon(Icons.link, size: 18),
                  SizedBox(width: 10),
                  Text('Liste associée')
                ])),
            const PopupMenuItem(
                value: 'renommer',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Renommer')
                ])),
            const PopupMenuItem(
                value: 'partager',
                child: Row(children: [
                  Icon(Icons.qr_code_2, size: 18),
                  SizedBox(width: 10),
                  Text('Partager')
                ])),
            if (tous.length > 1)
              const PopupMenuItem(
                  value: 'supprimer',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 10),
                    Text('Supprimer')
                  ])),
          ],
        ),
      ),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, String v, Profil p,
      List<Profil> tous) async {
    switch (v) {
      case 'rayons':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const RayonsScreen()));
      case 'liste':
        await _lierListe(context, ref, p);
      case 'renommer':
        await _renommer(context, ref, p);
      case 'partager':
        await _partager(context, ref, p);
      case 'supprimer':
        await _supprimer(context, ref, p);
    }
  }

  Future<void> _creerProfil(BuildContext context, WidgetRef ref) async {
    final nom = await _demanderNom(context, 'Nouveau profil', '');
    if (nom == null || nom.isEmpty) return;
    final p = await ref.read(profilsNotifierProvider.notifier).creer(nom);
    // On l'active tout de suite pour pouvoir en régler les rayons.
    await ref.read(profilsNotifierProvider.notifier).activer(p.id);
    if (context.mounted) {
      afficherMessage(context, 'Profil « $nom » créé et activé',
          couleur: couleurSucces(context));
    }
  }

  Future<void> _renommer(BuildContext context, WidgetRef ref, Profil p) async {
    final nom = await _demanderNom(context, 'Renommer le profil', p.nom);
    if (nom == null || nom.isEmpty) return;
    await ref.read(profilsNotifierProvider.notifier).renommer(p, nom);
  }

  Future<void> _lierListe(BuildContext context, WidgetRef ref, Profil p) async {
    final listes = (await ref.read(listesNotifierProvider.future))
        .where((l) => !l.archivee)
        .toList();
    if (!context.mounted) return;
    final choix = await showModalBottomSheet<String?>(
      context: context,
      useSafeArea: true,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Liste associée',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('Aucune'),
              onTap: () => Navigator.pop(sheetCtx, '__aucune__'),
            ),
            const Divider(height: 1),
            for (final l in listes)
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: Text(l.nom),
                trailing: p.listeId == l.id ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetCtx, l.id),
              ),
          ],
        ),
      ),
    );
    if (choix == null) return;
    await ref
        .read(profilsNotifierProvider.notifier)
        .lierListe(p, choix == '__aucune__' ? null : choix);
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref, Profil p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le profil ?'),
        content: Text('« ${p.nom} » sera supprimé. Ton organisation actuelle '
            'de rayons n\'est pas touchée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: couleurDanger(context),
                foregroundColor: texteContrastant(couleurDanger(context))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(profilsNotifierProvider.notifier).supprimer(p.id);
  }

  Future<void> _partager(BuildContext context, WidgetRef ref, Profil p) async {
    try {
      // Si on partage le profil ACTIF, on capture d'abord l'organisation en
      // cours pour que l'instantané envoyé soit à jour.
      if (p.actif) {
        await ref.read(profilsNotifierProvider.notifier).capturerActif();
      }
      final profilAJour = (await ref.read(dbServiceProvider).getProfils())
          .where((x) => x.id == p.id)
          .firstOrNull;
      final code = await ref
          .read(syncServiceProvider)
          .partagerProfil(profilAJour ?? p);
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Partager « ${p.nom} »'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.listeId != null
                  ? 'La liste associée est partagée avec le profil. Fais '
                      'scanner ce QR code (ou donne le code).'
                  : 'Fais scanner ce QR code (ou donne le code) pour partager '
                      'ton organisation de rayons.'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.white,
                child: QrImageView(data: code, size: 200),
              ),
              const SizedBox(height: 12),
              SelectableText(code,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        afficherMessage(context, 'Échec : $e');
      }
    }
  }

  Future<void> _suivreProfil(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Suivre un profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  hintText: 'Code à 6 caractères',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner un QR code'),
              onPressed: () async {
                final scanned = await Navigator.push<String>(dctx,
                    MaterialPageRoute(builder: (_) => const _ScanProfilScreen()));
                if (scanned != null && dctx.mounted) {
                  Navigator.pop(dctx, scanned);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
              child: const Text('Suivre')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      final res = await ref.read(syncServiceProvider).suivreProfil(code);
      if (!context.mounted) return;
      if (res == null) {
        afficherMessage(context, 'Code invalide');
        return;
      }
      ref.invalidate(profilsNotifierProvider);
      // Liste associée : proposer de la rejoindre.
      if (res.listeCode != null) {
        await _rejoindreListeAssociee(context, ref, res.profilId, res.listeCode!);
      }
      if (context.mounted) {
        afficherMessage(context, 'Profil « ${res.nom} » ajouté',
            couleur: couleurSucces(context));
      }
    } catch (e) {
      if (context.mounted) afficherMessage(context, 'Échec : $e');
    }
  }

  Future<void> _rejoindreListeAssociee(BuildContext context, WidgetRef ref,
      String profilId, String listeCode) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Liste associée'),
        content: const Text(
            'Ce profil a une liste collaborative associée. La rejoindre ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rejoindre')),
        ],
      ),
    );
    if (ok != true) return;
    final res =
        await ref.read(syncServiceProvider).rejoindreListeParCode(listeCode);
    if (res == null) return;
    final db = ref.read(dbServiceProvider);
    await db.insertListe(res.liste);
    for (final item in res.items) {
      await db.insertArticleListe(item);
    }
    // Lie la liste rejointe au profil suivi.
    final profil =
        (await db.getProfils()).where((p) => p.id == profilId).firstOrNull;
    if (profil != null) await db.updateProfil(profil.copyWith(listeId: res.liste.id));
    ref.invalidate(listesNotifierProvider);
    ref.invalidate(profilsNotifierProvider);
  }

  Future<String?> _demanderNom(
      BuildContext context, String titre, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titre),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Ex. Carrefour, Lidl...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
  }
}

// Petit écran de scan d'un QR code de profil. Renvoie le contenu une fois.
class _ScanProfilScreen extends StatefulWidget {
  const _ScanProfilScreen();
  @override
  State<_ScanProfilScreen> createState() => _ScanProfilScreenState();
}

class _ScanProfilScreenState extends State<_ScanProfilScreen> {
  bool _fait = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner le QR code')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_fait) return;
          final code = capture.barcodes.isNotEmpty
              ? capture.barcodes.first.rawValue
              : null;
          if (code != null && code.isNotEmpty) {
            _fait = true;
            Navigator.pop(context, code);
          }
        },
      ),
    );
  }
}
