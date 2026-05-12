import 'language.dart';

/// How the narrative voice speaks (first vs third person)
enum NarratorVoice {
  firstPerson,   // "I predicted..." / "J'ai prédit..."
  thirdPerson;   // "The Oracle predicted..." / "L'Oracle a prédit..."

  String displayName(Language locale) {
    switch (this) {
      case NarratorVoice.firstPerson:
        return locale == Language.french ? 'Première personne' : 'First Person';
      case NarratorVoice.thirdPerson:
        return locale == Language.french ? 'Troisième personne' : 'Third Person';
    }
  }

  String description(Language locale) {
    switch (this) {
      case NarratorVoice.firstPerson:
        return locale == Language.french
            ? '"J\'ai prédit que..."'
            : '"I predicted that..."';
      case NarratorVoice.thirdPerson:
        return locale == Language.french
            ? '"L\'Oracle a prédit que..."'
            : '"The Oracle predicted that..."';
    }
  }

  String toJson() => name;

  static NarratorVoice fromJson(String? json) {
    switch (json) {
      case 'thirdPerson':
        return NarratorVoice.thirdPerson;
      default:
        return NarratorVoice.firstPerson;
    }
  }
}

/// How we address the participant (you vs by name)
enum AddressMode {
  you,    // "You chose..." / "Tu as choisi..."
  byName;   // "[Name] chose..." / "[Nom] a choisi..."

  String displayName(Language locale) {
    switch (this) {
      case AddressMode.you:
        return locale == Language.french ? 'Tutoiement (Tu)' : 'You';
      case AddressMode.byName:
        return locale == Language.french ? 'Par le nom' : 'By Name';
    }
  }

  String description(Language locale) {
    switch (this) {
      case AddressMode.you:
        return locale == Language.french
            ? '"Tu as choisi..."'
            : '"You chose..."';
      case AddressMode.byName:
        return locale == Language.french
            ? '"Marie a choisi..."'
            : '"Marie chose..."';
    }
  }

  String toJson() => name;

  static AddressMode fromJson(String? json) {
    switch (json) {
      case 'byName':
        return AddressMode.byName;
      default:
        return AddressMode.you;
    }
  }
}
