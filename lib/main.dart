import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_tracking_collection/screens/language_selection_screen.dart';
import 'package:eye_tracking_collection/screens/user_agreement_screen.dart';
import 'package:eye_tracking_collection/screens/user_form_screen.dart';
import 'package:eye_tracking_collection/screens/collection_grid_screen.dart';
import 'package:eye_tracking_collection/screens/admin_login_screen.dart';
import 'package:eye_tracking_collection/screens/data_viewer_screen.dart';
import 'package:eye_tracking_collection/screens/diagnostic_screen.dart';
import 'package:eye_tracking_collection/screens/permission_screen.dart';
import 'package:eye_tracking_collection/screens/session_summary_screen.dart';
import 'package:eye_tracking_collection/core/constants/app_colors.dart';
import 'package:eye_tracking_collection/core/services/firebase_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await FirebaseInitializer.init();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Determine whether to show the permission screen on first launch
  final prefs = await SharedPreferences.getInstance();
  final permissionsGranted = prefs.getBool('permissions_granted') ?? false;
  final initialRoute = permissionsGranted
      ? LanguageSelectionScreen.routeName
      : PermissionScreen.routeName;

  runApp(EyeTrackingApp(initialRoute: initialRoute));
}

class EyeTrackingApp extends StatelessWidget {
  const EyeTrackingApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eye Tracking Research',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
      ),
      initialRoute: initialRoute,
      routes: {
        PermissionScreen.routeName: (_) => const PermissionScreen(),
        LanguageSelectionScreen.routeName: (_) =>
            const LanguageSelectionScreen(),
        UserAgreementScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, String>?;
          final langCode = args?['lang'] ?? 'en';
          return UserAgreementScreen(languageCode: langCode);
        },
        UserFormScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, String>?;
          final langCode = args?['lang'] ?? 'en';
          return UserFormScreen(languageCode: langCode);
        },
        CollectionGridScreen.routeName: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as CollectionGridArgs?;
          return CollectionGridScreen(args: args ?? CollectionGridArgs.empty());
        },
        AdminLoginScreen.routeName: (_) => const AdminLoginScreen(),
        DataViewerScreen.routeName: (_) => const DataViewerScreen(),
        DiagnosticScreen.routeName: (_) => const DiagnosticScreen(),
        SessionSummaryScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as SessionSummaryArgs?;
          if (args == null) {
            return const Scaffold(
                body: Center(child: Text('No session args')));
          }
          return SessionSummaryScreen(args: args);
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
