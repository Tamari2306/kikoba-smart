import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'router/app_router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print("FlutterError: ${details.exception}");
  };

  runApp(const ProviderScope(child: KikobaSmartApp()));
}

class KikobaSmartApp extends ConsumerWidget {
  const KikobaSmartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Kikoba Smart',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          filled: false,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
