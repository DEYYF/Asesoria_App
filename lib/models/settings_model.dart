class KanbanColumn {
  final String id;
  final String title;
  final String color;
  final int order;

  KanbanColumn({
    required this.id,
    required this.title,
    required this.color,
    required this.order,
  });

  factory KanbanColumn.fromJson(Map<String, dynamic> json) {
    return KanbanColumn(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      color: json['color'] ?? 'blue',
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'color': color, 'order': order};
  }

  KanbanColumn copyWith({
    String? id,
    String? title,
    String? color,
    int? order,
  }) {
    return KanbanColumn(
      id: id ?? this.id,
      title: title ?? this.title,
      color: color ?? this.color,
      order: order ?? this.order,
    );
  }
}

class PdfSettings {
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String logoUrl;
  final String headerTitle;
  final String footerText;
  final String footerContactInfo;
  final String fontFamily;
  final bool includeCoverPage;
  final String headerStyle;
  final bool showMacrosSummary;

  // Layout & Spacing
  final String pageMargins;
  final double lineSpacing;
  final double sectionSpacing;

  // Typography
  final double headerFontSize;
  final double bodyFontSize;
  final double tableFontSize;

  // Table Styling
  final String tableBorderStyle;
  final bool alternateRowColors;
  final String tableHeaderColor;

  // Branding
  final String watermarkText;
  final double watermarkOpacity;
  final String logoSize;
  final String logoPosition;

  // Advanced
  final String pageOrientation;
  final bool showPageNumbers;
  final String dateFormat;
  final String currencySymbol;

  PdfSettings({
    this.primaryColor = '#007AFF',
    this.secondaryColor = '#34C759',
    this.accentColor = '#FFD700',
    this.logoUrl = '',
    this.headerTitle = 'Asesoría Pro',
    this.footerText = 'Gracias por confiar en nuestros servicios.',
    this.footerContactInfo = '',
    this.fontFamily = 'Helvetica',
    this.includeCoverPage = false,
    this.headerStyle = 'classic',
    this.showMacrosSummary = true,
    this.pageMargins = 'medium',
    this.lineSpacing = 1.2,
    this.sectionSpacing = 20,
    this.headerFontSize = 18,
    this.bodyFontSize = 10,
    this.tableFontSize = 9,
    this.tableBorderStyle = 'light',
    this.alternateRowColors = false,
    this.tableHeaderColor = '',
    this.watermarkText = '',
    this.watermarkOpacity = 0.1,
    this.logoSize = 'medium',
    this.logoPosition = 'header',
    this.pageOrientation = 'auto',
    this.showPageNumbers = true,
    this.dateFormat = 'DD/MM/YYYY',
    this.currencySymbol = '€',
  });

  factory PdfSettings.fromJson(Map<String, dynamic> json) {
    return PdfSettings(
      primaryColor: json['primaryColor'] ?? '#007AFF',
      secondaryColor: json['secondaryColor'] ?? '#34C759',
      accentColor: json['accentColor'] ?? '#FFD700',
      logoUrl: json['logoUrl'] ?? '',
      headerTitle: json['headerTitle'] ?? 'Asesoría Pro',
      footerText:
          json['footerText'] ?? 'Gracias por confiar en nuestros servicios.',
      footerContactInfo: json['footerContactInfo'] ?? '',
      fontFamily: json['fontFamily'] ?? 'Helvetica',
      includeCoverPage: json['includeCoverPage'] ?? false,
      headerStyle: json['headerStyle'] ?? 'classic',
      showMacrosSummary: json['showMacrosSummary'] ?? true,
      pageMargins: json['pageMargins'] ?? 'medium',
      lineSpacing: (json['lineSpacing'] ?? 1.2).toDouble(),
      sectionSpacing: (json['sectionSpacing'] ?? 20).toDouble(),
      headerFontSize: (json['headerFontSize'] ?? 18).toDouble(),
      bodyFontSize: (json['bodyFontSize'] ?? 10).toDouble(),
      tableFontSize: (json['tableFontSize'] ?? 9).toDouble(),
      tableBorderStyle: json['tableBorderStyle'] ?? 'light',
      alternateRowColors: json['alternateRowColors'] ?? false,
      tableHeaderColor: json['tableHeaderColor'] ?? '',
      watermarkText: json['watermarkText'] ?? '',
      watermarkOpacity: (json['watermarkOpacity'] ?? 0.1).toDouble(),
      logoSize: json['logoSize'] ?? 'medium',
      logoPosition: json['logoPosition'] ?? 'header',
      pageOrientation: json['pageOrientation'] ?? 'auto',
      showPageNumbers: json['showPageNumbers'] ?? true,
      dateFormat: json['dateFormat'] ?? 'DD/MM/YYYY',
      currencySymbol: json['currencySymbol'] ?? '€',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'accentColor': accentColor,
      'logoUrl': logoUrl,
      'headerTitle': headerTitle,
      'footerText': footerText,
      'footerContactInfo': footerContactInfo,
      'fontFamily': fontFamily,
      'includeCoverPage': includeCoverPage,
      'headerStyle': headerStyle,
      'showMacrosSummary': showMacrosSummary,
      'pageMargins': pageMargins,
      'lineSpacing': lineSpacing,
      'sectionSpacing': sectionSpacing,
      'headerFontSize': headerFontSize,
      'bodyFontSize': bodyFontSize,
      'tableFontSize': tableFontSize,
      'tableBorderStyle': tableBorderStyle,
      'alternateRowColors': alternateRowColors,
      'tableHeaderColor': tableHeaderColor,
      'watermarkText': watermarkText,
      'watermarkOpacity': watermarkOpacity,
      'logoSize': logoSize,
      'logoPosition': logoPosition,
      'pageOrientation': pageOrientation,
      'showPageNumbers': showPageNumbers,
      'dateFormat': dateFormat,
      'currencySymbol': currencySymbol,
    };
  }

  PdfSettings copyWith({
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? logoUrl,
    String? headerTitle,
    String? footerText,
    String? footerContactInfo,
    String? fontFamily,
    bool? includeCoverPage,
    String? headerStyle,
    bool? showMacrosSummary,
    String? pageMargins,
    double? lineSpacing,
    double? sectionSpacing,
    double? headerFontSize,
    double? bodyFontSize,
    double? tableFontSize,
    String? tableBorderStyle,
    bool? alternateRowColors,
    String? tableHeaderColor,
    String? watermarkText,
    double? watermarkOpacity,
    String? logoSize,
    String? logoPosition,
    String? pageOrientation,
    bool? showPageNumbers,
    String? dateFormat,
    String? currencySymbol,
  }) {
    return PdfSettings(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      logoUrl: logoUrl ?? this.logoUrl,
      headerTitle: headerTitle ?? this.headerTitle,
      footerText: footerText ?? this.footerText,
      footerContactInfo: footerContactInfo ?? this.footerContactInfo,
      fontFamily: fontFamily ?? this.fontFamily,
      includeCoverPage: includeCoverPage ?? this.includeCoverPage,
      headerStyle: headerStyle ?? this.headerStyle,
      showMacrosSummary: showMacrosSummary ?? this.showMacrosSummary,
      pageMargins: pageMargins ?? this.pageMargins,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      sectionSpacing: sectionSpacing ?? this.sectionSpacing,
      headerFontSize: headerFontSize ?? this.headerFontSize,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      tableFontSize: tableFontSize ?? this.tableFontSize,
      tableBorderStyle: tableBorderStyle ?? this.tableBorderStyle,
      alternateRowColors: alternateRowColors ?? this.alternateRowColors,
      tableHeaderColor: tableHeaderColor ?? this.tableHeaderColor,
      watermarkText: watermarkText ?? this.watermarkText,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      logoSize: logoSize ?? this.logoSize,
      logoPosition: logoPosition ?? this.logoPosition,
      pageOrientation: pageOrientation ?? this.pageOrientation,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      dateFormat: dateFormat ?? this.dateFormat,
      currencySymbol: currencySymbol ?? this.currencySymbol,
    );
  }
}

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
  final bool enabledFinanzas;
  final List<KanbanColumn> kanbanColumns;
  final PdfSettings pdfSettings;

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
    this.enabledFinanzas = true,
    this.kanbanColumns = const [],
    required this.pdfSettings,
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
      enabledFinanzas: json['enabledFinanzas'] ?? true,
      kanbanColumns:
          (json['kanbanColumns'] as List?)
              ?.map((c) => KanbanColumn.fromJson(c))
              .toList() ??
          [],
      pdfSettings: json['pdfSettings'] != null
          ? PdfSettings.fromJson(json['pdfSettings'])
          : PdfSettings(),
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
      'enabledFinanzas': enabledFinanzas,
      'kanbanColumns': kanbanColumns.map((c) => c.toJson()).toList(),
      'pdfSettings': pdfSettings.toJson(),
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
    bool? enabledFinanzas,
    List<KanbanColumn>? kanbanColumns,
    PdfSettings? pdfSettings,
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
      enabledFinanzas: enabledFinanzas ?? this.enabledFinanzas,
      kanbanColumns: kanbanColumns ?? this.kanbanColumns,
      pdfSettings: pdfSettings ?? this.pdfSettings,
    );
  }
}
