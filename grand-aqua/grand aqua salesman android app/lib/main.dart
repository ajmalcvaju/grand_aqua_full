import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: GrandAquaSalesmanApp()));
}

class GrandAquaSalesmanApp extends StatelessWidget {
  const GrandAquaSalesmanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Grand Aqua Salesman',
      debugShowCheckedModeBanner: false,
      routerConfig: salesmanRouter,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488),
          primary: const Color(0xFF0D9488),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
    );
  }
}
