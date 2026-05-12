/// Supported languages
enum Language {
  english,
  french,
  spanish;

  String get displayName {
    switch (this) {
      case Language.english:
        return 'English';
      case Language.french:
        return 'Français';
      case Language.spanish:
        return 'Español';
    }
  }

  String get flag {
    switch (this) {
      case Language.english:
        return '🇬🇧';
      case Language.french:
        return '🇫🇷';
      case Language.spanish:
        return '🇪🇸';
    }
  }

  String get code {
    switch (this) {
      case Language.english:
        return 'EN';
      case Language.french:
        return 'FR';
      case Language.spanish:
        return 'ES';
    }
  }

  static Language fromString(String? value) {
    switch (value) {
      case 'french':
        return Language.french;
      case 'spanish':
        return Language.spanish;
      default:
        return Language.english;
    }
  }
}
