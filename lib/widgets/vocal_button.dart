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

  // ── Validation et ajout au catalogue ─────────────────────────
  Future<void> _valider() async {
    if (_texteEnCours.trim().isEmpty) return;
    if (!mounted) return;

    final result = VocalService.nettoyer(_texteEnCours);

    final catalogue = ref.read(articlesNotifierProvider).valueOrNull ?? [];

    // Chercher si l'article existe déjà dans le catalogue
    var article = catalogue
        .where((a) => a.nom.toLowerCase() == result.nomArticle.toLowerCase())
        .firstOrNull;

    String msg;

    if (article == null) {
      // Nouveau : créer et ajouter au catalogue
      article = Article(
        id: 'article_${DateTime.now().millisecondsSinceEpoch}',
        nom: result.nomArticle,
      );
      await ref.read(articlesNotifierProvider.notifier).ajouter(article);
      msg = widget.listeId != null
          ? '"${result.nomArticle}" ajouté au catalogue et à la liste'
          : '"${result.nomArticle}" ajouté au catalogue';
    } else {
      // Existant : ne pas recréer dans le catalogue
      msg = widget.listeId != null
          ? '"${result.nomArticle}" ajouté à la liste'
          : '"${result.nomArticle}" existe déjà dans le catalogue';
    }

    // Ajouter à la liste si ciblée (qu'il soit nouveau ou existant)
    if (widget.listeId != null) {
      final itemsListe =
          ref.read(articlesListeProvider(widget.listeId!)).valueOrNull ?? [];
      final dejaInListe = itemsListe.any((i) => i.articleId == article!.id);
      if (!dejaInListe) {
        await ref.read(articlesListeProvider(widget.listeId!).notifier).ajouter(
              ArticleListe(
                id: 'al_${DateTime.now().millisecondsSinceEpoch}',
                listeId: widget.listeId!,
                articleId: article.id,
                quantite: result.quantite,
                unite: result.unite,
              ),
            );
      } else {
        msg = '"${result.nomArticle}" est déjà dans la liste';
      }
    }

    if (!mounted) return;
    Navigator.pop(context);

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
            'Ex: "pain", "3 yaourts", "deux litres de lait"',
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
