import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'services/widget_service.dart';
import 'utils/theme_utils.dart';
import 'widgets/background_logo.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Protège Firestore contre les clients non authentifiés/abusifs. En
  // debug on utilise le provider "debug" (nécessite d'enregistrer le
  // jeton affiché dans les logs sur la console Firebase → App Check).
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  // Désactivé en debug pour ne pas polluer Crashlytics avec les sessions
  // de développement (hot reload, exceptions volontaires, etc.).
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final prefs = await SharedPreferences.getInstance();
  final afficherStats = prefs.getBool('afficher_stats') ?? true;
  final afficherBudget = prefs.getBool('afficher_budget') ?? true;
  final afficherPrix = prefs.getBool('afficher_prix') ?? true;
  final couleurTheme = prefs.getString('couleur_theme') ?? 'vert';
  final fondActif = prefs.getBool('fond_actif') ?? true;
  final fondOpacite = prefs.getDouble('fond_opacite') ?? 0.06;
  final themeMode = _themeModeDepuisPrefs(prefs.getString('theme_mode'));
  final onboardingVu = prefs.getBool('onboarding_vu') ?? false;
  final tailleTexte = prefs.getDouble('taille_texte') ?? 1.0;

  // Resynchronise le widget d'écran d'accueil avec la couleur actuelle à
  // chaque démarrage (pas seulement au moment où l'utilisateur la change
  // dans Paramètres) : couvre le cas d'un widget ajouté après coup ou
  // réinstallé, qui sinon resterait sur sa couleur par défaut tant que
  // l'utilisateur ne rouvre pas Paramètres.
  WidgetService.mettreAJourCouleur(_couleurSeed(couleurTheme).toARGB32());

  runApp(ProviderScope(
    overrides: [
      afficherStatsProvider.overrideWith((ref) => afficherStats),
      afficherBudgetProvider.overrideWith((ref) => afficherBudget),
      afficherPrixProvider.overrideWith((ref) => afficherPrix),
      couleurThemeProvider.overrideWith((ref) => couleurTheme),
      fondActiveProvider.overrideWith((ref) => fondActif),
      fondOpaciteProvider.overrideWith((ref) => fondOpacite),
      themeModeProvider.overrideWith((ref) => themeMode),
      afficherOnboardingProvider.overrideWith((ref) => !onboardingVu),
      tailleTexteProvider.overrideWith((ref) => tailleTexte),
    ],
    child: const SmartCartApp(),
  ));
}

ThemeMode _themeModeDepuisPrefs(String? valeur) {
  switch (valeur) {
    case 'clair': return ThemeMode.light;
    case 'sombre': return ThemeMode.dark;
    default: return ThemeMode.system;
  }
}

class SmartCartApp extends ConsumerWidget {
  const SmartCartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couleur = ref.watch(couleurThemeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final tailleTexte = ref.watch(tailleTexteProvider);
    return MaterialApp(
      title: 'SmartCart',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light, couleur),
      darkTheme: _buildTheme(Brightness.dark, couleur),
      themeMode: themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(tailleTexte)),
        child: child!,
      ),
      home: const _SplashWrapper(),
    );
  }

  ThemeData _buildTheme(Brightness brightness, String couleurNom) {
    final isDark = brightness == Brightness.dark;
    final seedColor = _couleurSeed(couleurNom);
    // Les tons "surface" générés par ColorScheme.fromSeed reprennent la
    // teinte de la couleur choisie (c'est le fonctionnement normal de
    // Material 3) : pour un rouge ou un orange, très saturés, ça donne un
    // fond d'écran, de cartes et de boîtes de dialogue visiblement teinté,
    // perçu comme "un filtre sur l'écran". On garde donc les rôles d'accent
    // (primary/secondary/tertiary/error) calculés depuis la couleur choisie,
    // mais on prend des surfaces neutres (calculées depuis un gris neutre)
    // pour que seuls les boutons/AppBar/accents portent la couleur, pas
    // l'ensemble de l'interface.
    // Un gris VRAIMENT neutre (chroma quasi nulle), pas un bleu-gris/
    // "blueGrey" : ce dernier gardait une légère teinte bleue perceptible
    // sur les grandes surfaces (fond d'écran, cartes) en mode sombre,
    // donnant l'impression que "le thème sombre est bleu" quelle que soit
    // la couleur choisie, et écrasait la différence visuelle entre deux
    // thèmes comme "brun" et "gris ardoise" (tous deux dominés par ce même
    // bleu-gris de fond).
    final neutre = ColorScheme.fromSeed(
      seedColor: const Color(0xFF808080),
      brightness: brightness,
    );
    var colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ).copyWith(
      surface: neutre.surface,
      surfaceDim: neutre.surfaceDim,
      surfaceBright: neutre.surfaceBright,
      surfaceContainerLowest: neutre.surfaceContainerLowest,
      surfaceContainerLow: neutre.surfaceContainerLow,
      surfaceContainer: neutre.surfaceContainer,
      surfaceContainerHigh: neutre.surfaceContainerHigh,
      surfaceContainerHighest: neutre.surfaceContainerHighest,
      onSurface: neutre.onSurface,
      onSurfaceVariant: neutre.onSurfaceVariant,
      outline: neutre.outline,
      outlineVariant: neutre.outlineVariant,
    );

    // primary est calculé directement depuis la couleur choisie plutôt que
    // laissé à l'algorithme HCT de Material, pour deux raisons :
    // 1) pour une couleur quasi neutre (chroma très faible, ex. "noir"),
    //    HCT doit malgré tout inventer une teinte pour construire toute la
    //    palette, et penche systématiquement vers le bleu quand la couleur
    //    de départ n'a presque pas de teinte propre — "noir" ressortait
    //    bleuté sur les boutons/AppBar.
    // 2) en thème sombre, Material 3 éclaircit délibérément primary (ton
    //    ~80, pensé comme du TEXTE lisible sur fond sombre) : pour un
    //    bouton, ça donne une couleur pâle/"délavée" plutôt qu'un bouton
    //    fait pour être vu, avec le texte blanc qu'on attendrait dessus.
    // On garde donc toujours la même teinte/saturation que la couleur
    // choisie et on ne fait varier que la luminosité, légèrement plus
    // claire en mode sombre pour rester lisible sur un fond sombre, mais
    // jamais au point de devenir pâle.
    final hslSeed = HSLColor.fromColor(seedColor);
    final saturationUtilisable = hslSeed.saturation < 0.08
        ? 0.0
        : hslSeed.saturation.clamp(0.45, 1.0);
    final primary = hslSeed
        .withSaturation(saturationUtilisable)
        .withLightness(isDark ? 0.55 : 0.32)
        .toColor();
    final primaryContainer = hslSeed
        .withSaturation(saturationUtilisable)
        .withLightness(isDark ? 0.28 : 0.85)
        .toColor();
    colorScheme = colorScheme.copyWith(
      primary: primary,
      onPrimary: texteContrastant(primary),
      primaryContainer: primaryContainer,
      onPrimaryContainer: texteContrastant(primaryContainer),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? colorScheme.surface : colorScheme.primary,
        foregroundColor: isDark ? colorScheme.onSurface : colorScheme.onPrimary,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
        color: colorScheme.surfaceContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeSlideTransition(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

}

// Couleur choisie librement par l'utilisateur (sélecteur "Personnalisée…"
// dans Paramètres), stockée sous la forme "custom:RRGGBB" plutôt que
// d'ajouter une clé de préférence séparée à synchroniser partout.
Color? _couleurPersonnalisee(String nom) {
  if (!nom.startsWith('custom:')) return null;
  final hex = int.tryParse(nom.substring('custom:'.length), radix: 16);
  return hex == null ? null : Color(0xFF000000 | hex);
}

Color _couleurSeed(String nom) {
  final personnalisee = _couleurPersonnalisee(nom);
  if (personnalisee != null) return personnalisee;
  switch (nom) {
    case 'vert': return const Color(0xFF1ABC9C);
    case 'vert_fonce': return const Color(0xFF2E7D32);
    case 'teal': return const Color(0xFF00695C);
    case 'olive': return const Color(0xFF827717);
    case 'bleu': return const Color(0xFF1565C0);
    case 'bleu_clair': return const Color(0xFF0288D1);
    case 'indigo': return const Color(0xFF283593);
    case 'cyan': return const Color(0xFF00838F);
    case 'orange': return const Color(0xFFE65100);
    case 'ambre': return const Color(0xFFFF6F00);
    case 'rouge': return const Color(0xFFC62828);
    case 'rose': return const Color(0xFFAD1457);
    case 'violet': return const Color(0xFF6A1B9A);
    case 'brun': return const Color(0xFF4E342E);
    case 'gris': return const Color(0xFF616161);
    case 'noir': return const Color(0xFF212121);
    default: return const Color(0xFF1ABC9C);
  }
}

class _SplashWrapper extends ConsumerStatefulWidget {
  const _SplashWrapper();
  @override
  ConsumerState<_SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends ConsumerState<_SplashWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 150), () {
      FlutterNativeSplash.remove();
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
    final afficherOnboarding = ref.watch(afficherOnboardingProvider);
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: afficherOnboarding
            ? OnboardingScreen(
                onTermine: () =>
                    ref.read(afficherOnboardingProvider.notifier).state = false,
              )
            : const HomeScreen(),
      ),
    );
  }
}


// ── Transition fade + slide personnalisée ─────────────────────────
class _FadeSlideTransition extends PageTransitionsBuilder {
  const _FadeSlideTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0.03, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
