class UserProfile {
  final int id;
  final String name;
  final String email;
  final String avatarPath;
  final String healthGoal;
  final String wakeTime;
  final String bedtime;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String? emergencyContact;
  final bool isSetupCompleted;

  const UserProfile({
    this.id = 1,
    this.name = 'Livia Vaccaro',
    this.email = 'livia.vaccaro@example.com',
    this.avatarPath = 'assets/images/user_avatar.png',
    this.healthGoal = 'Never miss a daily dose',
    this.wakeTime = '08:00 AM',
    this.bedtime = '10:00 PM',
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.emergencyContact,
    this.isSetupCompleted = false,
  });

  UserProfile copyWith({
    int? id,
    String? name,
    String? email,
    String? avatarPath,
    String? healthGoal,
    String? wakeTime,
    String? bedtime,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? emergencyContact,
    bool? isSetupCompleted,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarPath: avatarPath ?? this.avatarPath,
      healthGoal: healthGoal ?? this.healthGoal,
      wakeTime: wakeTime ?? this.wakeTime,
      bedtime: bedtime ?? this.bedtime,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      isSetupCompleted: isSetupCompleted ?? this.isSetupCompleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar_path': avatarPath,
        'health_goal': healthGoal,
        'wake_time': wakeTime,
        'bedtime': bedtime,
        'sound_enabled': soundEnabled ? 1 : 0,
        'vibration_enabled': vibrationEnabled ? 1 : 0,
        'emergency_contact': emergencyContact,
        'is_setup_completed': isSetupCompleted ? 1 : 0,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as int? ?? 1,
        name: map['name'] as String? ?? 'Livia Vaccaro',
        email: map['email'] as String? ?? 'livia.vaccaro@example.com',
        avatarPath: map['avatar_path'] as String? ?? 'assets/images/user_avatar.png',
        healthGoal: map['health_goal'] as String? ?? 'Never miss a daily dose',
        wakeTime: map['wake_time'] as String? ?? '08:00 AM',
        bedtime: map['bedtime'] as String? ?? '10:00 PM',
        soundEnabled: (map['sound_enabled'] as int? ?? 1) == 1,
        vibrationEnabled: (map['vibration_enabled'] as int? ?? 1) == 1,
        emergencyContact: map['emergency_contact'] as String?,
        isSetupCompleted: (map['is_setup_completed'] as int? ?? 0) == 1,
      );
}
