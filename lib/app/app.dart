import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:pontocerto/core/auth/session_bootstrap.dart';
import 'package:pontocerto/core/router/app_router.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/widgets/global_whatsapp_support_fab.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppBrandColors.primary,
      brightness: Brightness.light,
      primary: AppBrandColors.primary,
      secondary: AppBrandColors.accent,
      surface: Colors.white,
    );

    final tema = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppBrandColors.surface,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppBrandColors.ink,
        displayColor: AppBrandColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppBrandColors.ink,
        titleTextStyle: TextStyle(
          color: AppBrandColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xF7FFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        shadowColor: const Color(0x120044CC),
        surfaceTintColor: Colors.white,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: AppBrandColors.softText),
        hintStyle: const TextStyle(color: AppBrandColors.softText),
        prefixIconColor: AppBrandColors.primaryDeep,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD6E4FF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppBrandColors.primary,
            width: 1.4,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppBrandColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppBrandColors.primaryDeep,
          side: const BorderSide(color: Color(0xFFC9DBFF)),
          backgroundColor: const Color(0xAAFFFFFF),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppBrandColors.primaryDeep,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppBrandColors.ink,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: kIsWeb
            ? {
                for (final p in TargetPlatform.values)
                  p: const FadeUpwardsPageTransitionsBuilder(),
              }
            : {
                TargetPlatform.android: const _AppFadeSlideTransitionsBuilder(),
                TargetPlatform.iOS: const _AppFadeSlideTransitionsBuilder(),
                TargetPlatform.windows: const _AppFadeSlideTransitionsBuilder(),
                TargetPlatform.macOS: const _AppFadeSlideTransitionsBuilder(),
                TargetPlatform.linux: const _AppFadeSlideTransitionsBuilder(),
              },
      ),
    );

    return SessionBootstrap(
      child: MaterialApp.router(
        title: 'Ponto Certo',
        theme: tema,
        routerConfig: RotasApp.roteador,
        scrollBehavior: const _AppScrollBehavior(),
        builder: (context, child) {
          final routed = child ?? const SizedBox.shrink();
          final content = kIsWeb ? SelectionArea(child: routed) : routed;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              content,
              const GlobalWhatsappSupportFab(),
            ],
          );
        },
      ),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _AppFadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _AppFadeSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    final offsetAnimation = Tween<Offset>(
      begin: const Offset(0.02, 0),
      end: Offset.zero,
    ).animate(curved);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: offsetAnimation, child: child),
    );
  }
}
