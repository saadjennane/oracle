/// V2 Enums — used by AssemblyTrace and bank routing

import '../../models/models.dart';

/// Styles narratifs V2 (4 styles uniquement)
enum NarrativeStyleV2 {
  direct,
  psychologique,
  narratif,
  carnet,
}

/// Extension pour display names
extension NarrativeStyleV2Extension on NarrativeStyleV2 {
  String displayName(Language language) {
    switch (this) {
      case NarrativeStyleV2.direct:
        return language == Language.french ? 'Direct' : 'Direct';
      case NarrativeStyleV2.psychologique:
        return language == Language.french ? 'Psychologique' : 'Psychological';
      case NarrativeStyleV2.narratif:
        return language == Language.french ? 'Narratif' : 'Narrative';
      case NarrativeStyleV2.carnet:
        return language == Language.french ? 'Carnet' : 'Notebook';
    }
  }
}

/// Tons narratifs V2
enum NarrativeToneV2 {
  neutral,
  confident,
  humorous,
  playfulMocking,
}

/// Patterns spectateur V2
enum SpectatorPatternV2 {
  repeatHeavy,
  oneSwitch,
  alternating,
  mixed,
}

/// Temps narratif V2
enum NarrativeTenseV2 {
  past,
  present,
  future,
}

/// Saveur narrative V2
enum NarrativeFlavorV2 {
  dream,
  intuition,
  premonition,
  chance,
}
