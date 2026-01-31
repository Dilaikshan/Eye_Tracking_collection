import 'package:eye_tracking_collection/core/constants/app_theme.dart';
import 'package:eye_tracking_collection/core/services/firebase_initializer.dart';
import 'screens/collection_grid_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/user_agreement_screen.dart';
import 'screens/user_form_screen.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseInitializer.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eye Tracking Collection',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.highContrast,
      initialRoute: LanguageSelectionScreen.routeName,
      routes: {
        LanguageSelectionScreen.routeName: (_) => const LanguageSelectionScreen(),
        UserAgreementScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
          final langCode = args?['lang'] ?? 'en';
          return UserAgreementScreen(languageCode: langCode);
        },
        UserFormScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
          final langCode = args?['lang'] ?? 'en';
          return UserFormScreen(languageCode: langCode);
        },
        CollectionGridScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as CollectionGridArgs?;
          return CollectionGridScreen(args: args ?? CollectionGridArgs.empty());
        },
      },
      supportedLocales: const [
        Locale('en'),
        Locale('ta'),
        Locale('si'),
      ],
    );
  }
}
