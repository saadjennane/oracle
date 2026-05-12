import 'appellation.dart';
import 'language.dart';

/// Handedness preference for narrative generation
enum Handedness {
  right,
  left,
  unknown;

  String displayName(Language lang) {
    switch (this) {
      case Handedness.right:
        return lang == Language.french ? 'Droitier' : 'Right';
      case Handedness.left:
        return lang == Language.french ? 'Gaucher' : 'Left';
      case Handedness.unknown:
        return lang == Language.french ? 'Inconnu' : 'Unknown';
    }
  }
}

/// Reference mode for how the performer addresses the spectator
enum ReferenceMode {
  jeTu,      // First person: Je/Tu (performer speaks, addresses spectator directly)
  nomNom,    // Two names: uses performer name + spectator name
  neutre;    // Third person: neutral/impersonal

  String displayName(Language lang) {
    switch (this) {
      case ReferenceMode.jeTu:
        return lang == Language.french ? 'Je / Tu' : 'I / You';
      case ReferenceMode.nomNom:
        return lang == Language.french ? 'Nom / Nom' : 'Name / Name';
      case ReferenceMode.neutre:
        return lang == Language.french ? 'Neutre' : 'Neutral';
    }
  }

  /// Convert to NarratorVoice for narrative engine
  NarratorVoice toNarratorVoice() {
    switch (this) {
      case ReferenceMode.jeTu:
        return NarratorVoice.firstPerson;
      case ReferenceMode.nomNom:
        return NarratorVoice.thirdPerson;
      case ReferenceMode.neutre:
        return NarratorVoice.thirdPerson;
    }
  }

  /// Convert to AddressMode for narrative engine
  AddressMode toAddressMode() {
    switch (this) {
      case ReferenceMode.jeTu:
        return AddressMode.you;
      case ReferenceMode.nomNom:
        return AddressMode.byName;
      case ReferenceMode.neutre:
        return AddressMode.you;
    }
  }
}

/// Live cues that can be entered during the reveal to customize the narrative
class LiveCues {
  final String? spectatorName;
  final ReferenceMode? referenceMode;
  final Handedness? handedness;

  const LiveCues({
    this.spectatorName,
    this.referenceMode,
    this.handedness,
  });

  bool get isEmpty =>
      (spectatorName == null || spectatorName!.trim().isEmpty) &&
      referenceMode == null &&
      handedness == null;

  bool get hasSpectatorName =>
      spectatorName != null && spectatorName!.trim().isNotEmpty;

  LiveCues copyWith({
    String? spectatorName,
    ReferenceMode? referenceMode,
    Handedness? handedness,
    bool clearSpectatorName = false,
  }) {
    return LiveCues(
      spectatorName: clearSpectatorName ? null : (spectatorName ?? this.spectatorName),
      referenceMode: referenceMode ?? this.referenceMode,
      handedness: handedness ?? this.handedness,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spectatorName': spectatorName,
      'referenceMode': referenceMode?.name,
      'handedness': handedness?.name,
    };
  }

  factory LiveCues.fromJson(Map<String, dynamic> json) {
    return LiveCues(
      spectatorName: json['spectatorName'] as String?,
      referenceMode: json['referenceMode'] != null
          ? ReferenceMode.values.firstWhere(
              (e) => e.name == json['referenceMode'],
              orElse: () => ReferenceMode.jeTu,
            )
          : null,
      handedness: json['handedness'] != null
          ? Handedness.values.firstWhere(
              (e) => e.name == json['handedness'],
              orElse: () => Handedness.unknown,
            )
          : null,
    );
  }

  static const LiveCues empty = LiveCues();
}
