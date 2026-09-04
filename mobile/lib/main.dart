import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'providers/providers.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: VickMpesaApp()));
}

class VickMpesaApp extends ConsumerWidget {
  const VickMpesaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Vick Mpesa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
