import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/providers.dart';
import '../services/widget_service.dart';
import '../utils/theme_utils.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/background_logo.dart';

// ================================================================
// ÉCRAN APPARENCE — thème de couleur, mode clair/sombre, taille du
// texte et fond personnalisé (logo en filigrane)
// ================================================================
class ApparenceScreen extends ConsumerWidget {
  const ApparenceScreen({super.key});

  // "custom:RRGGBB" = couleur choisie librement via le sélecteur
  // "Personnalisée…", pas une des 16 couleurs prédéfinies ci-dessous.
  static Color? _couleurPersonnalisee(String c) {
    if (!c.startsWith('custom:')) return null;
    final hex = int.tryParse(c.substring('custom:'.length), radix: 16);
    return hex == null ? null : Color(0xFF000000 | hex);
  }

  static String _nomTheme(String c) {
    if (_couleurPersonnalisee(c) != null) return 'Personnalisée';
    const noms = {
      'vert': 'Vert', 'vert_fonce': 'Vert foncé', 'teal': 'Teal', 'olive': 'Olive',
      'bleu': 'Bleu', 'bleu_clair': 'Bleu ciel', 'indigo': 'Indigo', 'cyan': 'Cyan',
      'orange': 'Orange', 'ambre': 'Ambre', 'rouge': 'Rouge', 'rose': 'Rose',
      'violet': 'Violet', 'brun': 'Brun', 'gris': 'Gris ardoise', 'noir': 'Sombre',
    };
    return noms[c] ?? c;
  }

  static Color _couleurTheme(String c) {
    final personnalisee = _couleurPersonnalisee(c);
    if (personnalisee != null) return personnalisee;
    const couleurs = {
      'vert': Color(0xFF1ABC9C), 'vert_fonce': Color(0xFF2E7D32),
      'teal': Color(0xFF00695C), 'olive': Color(0xFF827717),
      'bleu': Color(0xFF1565C0), 'bleu_clair': Color(0xFF0288D1),
      'indigo': Color(0xFF283593), 'cyan': Color(0xFF00838F),
      'orange': Color(0xFFE65100), 'ambre': Color(0xFFFF6F00),
      'rouge': Color(0xFFC62828), 'rose': Color(0xFFAD1457),
      'violet': Color(0xFF6A1B9A), 'brun': Color(0xFF4E342E),
      'gris': Color(0xFF616161), 'noir': Color(0xFF212121),
    };
    return couleurs[c] ?? const Color(0xFF1ABC9C);
  }

  static String _nomModeTheme(ThemeMode mode) {
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
      ('gris', 'Gris ardoise', const Color(0xFF616161)),
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
            children: themes.map<Widget>((t) {
              final (id, nom, couleur) = t;
              final selected = actuel == id;
              return Semantics(
                label: nom,
                selected: selected,
                button: true,
                child: BouncingButton(
                onTap: () async {
                  ref.read(couleurThemeProvider.notifier).state = id;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('couleur_theme', id);
                  WidgetService.mettreAJourCouleur(couleur.toARGB32());
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
                ),
              );
            }).toList()
              ..add(_SwatchPersonnalisee(
                actuel: actuel,
                couleurActuelle: _couleurPersonnalisee(actuel),
                onTap: () => _choisirCouleurPersonnalisee(context, ref),
              )),
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

  Future<void> _choisirCouleurPersonnalisee(
      BuildContext context, WidgetRef ref) async {
    Color choisie = _couleurTheme(ref.read(couleurThemeProvider));
    final confirmee = await showDialog<Color>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Couleur personnalisée'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: choisie,
            onColorChanged: (c) => choisie = c,
            enableAlpha: false,
            pickerAreaHeightPercent: 0.7,
            labelTypes: const [ColorLabelType.hex],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, choisie),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirmee == null) return;

    final utilisable = couleurSeedUtilisable(confirmee);
    final hex = utilisable.toARGB32().toRadixString(16).padLeft(8, '0');
    final id = 'custom:${hex.substring(2).toUpperCase()}';
    ref.read(couleurThemeProvider.notifier).state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('couleur_theme', id);
    WidgetService.mettreAJourCouleur(utilisable.toARGB32());
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actif = ref.watch(fondActiveProvider);
    final opacite = ref.watch(fondOpaciteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Apparence')),
      body: ListView(
        children: [
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
            title: const Text('Mode'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Écran',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    )),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: SwitchListTile(
              secondary: const Icon(Icons.screen_rotation_outlined),
              title: const Text('Rotation de l\'écran'),
              subtitle: const Text(
                  'Suivre l\'orientation du téléphone (sinon bloqué en portrait)'),
              value: ref.watch(rotationAutoriseeProvider),
              onChanged: (v) async {
                ref.read(rotationAutoriseeProvider.notifier).state = v;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('rotation_autorisee', v);
                await SystemChrome.setPreferredOrientations(v
                    ? DeviceOrientation.values
                    : [DeviceOrientation.portraitUp]);
              },
            ),
          ),
          const Divider(),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Swatch "Personnalisée…" dans le sélecteur de thème : ouvre un vrai
// sélecteur de couleur (roue HSV + hex) au lieu de se limiter aux 16
// couleurs prédéfinies.
class _SwatchPersonnalisee extends StatelessWidget {
  final String actuel;
  final Color? couleurActuelle;
  final VoidCallback onTap;
  const _SwatchPersonnalisee({
    required this.actuel,
    required this.couleurActuelle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = couleurActuelle != null;
    return Semantics(
      label: 'Couleur personnalisée',
      selected: selected,
      button: true,
      child: BouncingButton(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: couleurActuelle,
              gradient: selected
                  ? null
                  : const SweepGradient(colors: [
                      Color(0xFFE53935), Color(0xFFFDD835), Color(0xFF43A047),
                      Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFFE53935),
                    ]),
              border: selected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface, width: 3)
                  : null,
              boxShadow: selected
                  ? [BoxShadow(
                      color: couleurActuelle!.withValues(alpha: 0.5),
                      blurRadius: 8, spreadRadius: 2)]
                  : null,
            ),
            child: Icon(
              selected ? Icons.check : Icons.colorize,
              color: Colors.white,
              size: selected ? 24 : 20,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Perso.', style: TextStyle(fontSize: 11)),
        ],
      ),
      ),
    );
  }
}
