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
      'guideline_5':
          'Only small grayscale eye region images and coordinates are collected. No face photos or video are stored.',
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
        'This research study collects two types of data from your eyes during the session:\n\n1. Eye landmark coordinates — numerical positions of your iris and pupil detected by the front camera.\n\n2. Cropped grayscale eye images — small 64x64 pixel photographs of your eye region only, not your full face. These images are converted to grayscale and are used solely to train a gaze estimation model for assistive technology research.\n\nNo full face photos, video recordings, or personally identifying images are stored at any time. All data is stored securely and used only for this academic research project at South Eastern University of Sri Lanka.',
    'ta':
        'இந்த ஆராய்ச்சி இரண்டு வகையான கண் தரவுகளை சேகரிக்கிறது: கண் நிலை ஒருங்கிணைப்புகள் மற்றும் 64x64 பிக்சல் அளவிலான சாம்பல் நிற கண் படங்கள் மட்டுமே. முழு முகப் படங்களோ வீடியோவோ சேமிக்கப்படுவதில்லை. இந்தத் தரவு தென்கிழக்கு பல்கலைக்கழகத்தின் ஆராய்ச்சி நோக்கங்களுக்காக மட்டுமே பயன்படுத்தப்படும்.',
    'si':
        'මෙම පර්යේෂණය ඇස් ඛණ්ඩාංක සහ 64x64 පික්සල් ප්‍රමාණයේ අළු පාට ඇස් කලාපීය රූප පමණක් රැස් කරයි. මුළු මුහුණේ ඡායාරූප හෝ වීඩියෝ කිසිවිටෙකත් ගබඩා නොකරයි. මෙම දත්ත ගිනිකොනදිග විශ්ව විද්‍යාලයේ ශෛක්ෂණික පර්යේෂණ අරමුණු සඳහා පමණක් භාවිත වේ.',
  };

  static String agreementFor(String code) =>
      agreements[code] ?? agreements['en']!;
  static String languageLabel(String code) => languageNames[code] ?? code;
}
