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
  final bool enabledChat;
  final bool enabledEmail;
  final bool enabledProgressFrequencies;
  final bool enabledTemplateManagement;
  final bool enabledTrainingLog;
  final bool enabledFoodScanner;
  final bool enabledAutomation;

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
    this.enabledChat = true,
    this.enabledEmail = true,
    this.enabledProgressFrequencies = true,
    this.enabledTemplateManagement = true,
    this.enabledTrainingLog = true,
    this.enabledFoodScanner = true,
    this.enabledAutomation = true,
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
      enabledChat: json['enabledChat'] ?? true,
      enabledEmail: json['enabledEmail'] ?? true,
      enabledProgressFrequencies: json['enabledProgressFrequencies'] ?? true,
      enabledTemplateManagement: json['enabledTemplateManagement'] ?? true,
      enabledTrainingLog: json['enabledTrainingLog'] ?? true,
      enabledFoodScanner: json['enabledFoodScanner'] ?? true,
      enabledAutomation: json['enabledAutomation'] ?? true,
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
      'enabledChat': enabledChat,
      'enabledEmail': enabledEmail,
      'enabledProgressFrequencies': enabledProgressFrequencies,
      'enabledTemplateManagement': enabledTemplateManagement,
      'enabledTrainingLog': enabledTrainingLog,
      'enabledFoodScanner': enabledFoodScanner,
      'enabledAutomation': enabledAutomation,
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
    bool? enabledChat,
    bool? enabledEmail,
    bool? enabledProgressFrequencies,
    bool? enabledTemplateManagement,
    bool? enabledTrainingLog,
    bool? enabledFoodScanner,
    bool? enabledAutomation,
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
      enabledChat: enabledChat ?? this.enabledChat,
      enabledEmail: enabledEmail ?? this.enabledEmail,
      enabledProgressFrequencies:
          enabledProgressFrequencies ?? this.enabledProgressFrequencies,
      enabledTemplateManagement:
          enabledTemplateManagement ?? this.enabledTemplateManagement,
      enabledTrainingLog: enabledTrainingLog ?? this.enabledTrainingLog,
      enabledFoodScanner: enabledFoodScanner ?? this.enabledFoodScanner,
      enabledAutomation: enabledAutomation ?? this.enabledAutomation,
    );
  }
}
