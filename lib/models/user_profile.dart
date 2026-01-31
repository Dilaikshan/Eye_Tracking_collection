class UserProfile {
  const UserProfile({
    required this.name,
    required this.age,
    required this.blindnessType,
    required this.languageCode,
  });

  final String name;
  final int age;
  final String blindnessType;
  final String languageCode;
}
