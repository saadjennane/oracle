class RoundInput {
  final int roundNumber;
  final String spectatorChoice;
  final String? performerChoice;

  const RoundInput({
    required this.roundNumber,
    required this.spectatorChoice,
    this.performerChoice,
  });

  Map<String, dynamic> toJson() => {
        'roundNumber': roundNumber,
        'spectatorChoice': spectatorChoice,
        'performerChoice': performerChoice,
      };

  factory RoundInput.fromJson(Map<String, dynamic> json) => RoundInput(
        roundNumber: json['roundNumber'] as int,
        spectatorChoice: json['spectatorChoice'] as String,
        performerChoice: json['performerChoice'] as String?,
      );

  RoundInput copyWith({
    int? roundNumber,
    String? spectatorChoice,
    String? performerChoice,
  }) {
    return RoundInput(
      roundNumber: roundNumber ?? this.roundNumber,
      spectatorChoice: spectatorChoice ?? this.spectatorChoice,
      performerChoice: performerChoice ?? this.performerChoice,
    );
  }

  @override
  String toString() =>
      'RoundInput(round: $roundNumber, spectator: $spectatorChoice, performer: $performerChoice)';
}
