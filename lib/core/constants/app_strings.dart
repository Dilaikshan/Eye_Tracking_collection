class AppStrings {
  // Language options
  static const Map<String, Map<String, String>> translations = {
    'en': {
      'app_title': 'Eye Tracking Research',
      'select_language': 'Select Language',
      'english': 'English',
      'sinhala': 'සිංහල',
      'tamil': 'தமிழ்',
      'next': 'Next',
      'start': 'Start',
      'profile_title': 'Participant Information',
      'name': 'Name',
      'age': 'Age',
      'blindness_type': 'Type of Vision Impairment',
      'dominant_eye': 'Dominant Eye',
      'vision_acuity': 'Vision Clarity (1-10)',
      'wears_glasses': 'Wears Glasses',
      'consent': 'I consent to data collection for research',
      'guideline_1': 'Hold the phone at chest level or place on stable surface',
      'guideline_2': 'Ensure your face is visible to front camera',
      'guideline_3': 'Avoid strong light behind you',
      'guideline_4': 'Follow voice instructions carefully',
      'guideline_5': 'Only eye coordinates collected, no video stored',
      'align_head': 'Align your head to the frame',
      'i_am_aligned': 'I am aligned',
      'start_collection': 'Start Data Collection',
      'look_at': 'Look at the',
      'color': 'color',
      'follow_moving': 'Follow the moving point',
      'slow': 'slowly',
      'medium': 'at medium speed',
      'fast': 'quickly',
      'calibration': 'Calibration',
      'pulse': 'Pulse Phase',
      'moving': 'Moving Phase',
      'complete': 'Session Complete',
    },
    'ta': {
      'app_title': 'கண் கண்காணிப்பு ஆராய்ச்சி',
      'select_language': 'மொழியை தேர்ந்தெடுக்கவும்',
      'english': 'English',
      'sinhala': 'සිංහල',
      'tamil': 'தமிழ்',
      'next': 'அடுத்து',
      'start': 'தொடங்கு',
    },
    'si': {
      'app_title': 'ඇස් ලුහුබැඳීමේ පර්යේෂණය',
      'select_language': 'භාෂාව තෝරන්න',
      'english': 'English',
      'sinhala': 'සිංහල',
      'tamil': 'தமிழ்',
      'next': 'ඊළඟ',
      'start': 'ආරම්භ කරන්න',
    },
  };

  static String get(String key, String languageCode) {
    return translations[languageCode]?[key] ?? translations['en']![key]!;
  }

  // Legacy support
  static const Map<String, String> languageNames = {
    'en': 'English',
    'ta': 'Tamil',
    'si': 'Sinhala',
  };

  static const Map<String, String> agreements = {
    'en':
        'This research collects eye coordination data only. No personally identifying video is stored.',
    'ta':
        'இந்த ஆராய்ச்சி கண் ஒருங்கிணைப்புத் தரவை மட்டுமே சேகரிக்கிறது. எவ்வித தனிப்பட்ட வீடியோவும் சேமிக்கப்படாது.',
    'si':
        'මෙම පර්යේෂණය ඇස් සම්බන්ධීකරණ දත්ත පමණක් රැස් කරයි. පුද්ගලික වීඩියෝ කිසිවිටෙකත් තැන්පත් නොකරයි.',
  };

  static String agreementFor(String code) =>
      agreements[code] ?? agreements['en']!;
  static String languageLabel(String code) => languageNames[code] ?? code;
}
