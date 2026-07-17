import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'widgets/background_logo.dart';
import 'screens/home_screen.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final prefs = await SharedPreferences.getInstance();
  final afficherStats = prefs.getBool('afficher_stats') ?? true;
  final couleurTheme = prefs.getString('couleur_theme') ?? 'vert';
  final fondActif = prefs.getBool('fond_actif') ?? true;
  final fondOpacite = prefs.getDouble('fond_opacite') ?? 0.06;

  runApp(ProviderScope(
    overrides: [
      afficherStatsProvider.overrideWith((ref) => afficherStats),
      couleurThemeProvider.overrideWith((ref) => couleurTheme),
      fondActiveProvider.overrideWith((ref) => fondActif),
      fondOpaciteProvider.overrideWith((ref) => fondOpacite),
    ],
    child: const SmartCartApp(),
  ));
}

class SmartCartApp extends ConsumerWidget {
  const SmartCartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couleur = ref.watch(couleurThemeProvider);
    return MaterialApp(
      title: 'SmartCart',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light, couleur),
      darkTheme: _buildTheme(Brightness.dark, couleur),
      themeMode: ThemeMode.system,
      home: const _SplashWrapper(),
    );
  }

  ThemeData _buildTheme(Brightness brightness, String couleurNom) {
    final isDark = brightness == Brightness.dark;
    final seedColor = _couleurSeed(couleurNom);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeSlideTransition(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  Color _couleurSeed(String nom) {
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
      case 'gris': return const Color(0xFF455A64);
      case 'noir': return const Color(0xFF212121);
      default: return const Color(0xFF1ABC9C);
    }
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
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideAnim, child: const HomeScreen()),
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
