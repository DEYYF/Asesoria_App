class UserSettings {
  final bool pushNotifications;
  final bool emailNotifications;
  final String theme; // 'light', 'dark', 'system'
  final String accentColor;
  final String? emailSignature; // admin only
  final String? signatureImageUrl; // admin only
  final String? businessEmail; // admin only
  final String weightFrequency;
  final String fatFrequency;
  final String measuresFrequency;
  final String muscleFrequency;

  UserSettings({
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.theme = 'system',
    this.accentColor = '#007AFF',
    this.emailSignature,
    this.signatureImageUrl,
    this.businessEmail,
    this.weightFrequency = 'weekly',
    this.fatFrequency = 'weekly',
    this.measuresFrequency = 'monthly',
    this.muscleFrequency = 'monthly',
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      pushNotifications: json['pushNotifications'] ?? true,
      emailNotifications: json['emailNotifications'] ?? true,
      theme: json['theme'] ?? 'system',
      accentColor: json['accentColor'] ?? '#007AFF',
      emailSignature: json['emailSignature'],
      signatureImageUrl: json['signatureImageUrl'],
      businessEmail: json['businessEmail'],
      weightFrequency: json['weightFrequency'] ?? 'weekly',
      fatFrequency: json['fatFrequency'] ?? 'weekly',
      measuresFrequency: json['measuresFrequency'] ?? 'monthly',
      muscleFrequency: json['muscleFrequency'] ?? 'monthly',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pushNotifications': pushNotifications,
      'emailNotifications': emailNotifications,
      'theme': theme,
      'accentColor': accentColor,
      if (emailSignature != null) 'emailSignature': emailSignature,
      if (signatureImageUrl != null) 'signatureImageUrl': signatureImageUrl,
      if (businessEmail != null) 'businessEmail': businessEmail,
      'weightFrequency': weightFrequency,
      'fatFrequency': fatFrequency,
      'measuresFrequency': measuresFrequency,
      'muscleFrequency': muscleFrequency,
    };
  }

  UserSettings copyWith({
    bool? pushNotifications,
    bool? emailNotifications,
    String? theme,
    String? accentColor,
    String? emailSignature,
    String? signatureImageUrl,
    String? businessEmail,
    String? weightFrequency,
    String? fatFrequency,
    String? measuresFrequency,
    String? muscleFrequency,
  }) {
    return UserSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      theme: theme ?? this.theme,
      accentColor: accentColor ?? this.accentColor,
      emailSignature: emailSignature ?? this.emailSignature,
      signatureImageUrl: signatureImageUrl ?? this.signatureImageUrl,
      businessEmail: businessEmail ?? this.businessEmail,
      weightFrequency: weightFrequency ?? this.weightFrequency,
      fatFrequency: fatFrequency ?? this.fatFrequency,
      measuresFrequency: measuresFrequency ?? this.measuresFrequency,
      muscleFrequency: muscleFrequency ?? this.muscleFrequency,
    );
  }
}
