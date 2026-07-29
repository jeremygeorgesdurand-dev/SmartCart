import 'package:flutter/material.dart';
import '../utils/theme_utils.dart';

/// Anime l'apparition d'un item dans une liste (fade + slide depuis le bas)
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 50),
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Délai progressif selon l'index (max 400ms pour ne pas être trop lent)
    final delayMs =
        (widget.index * widget.delay.inMilliseconds).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Bouton avec animation de rebond au tap
class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BouncingButton({super.key, required this.child, required this.onTap});

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Widget check animé (pour le mode courses)
class AnimatedCheckIcon extends StatefulWidget {
  final bool checked;
  final Color color;
  final double size;

  const AnimatedCheckIcon({
    super.key,
    required this.checked,
    required this.color,
    this.size = 28,
  });

  @override
  State<AnimatedCheckIcon> createState() => _AnimatedCheckIconState();
}

class _AnimatedCheckIconState extends State<AnimatedCheckIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scale = TweenSequence([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(AnimatedCheckIcon old) {
    super.didUpdateWidget(old);
    if (old.checked != widget.checked) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          widget.checked ? Icons.check_circle : Icons.radio_button_unchecked,
          key: ValueKey(widget.checked),
          color: widget.color,
          size: widget.size,
        ),
      ),
    );
  }
}

/// Comme [Dismissible], mais le glissement ne se déclenche que si le doigt
/// se pose dans une zone étroite à droite (par défaut là où se trouve une
/// icône/flèche de fin de ligne) : glisser au milieu de la ligne ne fait
/// rien, ce qui permet de superposer un geste de glissement plein écran
/// ailleurs (ex: changer d'onglet) sans que les deux gestes se disputent
/// la ligne entière comme le ferait un Dismissible classique.
class SwipeZoneDismissible extends StatefulWidget {
  final Widget child;
  final Widget background;
  final Future<bool> Function() confirmDismiss;
  final VoidCallback onDismissed;
  final double zoneDeclenchement;

  const SwipeZoneDismissible({
    super.key,
    required this.child,
    required this.background,
    required this.confirmDismiss,
    required this.onDismissed,
    this.zoneDeclenchement = 64,
  });

  @override
  State<SwipeZoneDismissible> createState() => _SwipeZoneDismissibleState();
}

class _SwipeZoneDismissibleState extends State<SwipeZoneDismissible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _dx = 0;

  static const _seuil = 90.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _animerVers(double cible, {Duration? duree}) async {
    final depart = _dx;
    _ctrl.duration = duree ?? const Duration(milliseconds: 200);
    _ctrl.reset();
    final anim = Tween<double>(begin: depart, end: cible)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    void listener() => setState(() => _dx = anim.value);
    anim.addListener(listener);
    await _ctrl.forward();
    anim.removeListener(listener);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _dx = (_dx + details.delta.dx).clamp(-320.0, 0.0));
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (_dx.abs() < _seuil) {
      await _animerVers(0);
      return;
    }
    // Reste dans une position "révélée" pendant la confirmation, plutôt
    // que de continuer jusqu'au bout avant même de savoir si l'utilisateur
    // confirme.
    await _animerVers(-widget.zoneDeclenchement * 1.4);
    if (!mounted) return;
    final confirme = await widget.confirmDismiss();
    if (!mounted) return;
    if (!confirme) {
      await _animerVers(0);
      return;
    }
    final largeur = context.size?.width ?? 400;
    await _animerVers(-largeur, duree: const Duration(milliseconds: 250));
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Largeur exactement égale à la distance glissée (0 au repos) :
        // un Positioned.fill classique laissait dépasser un fin liseré du
        // fond rouge derrière la carte au repos, les deux n'ayant pas
        // exactement le même arrondi/marge.
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: -_dx,
          child: ClipRect(
            child: OverflowBox(
              minWidth: 0,
              maxWidth: 320,
              alignment: Alignment.centerRight,
              child: widget.background,
            ),
          ),
        ),
        Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: widget.zoneDeclenchement,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
          ),
        ),
      ],
    );
  }
}

/// Card avec animation de suppression (slide + fade)
class DismissibleCard extends StatelessWidget {
  final String id;
  final Widget child;
  final VoidCallback onDismissed;
  final String confirmLabel;

  const DismissibleCard({
    super.key,
    required this.id,
    required this.child,
    required this.onDismissed,
    this.confirmLabel = 'Supprimer',
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Builder(builder: (context) {
        final danger = couleurDanger(context);
        return Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: danger,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, color: texteContrastant(danger), size: 28),
              const SizedBox(height: 4),
              Text('Supprimer',
                  style: TextStyle(
                      color: texteContrastant(danger),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                title: const Text('Confirmer ?'),
                content: Text('$confirmLabel définitivement ?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: const Text('Annuler')),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: couleurDanger(dialogCtx),
                        foregroundColor:
                            texteContrastant(couleurDanger(dialogCtx))),
                    onPressed: () => Navigator.pop(dialogCtx, true),
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDismissed(),
      child: child,
    );
  }
}
