class UserProfile {
  final String name;
  final int age;
  final String blindnessType;
  final String dominantEye;
  final int visionAcuity;
  final bool wearsGlasses;
  final String languageCode;
  final bool consentGiven;
  final DateTime createdAt;

  UserProfile({
    required this.name,
    required this.age,
    required this.blindnessType,
    required this.dominantEye,
    required this.visionAcuity,
    required this.wearsGlasses,
    required this.languageCode,
    required this.consentGiven,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'blindnessType': blindnessType,
      'dominantEye': dominantEye,
      'visionAcuity': visionAcuity,
      'wearsGlasses': wearsGlasses,
      'languageCode': languageCode,
      'consentGiven': consentGiven,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      blindnessType: map['blindnessType'] ?? '',
      dominantEye: map['dominantEye'] ?? 'both',
      visionAcuity: map['visionAcuity'] ?? 5,
      wearsGlasses: map['wearsGlasses'] ?? false,
      languageCode: map['languageCode'] ?? 'en',
      consentGiven: map['consentGiven'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }
}
