import 'package:eye_tracking_collection/models/user_profile.dart';
import 'package:eye_tracking_collection/widgets/accessible_text_field.dart';
import 'package:eye_tracking_collection/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'collection_grid_screen.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, required this.languageCode});

  static const String routeName = '/user-form';
  final String languageCode;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _ageController = TextEditingController();
  String _blindnessType = 'Myopia';

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _startCollection() {
    final personId =
        'P-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase().substring(4)}';
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    final profile = UserProfile(
      personId: personId,
      age: age,
      blindnessType: _blindnessType,
      languageCode: widget.languageCode,
      dominantEye: 'both',
      visionAcuity: 5,
      wearsGlasses: false,
      consentGiven: true,
    );
    Navigator.pushNamed(
      context,
      CollectionGridScreen.routeName,
      arguments: CollectionGridArgs(
          profile: profile, languageCode: widget.languageCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageCode;
    return Scaffold(
      appBar: AppBar(title: const Text('Participant Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please enter your details to continue.',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            AccessibleTextField(
              controller: _ageController,
              label: 'Age',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _blindnessType,
              dropdownColor: Colors.black,
              items: const [
                'Myopia',
                'Cataract',
              ]
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _blindnessType = value);
                }
              },
              decoration:
                  const InputDecoration(labelText: 'Partial Blind Type'),
            ),
            const Spacer(),
            PrimaryButton(
                label: 'Start Collection', onPressed: _startCollection),
          ],
        ),
      ),
    );
  }
}
