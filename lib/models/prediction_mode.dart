import 'language.dart';

/// Prediction mode for Multiple Choices presets
/// - game: mentalist is involved, can "miss" voluntarily (Je/Tu)
/// - direct: pure spectator-focused prediction, no mentalist guessing (Tu only)
enum PredictionMode {
  game,
  direct;

  String displayName(Language locale) {
    switch (this) {
      case PredictionMode.game:
        return locale == Language.french ? 'Game (Je/Tu)' : 'Game (I/You)';
      case PredictionMode.direct:
        return locale == Language.french ? 'Direct (Tu)' : 'Direct (You)';
    }
  }

  String description(Language locale) {
    switch (this) {
      case PredictionMode.game:
        return locale == Language.french
            ? "Le mentaliste est 'dans le jeu'. Le texte peut inclure des 'ratés' volontaires pour rendre l'effet plus naturel."
            : "The mentalist is 'in the game'. The text may include intentional misses for a more natural build.";
      case PredictionMode.direct:
        return locale == Language.french
            ? "Prédiction pure centrée sur le spectateur. Le texte annonce directement la suite des choix, sans 'deviner'."
            : "Pure spectator-focused prediction. The text directly predicts the spectator sequence, with no guessing.";
    }
  }

  String example(Language locale) {
    switch (this) {
      case PredictionMode.game:
        return locale == Language.french
            ? "J'avais prévu la séquence. J'ai laissé une respiration au début… puis tout s'est refermé comme écrit."
            : "I wrote the sequence in advance. I allowed a small gap… then closed the loop.";
      case PredictionMode.direct:
        return locale == Language.french
            ? "La première fois tu iras à gauche, puis à droite… et la note raconte la séquence comme si elle était écrite d'avance."
            : "First you go left, then right… the note reads like it was written beforehand.";
    }
  }

  String toJson() => name;

  static PredictionMode fromJson(String json) {
    return PredictionMode.values.firstWhere(
      (e) => e.name == json,
      orElse: () => PredictionMode.game,
    );
  }
}
