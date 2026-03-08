import 'package:eye_tracking_collection/core/constants/app_strings.dart';
import 'package:eye_tracking_collection/core/services/tts_service.dart';
import 'package:eye_tracking_collection/widgets/primary_button.dart';
import 'user_agreement_screen.dart';
import 'package:flutter/material.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  static const String routeName = '/language';

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final TtsService _tts = TtsService();

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _selectLanguage(String code) async {
    await _tts.speak(AppStrings.languageLabel(code));
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      UserAgreementScreen.routeName,
      arguments: {'lang': code},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Language'),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {
              Navigator.pushNamed(context, '/admin-login');
            },
            tooltip: 'Admin Login',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              'Select your preferred language',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            ...AppStrings.languageNames.keys.map(
              (code) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: PrimaryButton(
                  label: AppStrings.languageLabel(code),
                  onPressed: () => _selectLanguage(code),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
