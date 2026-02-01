import 'package:flutter/material.dart';
import 'package:eye_tracking_collection/core/constants/app_colors.dart';
import 'package:eye_tracking_collection/models/user_profile.dart';
import 'package:eye_tracking_collection/screens/collection_grid_screen.dart';
import 'package:eye_tracking_collection/core/services/tts_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String languageCode;

  const UserProfileScreen({super.key, required this.languageCode});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TtsService _tts = TtsService();

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String _blindnessType = 'Macular Degeneration';
  String _dominantEye = 'both';
  int _visionAcuity = 5;
  bool _wearsGlasses = false;
  bool _consentGiven = false;

  final List<String> _blindnessTypes = [
    'Macular Degeneration',
    'Glaucoma',
    'Diabetic Retinopathy',
    'Cataracts (Partial)',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tts.initialize(widget.languageCode);
    _speakInstructions();
  }

  Future<void> _speakInstructions() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _tts.speak('Please enter your information to begin data collection.');
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      _tts.speak('Please fill all required fields');
      return;
    }

    if (!_consentGiven) {
      _tts.speak('Please provide consent to continue');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide consent to continue')),
      );
      return;
    }

    final profile = UserProfile(
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text),
      blindnessType: _blindnessType,
      dominantEye: _dominantEye,
      visionAcuity: _visionAcuity,
      wearsGlasses: _wearsGlasses,
      languageCode: widget.languageCode,
      consentGiven: _consentGiven,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionGridScreen(
          args: CollectionGridArgs(
            profile: profile,
            languageCode: widget.languageCode,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Participant Information'),
        backgroundColor: AppColors.surface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Name',
                  hint: 'Enter your name',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _ageController,
                  label: 'Age',
                  hint: 'Enter your age',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your age';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 18 || age > 100) {
                      return 'Please enter a valid age (18-100)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildDropdown(
                  label: 'Type of Vision Impairment',
                  value: _blindnessType,
                  items: _blindnessTypes,
                  onChanged: (value) {
                    setState(() {
                      _blindnessType = value!;
                    });
                    _tts.speak(value!);
                  },
                ),
                const SizedBox(height: 20),
                _buildDropdown(
                  label: 'Dominant Eye',
                  value: _dominantEye,
                  items: const ['left', 'right', 'both'],
                  onChanged: (value) {
                    setState(() {
                      _dominantEye = value!;
                    });
                    _tts.speak(value!);
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Vision Clarity (1-10): $_visionAcuity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: _visionAcuity.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: _visionAcuity.toString(),
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    setState(() {
                      _visionAcuity = value.toInt();
                    });
                  },
                  onChangeEnd: (value) {
                    _tts.speak('Vision clarity ${value.toInt()}');
                  },
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text(
                    'Wears Glasses',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  value: _wearsGlasses,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    setState(() {
                      _wearsGlasses = value;
                    });
                    _tts.speak(
                        value ? 'Wears glasses' : 'Does not wear glasses');
                  },
                ),
                const SizedBox(height: 20),
                CheckboxListTile(
                  title: const Text(
                    'I consent to eye tracking data collection for research purposes',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  value: _consentGiven,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    setState(() {
                      _consentGiven = value ?? false;
                    });
                    _tts.speak(value! ? 'Consent given' : 'Consent removed');
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Continue to Data Collection'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
