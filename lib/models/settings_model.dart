class UserSettings {
  final bool pushNotifications;
  final bool emailNotifications;
  final String theme; // 'light', 'dark', 'system'
  final String accentColor;
  final String? emailSignature; // admin only
  final String? signatureImageUrl; // admin only
  final String? businessEmail; // admin only

  UserSettings({
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.theme = 'system',
    this.accentColor = '#007AFF',
    this.emailSignature,
    this.signatureImageUrl,
    this.businessEmail,
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
  }) {
    return UserSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      theme: theme ?? this.theme,
      accentColor: accentColor ?? this.accentColor,
      emailSignature: emailSignature ?? this.emailSignature,
      signatureImageUrl: signatureImageUrl ?? this.signatureImageUrl,
      businessEmail: businessEmail ?? this.businessEmail,
    );
  }
}
