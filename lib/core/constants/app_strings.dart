class AppStrings {
  static const Map<String, String> languageNames = {
    'en': 'English',
    'ta': 'Tamil',
    'si': 'Sinhala',
  };

  static const Map<String, String> agreements = {
    'en': 'This research collects eye coordination data only. No personally identifying video is stored.',
    'ta': 'இந்த ஆராய்ச்சி கண் ஒருங்கிணைப்புத் தரவை மட்டுமே சேகரிக்கிறது. எவ்வித தனிப்பட்ட வீடியோவும் சேமிக்கப்படாது.',
    'si': 'මෙම පර්යේෂණය ඇස් සම්බන්ධීකරණ දත්ත පමණක් රැස් කරයි. පුද්ගලික වීඩියෝ කිසිවිටෙකත් තැන්පත් නොකරයි.',
  };

  static const Map<String, String> formHints = {
    'en': 'Please enter your details to continue.',
    'ta': 'தொடர உங்கள் விவரங்களை உள்ளிடவும்.',
    'si': 'කරුණාකර ඉදිරියට යාමට ඔබගේ විස්තර ඇතුළත් කරන්න.',
  };

  static String agreementFor(String code) => agreements[code] ?? agreements['en']!;
  static String languageLabel(String code) => languageNames[code] ?? code;
  static String formHint(String code) => formHints[code] ?? formHints['en']!;
}
