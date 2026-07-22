import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/ajouter_article_dialog.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController();
  bool _traitement = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed && !_traitement) {
      _controller.start();
    }
  }

  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_traitement) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    // Retour immédiat à la détection : l'utilisateur sait que le code a
    // bien été lu sans avoir à regarder l'écran.
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    setState(() => _traitement = true);
    await _controller.stop();

    final code = barcode!.rawValue!;
    if (!mounted) return;

    // Loader pendant la recherche OFF
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Recherche du produit...'),
              ],
            ),
          ),
        ),
      ),
    );

    final article = await ref.read(offServiceProvider).searchByBarcode(code);
    if (!mounted) return;
    Navigator.pop(context); // fermer loader

    if (article == null) {
      _afficherNonTrouve(code);
    } else {
      _afficherArticleTrouve(article);
    }
  }

  void _resetScan() {
    if (mounted) {
      setState(() => _traitement = false);
      _controller.start();
    }
  }

  void _afficherNonTrouve(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Produit non trouvé'),
        content: Text('Code "$code" introuvable.\nVoulez-vous l\'ajouter manuellement ?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // scanner
            },
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              showDialog(
                context: context,
                builder: (_) => AjouterArticleDialog(barcodeInitial: code),
              ).then((_) {
                if (mounted) Navigator.pop(context); // scanner
              });
            },
            child: const Text('Ajouter manuellement'),
          ),
        ],
      ),
    ).then((_) => _resetScan());
  }

  void _afficherArticleTrouve(Article article) {
    showDialog(
      context: context,
      builder: (_) => _ArticleTrouveDialog(
        article: article,
        onIgnorer: () {
          Navigator.pop(context); // dialog
          _resetScan(); // reprendre le scan
        },
        onPersonnaliser: () async {
          // Ajouter d'abord en base
          await ref.read(articlesNotifierProvider.notifier).ajouter(article);
          if (!mounted) return;
          Navigator.pop(context); // dialog trouvé
          // Enchaîner un nouveau showDialog juste après un pop, dans le
          // même tick, peut ne rien afficher (la transition de fermeture
          // n'a pas fini) : on attend la frame suivante pour être sûr que
          // le dialogue précédent est bien retiré avant d'en ouvrir un autre.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (_) => AjouterArticleDialog(articleExistant: article),
            ).then((_) {
              if (mounted) Navigator.pop(context); // fermer scanner
            });
          });
        },
        onAjouterDirectement: () async {
          await ref.read(articlesNotifierProvider.notifier).ajouter(article);
          if (!mounted) return;
          Navigator.pop(context); // dialog
          Navigator.pop(context); // scanner
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${article.nom} ajouté au catalogue'),
            backgroundColor: Colors.green,
          ));
        },
      ),
    ).then((_) {
      // Dialog fermé sans action → reset pour nouveau scan
      if (mounted && _traitement) _resetScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner un produit'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Activer/désactiver le flash',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            tooltip: 'Changer de caméra',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Le widget MobileScanner reste toujours monté (démonter/remonter
          // pendant que les dialogues de résultat s'affichaient cassait la
          // reprise du scan : "Ignorer" laissait un écran noir impossible à
          // relancer, le contrôleur étant démarré avant que le widget ne
          // soit réattaché). On masque juste l'aperçu par un calque noir
          // pendant le traitement, sans toucher au cycle de vie caméra.
          MobileScanner(controller: _controller, onDetect: _onBarcode),
          if (_traitement) Positioned.fill(child: Container(color: Colors.black)),
          Center(
            child: Container(
              width: 260, height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(children: _buildCorners(context)),
            ),
          ),
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Pointez la caméra vers le code-barres',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    const s = 20.0, t = 3.0;
    return [
      Positioned(top: 0, left: 0,
          child: _Corner(color: c, size: s, thick: t, top: true, left: true)),
      Positioned(top: 0, right: 0,
          child: _Corner(color: c, size: s, thick: t, top: true, left: false)),
      Positioned(bottom: 0, left: 0,
          child: _Corner(color: c, size: s, thick: t, top: false, left: true)),
      Positioned(bottom: 0, right: 0,
          child: _Corner(color: c, size: s, thick: t, top: false, left: false)),
    ];
  }
}

// ── Coin du viseur ────────────────────────────────────────────────
class _Corner extends StatelessWidget {
  final Color color;
  final double size, thick;
  final bool top, left;
  const _Corner({required this.color, required this.size,
      required this.thick, required this.top, required this.left});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size, height: size,
      child: CustomPaint(
          painter: _CornerPainter(
              color: color, thick: thick, top: top, left: left)));
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thick;
  final bool top, left;
  _CornerPainter({required this.color, required this.thick,
      required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thick * 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height); path.lineTo(0, 0); path.lineTo(size.width, 0);
    } else if (top) {
      path.moveTo(0, 0); path.lineTo(size.width, 0); path.lineTo(size.width, size.height);
    } else if (left) {
      path.moveTo(0, 0); path.lineTo(0, size.height); path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height); path.lineTo(size.width, size.height); path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CornerPainter o) => false;
}

// ── Dialog article trouvé ─────────────────────────────────────────
class _ArticleTrouveDialog extends ConsumerWidget {
  final Article article;
  final VoidCallback onIgnorer;
  final Future<void> Function() onPersonnaliser;
  final Future<void> Function() onAjouterDirectement;

  const _ArticleTrouveDialog({
    required this.article,
    required this.onIgnorer,
    required this.onPersonnaliser,
    required this.onAjouterDirectement,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorie = ref.watch(categoriesNotifierProvider).valueOrNull
        ?.where((c) => c.id == article.categorieId).firstOrNull;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('Produit trouvé !'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.imageUrl != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  article.imageUrl!,
                  height: 80, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (article.imageUrl != null) const SizedBox(height: 12),
          Text(article.nom,
              style: Theme.of(context).textTheme.titleMedium),
          if (article.marque != null) ...[
            const SizedBox(height: 4),
            Text(article.marque!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (categorie != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                    backgroundColor: Color(categorie.couleur), radius: 6),
                const SizedBox(width: 6),
                Text('Catégorie : ${categorie.nom}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text('Voulez-vous ajouter ce produit au catalogue ?',
              style: TextStyle(fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onIgnorer,
          child: const Text('Ignorer'),
        ),
        OutlinedButton(
          onPressed: onPersonnaliser,
          child: const Text('Personnaliser'),
        ),
        FilledButton(
          onPressed: onAjouterDirectement,
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
