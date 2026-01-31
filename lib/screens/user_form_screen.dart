import 'package:eye_tracking_collection/core/constants/app_strings.dart';
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
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _blindnessType = 'Macular Degeneration';

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _startCollection() {
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    final profile = UserProfile(
      name: _nameController.text.trim(),
      age: age,
      blindnessType: _blindnessType,
      languageCode: widget.languageCode,
    );
    Navigator.pushNamed(
      context,
      CollectionGridScreen.routeName,
      arguments: CollectionGridArgs(profile: profile, languageCode: widget.languageCode),
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
            Text(AppStrings.formHint(lang), style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            AccessibleTextField(
              controller: _nameController,
              label: 'Name',
            ),
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
                'Macular Degeneration',
                'Glaucoma',
                'Diabetic Retinopathy',
                'Cataracts',
              ].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _blindnessType = value);
                }
              },
              decoration: const InputDecoration(labelText: 'Partial Blind Type'),
            ),
            const Spacer(),
            PrimaryButton(label: 'Start Collection', onPressed: _startCollection),
          ],
        ),
      ),
    );
  }
}
