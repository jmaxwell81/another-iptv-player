/// Types of auto-combine rules
enum AutoCombineRuleType {
  /// Merge categories containing specific keywords into a single category
  mergeByKeyword,

  /// Hide categories matching specific country/region patterns
  hideByCountry,
}

/// A single auto-combine rule
class AutoCombineRule {
  final String id;
  final AutoCombineRuleType type;
  final String name;
  final List<String> patterns;
  final String? targetCategoryName; // For merge rules, the name to merge into
  final bool enabled;
  final bool isBuiltIn; // Built-in rules can't be deleted, only disabled

  const AutoCombineRule({
    required this.id,
    required this.type,
    required this.name,
    required this.patterns,
    this.targetCategoryName,
    this.enabled = true,
    this.isBuiltIn = false,
  });

  AutoCombineRule copyWith({
    String? id,
    AutoCombineRuleType? type,
    String? name,
    List<String>? patterns,
    String? targetCategoryName,
    bool? enabled,
    bool? isBuiltIn,
  }) {
    return AutoCombineRule(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      patterns: patterns ?? this.patterns,
      targetCategoryName: targetCategoryName ?? this.targetCategoryName,
      enabled: enabled ?? this.enabled,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'name': name,
    'patterns': patterns,
    'targetCategoryName': targetCategoryName,
    'enabled': enabled,
    'isBuiltIn': isBuiltIn,
  };

  factory AutoCombineRule.fromJson(Map<String, dynamic> json) {
    return AutoCombineRule(
      id: json['id'] as String,
      type: AutoCombineRuleType.values[json['type'] as int],
      name: json['name'] as String,
      patterns: List<String>.from(json['patterns'] as List),
      targetCategoryName: json['targetCategoryName'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  /// Check if a category name matches any of this rule's patterns
  bool matchesCategory(String categoryName) {
    final upperName = categoryName.toUpperCase();
    for (final pattern in patterns) {
      final upperPattern = pattern.toUpperCase();
      // Support simple wildcard matching
      if (upperPattern.contains('*')) {
        final regex = RegExp(
          '^${upperPattern.replaceAll('*', '.*')}\$',
          caseSensitive: false,
        );
        if (regex.hasMatch(upperName)) return true;
      } else {
        // Simple contains match
        if (upperName.contains(upperPattern)) return true;
      }
    }
    return false;
  }
}

/// Configuration for all auto-combine rules
class AutoCombineConfig {
  final bool enabled;
  final bool mergeKidsCategories;
  final bool mergeGenreCategories;
  final bool hideNonEnglishCountries;
  final bool consolidateLiveChannels; // Consolidate duplicate channel variants
  final List<AutoCombineRule> customRules;

  // English-speaking countries/prefixes to NOT hide (customizable)
  final List<String> englishSpeakingCountries;

  const AutoCombineConfig({
    this.enabled = true,
    this.mergeKidsCategories = true,
    this.mergeGenreCategories = true,
    this.hideNonEnglishCountries = false,
    this.consolidateLiveChannels = true,
    this.customRules = const [],
    this.englishSpeakingCountries = const [
      // Country codes and names
      'US', 'USA', 'AMERICA', 'UNITED STATES',
      'UK', 'GB', 'ENGLAND', 'BRITAIN', 'UNITED KINGDOM',
      'AU', 'AUSTRALIA', 'AUSTRALIAN',
      'CA', 'CANADA', 'CANADIAN',
      // Note: IE (Ireland) and NZ (New Zealand) removed - user preference
      // Common prefixes for English/American content
      'AM', // America prefix (e.g., "AM | USA")
      'EN', // English prefix (e.g., "EN - ACTION")
      'ENGLISH',
      // TV Service provider names (not countries)
      'SL', 'SLING', // Sling TV
      'DI', 'DIRECTV', 'DIREC', // DirecTV
      'DTV', // DirecTV abbreviation
      'FU', 'FUBO', // FuboTV
      'YT', 'YTTV', // YouTube TV
      'HU', 'HULU', // Hulu
      'PH', 'PHILO', // Philo
      'PL', 'PLUTO', // Pluto TV
      'PE', 'PEACOCK', // Peacock
      'PA', 'PARAMOUNT', // Paramount+
      'VI', 'VIDGO', // Vidgo
      'FRNDLY', // Frndly TV (note: FR removed as it conflicts with France)
      'SP', 'SPECTRUM', // Spectrum
      'XF', 'XFINITY', // Xfinity
      'AT', 'ATT', // AT&T
      'VE', 'VERIZON', // Verizon
      'CO', 'COMCAST', // Comcast
      'CH', 'CHARTER', // Charter
      'DISH', // Dish Network
      'PR', 'PRIME', 'AMAZON', // Amazon Prime
      'NE', 'NETFLIX', // Netflix
      'HB', 'HBO', 'HBOMAX', // HBO Max
      'AP', 'APPLE', 'APPLETV', // Apple TV+
      'DISNEY', // Disney+
    ],
  });

  AutoCombineConfig copyWith({
    bool? enabled,
    bool? mergeKidsCategories,
    bool? mergeGenreCategories,
    bool? hideNonEnglishCountries,
    bool? consolidateLiveChannels,
    List<AutoCombineRule>? customRules,
    List<String>? englishSpeakingCountries,
  }) {
    return AutoCombineConfig(
      enabled: enabled ?? this.enabled,
      mergeKidsCategories: mergeKidsCategories ?? this.mergeKidsCategories,
      mergeGenreCategories: mergeGenreCategories ?? this.mergeGenreCategories,
      hideNonEnglishCountries: hideNonEnglishCountries ?? this.hideNonEnglishCountries,
      consolidateLiveChannels: consolidateLiveChannels ?? this.consolidateLiveChannels,
      customRules: customRules ?? this.customRules,
      englishSpeakingCountries: englishSpeakingCountries ?? this.englishSpeakingCountries,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'mergeKidsCategories': mergeKidsCategories,
    'mergeGenreCategories': mergeGenreCategories,
    'hideNonEnglishCountries': hideNonEnglishCountries,
    'consolidateLiveChannels': consolidateLiveChannels,
    'customRules': customRules.map((r) => r.toJson()).toList(),
    'englishSpeakingCountries': englishSpeakingCountries,
  };

  factory AutoCombineConfig.fromJson(Map<String, dynamic> json) {
    return AutoCombineConfig(
      enabled: json['enabled'] as bool? ?? true,
      mergeKidsCategories: json['mergeKidsCategories'] as bool? ?? true,
      mergeGenreCategories: json['mergeGenreCategories'] as bool? ?? true,
      hideNonEnglishCountries: json['hideNonEnglishCountries'] as bool? ?? false,
      consolidateLiveChannels: json['consolidateLiveChannels'] as bool? ?? true,
      customRules: (json['customRules'] as List?)
          ?.map((r) => AutoCombineRule.fromJson(r as Map<String, dynamic>))
          .toList() ?? [],
      englishSpeakingCountries: (json['englishSpeakingCountries'] as List?)
          ?.map((e) => e as String)
          .toList() ?? const [
        'US', 'USA', 'AMERICA', 'UNITED STATES',
        'UK', 'GB', 'ENGLAND', 'BRITAIN', 'UNITED KINGDOM',
        'AU', 'AUSTRALIA', 'AUSTRALIAN',
        'CA', 'CANADA', 'CANADIAN',
        // Note: IE/NZ removed, FR removed (conflicts with France)
        'AM', 'EN', 'ENGLISH',
        // TV Service provider names
        'SL', 'SLING', 'DI', 'DIRECTV', 'DIREC', 'DTV', 'FU', 'FUBO',
        'YT', 'YTTV', 'HU', 'HULU', 'PH', 'PHILO', 'PL', 'PLUTO',
        'PE', 'PEACOCK', 'PA', 'PARAMOUNT', 'VI', 'VIDGO', 'FRNDLY',
        'SP', 'SPECTRUM', 'XF', 'XFINITY', 'AT', 'ATT', 'VE', 'VERIZON',
        'CO', 'COMCAST', 'CH', 'CHARTER', 'DISH', 'PR', 'PRIME', 'AMAZON',
        'NE', 'NETFLIX', 'HB', 'HBO', 'HBOMAX', 'AP', 'APPLE', 'APPLETV',
        'DISNEY',
      ],
    );
  }

  /// Known US/UK TV channel names for consolidation
  static const List<String> knownChannelNames = [
    // Major US Networks
    'CBS', 'NBC', 'ABC', 'FOX', 'PBS', 'CW', 'THE CW',
    // Cable Networks
    'TNT', 'TBS', 'USA', 'FX', 'FXX', 'AMC', 'SYFY', 'BRAVO',
    'E!', 'LIFETIME', 'HALLMARK', 'HISTORY', 'A&E', 'DISCOVERY',
    'TLC', 'HGTV', 'FOOD NETWORK', 'TRAVEL', 'ANIMAL PLANET',
    'NATIONAL GEOGRAPHIC', 'NAT GEO', 'NATGEO',
    // News
    'CNN', 'MSNBC', 'FOX NEWS', 'CNBC', 'HLN', 'NEWSMAX', 'OAN',
    'BBC NEWS', 'BBC AMERICA', 'BBC',
    // Sports
    'ESPN', 'ESPN2', 'ESPNU', 'ESPN NEWS', 'FS1', 'FS2', 'NBCSN',
    'NFL NETWORK', 'NBA TV', 'MLB NETWORK', 'NHL NETWORK',
    'CBS SPORTS', 'FOX SPORTS', 'BEIN SPORTS', 'GOLF',
    // Premium
    'HBO', 'SHOWTIME', 'STARZ', 'CINEMAX', 'EPIX',
    // Kids
    'NICKELODEON', 'NICK', 'CARTOON NETWORK', 'DISNEY', 'DISNEY JR',
    'DISNEY XD', 'NICK JR', 'BOOMERANG', 'UNIVERSAL KIDS',
    // Movies
    'TCM', 'TURNER CLASSIC', 'SUNDANCE', 'IFC',
    // Music
    'MTV', 'VH1', 'CMT', 'BET',
    // UK Channels
    'ITV', 'ITV2', 'ITV3', 'ITV4', 'CHANNEL 4', 'CHANNEL 5',
    'SKY', 'SKY ONE', 'SKY NEWS', 'SKY SPORTS',
    // Streaming/Other
    'PARAMOUNT', 'PEACOCK', 'PLUTO',
  ];

  /// Default built-in genre keywords for merging
  /// These detect genres even in category names like "AM | USA THRILLER TV"
  static const List<String> defaultGenreKeywords = [
    'DRAMA',
    'COMEDY',
    'HORROR',
    'ACTION',
    'THRILLER', 'SUSPENSE',
    'DOCUMENTARY', 'DOCU',
    'ROMANCE', 'ROMANTIC',
    'CRIME',
    'MYSTERY',
    'WESTERN',
    'ANIMATION', 'ANIMATED', 'ANIME', 'CARTOON',
    'FANTASY',
    'SCI-FI', 'SCIFI', 'SCIENCE FICTION',
    'ADVENTURE',
    'MUSICAL',
    'WAR', 'MILITARY',
    'BIOGRAPHY', 'BIO', 'BIOPIC',
    'FAMILY',
    'HISTORY', 'HISTORICAL',
    'SPORTS', 'SPORT',
    'NEWS',
    'REALITY',
  ];

  /// Default country patterns for detection
  static const List<String> defaultCountryPatterns = [
    // European countries (non-English)
    'FRANCE', 'FRENCH', 'FR |', 'FR|',
    'GERMANY', 'GERMAN', 'DE |', 'DE|', 'DEUTSCH',
    'SPAIN', 'SPANISH', 'ES |', 'ES|', 'ESPANA',
    'ITALY', 'ITALIAN', 'IT |', 'IT|', 'ITALIA',
    'PORTUGAL', 'PORTUGUESE', 'PT |', 'PT|',
    'NETHERLANDS', 'DUTCH', 'NL |', 'NL|', 'HOLLAND',
    'BELGIUM', 'BELGIAN', 'BE |', 'BE|',
    'POLAND', 'POLISH', 'PL |', 'PL|', 'POLSKA',
    'ROMANIA', 'ROMANIAN', 'RO |', 'RO|',
    'GREECE', 'GREEK', 'GR |', 'GR|',
    'TURKEY', 'TURKISH', 'TR |', 'TR|', 'TURK',
    'SWEDEN', 'SWEDISH', 'SE |', 'SE|',
    'NORWAY', 'NORWEGIAN', 'NO |', 'NO|',
    'DENMARK', 'DANISH', 'DK |', 'DK|',
    'FINLAND', 'FINNISH', 'FI |', 'FI|',
    'RUSSIA', 'RUSSIAN', 'RU |', 'RU|',
    'UKRAINE', 'UKRAINIAN', 'UA |', 'UA|',
    'CZECH', 'CZ |', 'CZ|',
    'HUNGARY', 'HUNGARIAN', 'HU |', 'HU|',
    'AUSTRIA', 'AUSTRIAN', 'AT |', 'AT|',
    'SWITZERLAND', 'SWISS', 'CH |', 'CH|',
    'SERBIA', 'SERBIAN', 'RS |', 'RS|',
    'CROATIA', 'CROATIAN', 'HR |', 'HR|',
    'BULGARIA', 'BULGARIAN', 'BG |', 'BG|',
    'ALBANIA', 'ALBANIAN', 'ALB|', 'AL |', 'AL|',
    // Middle East
    'ARAB', 'ARABIC', 'ARABE',
    'ISRAEL', 'ISRAELI', 'HEBREW', 'IL |', 'IL|',
    'IRAN', 'PERSIAN', 'FARSI',
    'KURDISH', 'KURD',
    // Asia
    'ASIA', 'ASIA|', 'ASIA |', 'ASIAN',
    'CHINA', 'CHINESE', 'CN |', 'CN|', 'MANDARIN',
    'JAPAN', 'JAPANESE', 'JP |', 'JP|',
    'KOREA', 'KOREAN', 'KR |', 'KR|',
    'INDIA', 'INDIAN', 'IN |', 'IN|', 'HINDI', 'TAMIL', 'TELUGU', 'PUNJABI',
    'PAKISTAN', 'PAKISTANI', 'PK |', 'PK|', 'URDU',
    'THAILAND', 'THAI', 'TH |', 'TH|',
    'VIETNAM', 'VIETNAMESE', 'VN |', 'VN|',
    'INDONESIA', 'INDONESIAN', 'ID |', 'ID|',
    'MALAYSIA', 'MALAYSIAN', 'MY |', 'MY|', 'MALAY',
    'PHILIPPINES', 'FILIPINO', 'PH |', 'PH|', 'TAGALOG',
    'SINGAPORE', 'SG |', 'SG|',
    'HONG KONG', 'HK |', 'HK|',
    'TAIWAN', 'TW |', 'TW|',
    // Africa (non-English speaking)
    'AF |', 'AFRICA',
    'NIGERIA', 'NOLLYWOOD',
    'ETHIOPIA', 'ETHIOPIAN',
    'SOMALIA', 'SOMALI',
    'SENEGAL',
    'CAMEROON',
    'CONGO',
    'GHANA',
    'KENYA',
    'UGANDA',
    // Latin America
    'BRAZIL', 'BRAZILIAN', 'BR |', 'BR|', 'PORTUGUESE',
    'MEXICO', 'MEXICAN', 'MX |', 'MX|',
    'ARGENTINA', 'AR |', 'AR|',
    'COLOMBIA', 'CO |', 'CO|',
    'CHILE', 'CL |', 'CL|',
    'PERU', 'PE |', 'PE|',
    'VENEZUELA', 'VE |', 'VE|',
    'LATINO', 'LATIN',
    'HAITI', 'HAITIAN',
    'CARIBBEAN',
  ];
}
