import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/vocal_service.dart';

// ================================================================
// POINT D'ENTRÉE : ouvrir le sheet vocal depuis n'importe où
// ================================================================
void ouvrirVocal(BuildContext context, {String? listeId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VocalSheet(listeId: listeId),
  );
}

// ================================================================
// BOTTOM SHEET VOCAL — autonome, gère tout en interne
// ================================================================
class VocalSheet extends ConsumerStatefulWidget {
  /// Si fourni : ajoute directement à cette liste au lieu du catalogue
  final String? listeId;

  const VocalSheet({super.key, this.listeId});

  @override
  ConsumerState<VocalSheet> createState() => _VocalSheetState();
}

class _VocalSheetState extends ConsumerState<VocalSheet>
    with SingleTickerProviderStateMixin {

  // États
  _Etat _etat = _Etat.demarrage;
  String _texteEnCours = '';
  String _messageErreur = '';

  // Animation pulse du micro
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Stream écoute
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.18)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Démarrer l'écoute après que le sheet soit affiché
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 350), _demarrer);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _sub?.cancel();
    ref.read(vocalServiceProvider).annuler();
    super.dispose();
  }

  // ── Démarrage ─────────────────────────────────────────────────
  Future<void> _demarrer() async {
    if (!mounted) return;
    setState(() {
      _etat = _Etat.demarrage;
      _texteEnCours = '';
      _messageErreur = '';
    });

    final service = ref.read(vocalServiceProvider);

    // Préparer (permission + init)
    final erreur = await service.preparer();
    if (!mounted) return;

    if (erreur != null) {
      setState(() {
        _etat = _Etat.erreur;
        _messageErreur = erreur;
      });
      return;
    }

    // Démarrer l'écoute via stream
    setState(() => _etat = _Etat.ecoute);

    final stream = service.ecouter();
    _sub = stream.listen(
      // Chaque texte reconnu (partiel)
      (texte) {
        if (mounted) setState(() => _texteEnCours = texte);
      },
      // Stream terminé (silence ou résultat final reçu)
      onDone: () {
        if (!mounted) return;
        if (_texteEnCours.isNotEmpty) {
          _valider();
        } else {
          setState(() {
            _etat = _Etat.rienReconnu;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _etat = _Etat.rienReconnu);
      },
      cancelOnError: false,
    );
  }

  // ── Validation et ajout au catalogue (un ou plusieurs articles) ──
  Future<void> _valider() async {
    if (_texteEnCours.trim().isEmpty) return;
    if (!mounted) return;

    final resultats = VocalService.nettoyerMultiple(_texteEnCours);
    if (resultats.isEmpty) return;

    var ajoutes = 0;
    var dejaPresents = 0;

    for (final result in resultats) {
      // Relire le catalogue à chaque itération : les ajouts précédents
      // dans cette même dictée doivent être visibles pour les suivants.
      final catalogue = ref.read(articlesNotifierProvider).valueOrNull ?? [];
      var article = catalogue
          .where((a) => a.nom.toLowerCase() == result.nomArticle.toLowerCase())
          .firstOrNull;

      if (article == null) {
        article = Article(
          id: 'article_${DateTime.now().millisecondsSinceEpoch}_$ajoutes',
          nom: result.nomArticle,
        );
        await ref.read(articlesNotifierProvider.notifier).ajouter(article);
      }

      if (widget.listeId != null) {
        final itemsListe =
            ref.read(articlesListeProvider(widget.listeId!)).valueOrNull ?? [];
        final dejaInListe = itemsListe.any((i) => i.articleId == article!.id);
        if (!dejaInListe) {
          await ref.read(articlesListeProvider(widget.listeId!).notifier).ajouter(
                ArticleListe(
                  id: 'al_${DateTime.now().millisecondsSinceEpoch}_$ajoutes',
                  listeId: widget.listeId!,
                  articleId: article.id,
                  quantite: result.quantite,
                  unite: result.unite,
                ),
              );
          ajoutes++;
        } else {
          dejaPresents++;
        }
      } else {
        ajoutes++;
      }
    }

    if (!mounted) return;
    Navigator.pop(context);

    final cible = widget.listeId != null ? 'à la liste' : 'au catalogue';
    final msg = resultats.length == 1
        ? '"${resultats.first.nomArticle}" ajouté $cible'
        : '$ajoutes article(s) ajouté(s) $cible'
            '${dejaPresents > 0 ? ' ($dejaPresents déjà présent(s))' : ''}';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Titre
          Text(
            widget.listeId != null
                ? 'Ajouter à la liste'
                : 'Ajouter au catalogue',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Ex: "pain", "3 yaourts", "pommes, lait et pain"',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 32),

          // Micro animé
          _buildMicro(context),
          const SizedBox(height: 24),

          // Zone texte reconnu
          _buildZoneTexte(context),
          const SizedBox(height: 16),

          // Boutons
          _buildBoutons(context),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMicro(BuildContext context) {
    final isEcoute = _etat == _Etat.ecoute;
    final color = isEcoute
        ? Colors.red
        : Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(
        scale: isEcoute ? _pulseAnim.value : 1.0,
        child: child,
      ),
      child: GestureDetector(
        onTap: _etat == _Etat.rienReconnu || _etat == _Etat.erreur
            ? _demarrer
            : null,
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: isEcoute ? 20 : 10,
              spreadRadius: isEcoute ? 4 : 1,
            )],
          ),
          child: Icon(
            isEcoute ? Icons.mic : Icons.mic_none,
            color: Colors.white, size: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildZoneTexte(BuildContext context) {
    String texte;
    Color bgColor;
    Color textColor;

    switch (_etat) {
      case _Etat.demarrage:
        texte = 'Initialisation...';
        bgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        textColor = Theme.of(context).colorScheme.outline;
      case _Etat.ecoute:
        texte = _texteEnCours.isEmpty ? 'Parlez maintenant...' : _texteEnCours;
        bgColor = _texteEnCours.isEmpty
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primaryContainer;
        textColor = _texteEnCours.isEmpty
            ? Theme.of(context).colorScheme.outline
            : Theme.of(context).colorScheme.onPrimaryContainer;
      case _Etat.rienReconnu:
        texte = 'Rien entendu — appuyez sur le micro pour réessayer';
        bgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        textColor = Theme.of(context).colorScheme.outline;
      case _Etat.erreur:
        texte = _messageErreur;
        bgColor = Theme.of(context).colorScheme.errorContainer;
        textColor = Theme.of(context).colorScheme.onErrorContainer;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: _texteEnCours.isNotEmpty && _etat == _Etat.ecoute
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
            : null,
      ),
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: textColor,
          fontWeight: _texteEnCours.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildBoutons(BuildContext context) {
    return Row(
      children: [
        // Annuler
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              ref.read(vocalServiceProvider).annuler();
              Navigator.pop(context);
            },
            child: const Text('Annuler'),
          ),
        ),
        const SizedBox(width: 12),
        // Valider manuellement si texte reconnu
        if (_texteEnCours.isNotEmpty)
          Expanded(
            child: FilledButton.icon(
              onPressed: _valider,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Ajouter'),
            ),
          ),
      ],
    );
  }
}

enum _Etat { demarrage, ecoute, rienReconnu, erreur }
