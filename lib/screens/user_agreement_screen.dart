import 'package:eye_tracking_collection/core/constants/app_strings.dart';
import 'package:eye_tracking_collection/widgets/primary_button.dart';
import 'package:flutter/material.dart';

import 'user_form_screen.dart';

class UserAgreementScreen extends StatelessWidget {
  const UserAgreementScreen({super.key, required this.languageCode});

  static const String routeName = '/agreement';
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agreement')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consent', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text(AppStrings.agreementFor(languageCode),
                style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            PrimaryButton(
              label: 'I Agree',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  UserFormScreen.routeName,
                  arguments: {'lang': languageCode},
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
