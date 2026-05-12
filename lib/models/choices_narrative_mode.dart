/// Mode de narration pour CHOICES preprogrammed
/// - buckets: basé sur le nombre de hits (score)
/// - sequences: basé sur la séquence exacte des choix
enum ChoicesNarrativeMode {
  buckets,
  sequences;

  String displayName(bool isFrench) {
    switch (this) {
      case ChoicesNarrativeMode.buckets:
        return isFrench ? 'Buckets (par score)' : 'Buckets (by score)';
      case ChoicesNarrativeMode.sequences:
        return isFrench ? 'Séquences (par ordre)' : 'Sequences (by order)';
    }
  }

  String get description {
    switch (this) {
      case ChoicesNarrativeMode.buckets:
        return 'Texte basé sur le nombre de hits/misses';
      case ChoicesNarrativeMode.sequences:
        return 'Texte basé sur la séquence exacte des choix';
    }
  }

  String toJson() => name;

  static ChoicesNarrativeMode fromJson(String? value) {
    if (value == null) return ChoicesNarrativeMode.buckets;
    return ChoicesNarrativeMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ChoicesNarrativeMode.buckets,
    );
  }
}
