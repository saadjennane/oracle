/// FREE_WILL Mode Configuration
///
/// 3 objects on the table. Spectator distributes them into 3 actions:
/// - TAKE (keep for themselves)
/// - GIVE (give to performer)
/// - TABLE (leave on table)

import 'stealth_input_method.dart';

/// The three possible actions for FREE_WILL mode
enum FreeWillAction {
  take,   // Spectator takes the object
  give,   // Spectator gives to performer
  table;  // Object stays on table

  String get displayNameFR {
    switch (this) {
      case FreeWillAction.take:
        return 'prendre';
      case FreeWillAction.give:
        return 'me donner';
      case FreeWillAction.table:
        return 'laisser sur la table';
    }
  }

  String get displayNameEN {
    switch (this) {
      case FreeWillAction.take:
        return 'take';
      case FreeWillAction.give:
        return 'give to me';
      case FreeWillAction.table:
        return 'leave on the table';
    }
  }

  String get shortNameFR {
    switch (this) {
      case FreeWillAction.take:
        return 'prendre';
      case FreeWillAction.give:
        return 'donner';
      case FreeWillAction.table:
        return 'table';
    }
  }

  /// Short name for UI display in English
  String get shortNameEN {
    switch (this) {
      case FreeWillAction.take:
        return 'KEEP SPECTATOR';
      case FreeWillAction.give:
        return 'GIVE PERFORMER';
      case FreeWillAction.table:
        return 'TABLE';
    }
  }
}

/// Input mode for FREE_WILL
enum FreeWillInputMode {
  /// User selects which objects were taken/given (3rd deduced)
  byAction,
  /// User goes object by object and chooses action (3rd deduced)
  byObject,
}

/// Swap type after initial 2 inputs
enum FreeWillSwap {
  /// Swap positions 1 & 2
  top,
  /// Swap positions 1 & 3
  middle,
  /// Swap positions 2 & 3
  bottom,
}

/// Configuration for a FREE_WILL preset
class FreeWillConfig {
  /// The 3 objects (can be variables like {obj1})
  final List<String> objects;

  /// Order of actions to prompt (e.g., [table, give, take])
  final List<FreeWillAction> actionOrder;

  /// Order of objects to prompt in byObject mode (e.g., [0, 1, 2] or [2, 0, 1])
  final List<int> objectOrder;

  /// Input mode
  final FreeWillInputMode inputMode;

  /// If true, always suggest change of mind (adds phrase if no swap)
  final bool suggestChangeOfMind;

  /// Custom text for when spectator changed their mind (swapCount > 0)
  final String? changeMindText;

  /// Custom text for when spectator didn't change mind (suggestChangeOfMind ON, swapCount == 0)
  final String? noChangeMindText;

  /// Tap zone orientation for Free Will (only used with tap input method)
  final TapOrientation tapOrientation;

  FreeWillConfig({
    required this.objects,
    this.actionOrder = const [FreeWillAction.take, FreeWillAction.give, FreeWillAction.table],
    this.objectOrder = const [0, 1, 2],
    this.inputMode = FreeWillInputMode.byAction,
    this.suggestChangeOfMind = true,
    this.changeMindText,
    this.noChangeMindText,
    this.tapOrientation = TapOrientation.horizontal,
  }) : assert(objects.length == 3, 'FREE_WILL requires exactly 3 objects'),
       assert(objectOrder.length == 3, 'objectOrder must have exactly 3 indices');

  /// Default config with placeholder objects
  factory FreeWillConfig.defaultConfig() {
    return FreeWillConfig(
      objects: const ['le téléphone', 'la clé', 'la pièce'],
      actionOrder: const [FreeWillAction.take, FreeWillAction.give, FreeWillAction.table],
      objectOrder: const [0, 1, 2],
      inputMode: FreeWillInputMode.byAction,
      suggestChangeOfMind: true,
      changeMindText: null,
      noChangeMindText: null,
      tapOrientation: TapOrientation.horizontal,
    );
  }

  FreeWillConfig copyWith({
    List<String>? objects,
    List<FreeWillAction>? actionOrder,
    List<int>? objectOrder,
    FreeWillInputMode? inputMode,
    bool? suggestChangeOfMind,
    String? changeMindText,
    String? noChangeMindText,
    bool clearChangeMindText = false,
    bool clearNoChangeMindText = false,
    TapOrientation? tapOrientation,
  }) {
    return FreeWillConfig(
      objects: objects ?? this.objects,
      actionOrder: actionOrder ?? this.actionOrder,
      objectOrder: objectOrder ?? this.objectOrder,
      inputMode: inputMode ?? this.inputMode,
      suggestChangeOfMind: suggestChangeOfMind ?? this.suggestChangeOfMind,
      changeMindText: clearChangeMindText ? null : (changeMindText ?? this.changeMindText),
      noChangeMindText: clearNoChangeMindText ? null : (noChangeMindText ?? this.noChangeMindText),
      tapOrientation: tapOrientation ?? this.tapOrientation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'objects': objects,
      'actionOrder': actionOrder.map((a) => a.name).toList(),
      'objectOrder': objectOrder,
      'inputMode': inputMode.name,
      'suggestChangeOfMind': suggestChangeOfMind,
      'changeMindText': changeMindText,
      'noChangeMindText': noChangeMindText,
      'tapOrientation': tapOrientation.toJson(),
    };
  }

  factory FreeWillConfig.fromJson(Map<String, dynamic> json) {
    return FreeWillConfig(
      objects: List<String>.from(json['objects'] ?? ['obj1', 'obj2', 'obj3']),
      actionOrder: (json['actionOrder'] as List<dynamic>?)
          ?.map((a) => FreeWillAction.values.firstWhere((e) => e.name == a))
          .toList() ??
          [FreeWillAction.take, FreeWillAction.give, FreeWillAction.table],
      objectOrder: (json['objectOrder'] as List<dynamic>?)
          ?.map((i) => i as int)
          .toList() ??
          [0, 1, 2],
      // byObject mode is deprecated — legacy presets are migrated to byAction
      // (the "input the object for each action" mode is now the only mode).
      inputMode: FreeWillInputMode.byAction,
      suggestChangeOfMind: json['suggestChangeOfMind'] ?? true,
      changeMindText: json['changeMindText'] as String?,
      noChangeMindText: json['noChangeMindText'] as String?,
      tapOrientation: TapOrientation.fromJson(json['tapOrientation'] as String?),
    );
  }

  @override
  String toString() => 'FreeWillConfig(objects: $objects, inputMode: $inputMode, suggestChangeOfMind: $suggestChangeOfMind)';
}

/// Represents the current assignment state during FREE_WILL input
class FreeWillAssignment {
  /// Maps object index (0,1,2) to action (null if not yet assigned)
  final Map<int, FreeWillAction?> assignments;

  /// Number of swaps performed after initial assignment
  final int swapCount;

  /// History of swaps for debugging
  final List<FreeWillSwap> swapHistory;

  const FreeWillAssignment({
    required this.assignments,
    this.swapCount = 0,
    this.swapHistory = const [],
  });

  factory FreeWillAssignment.initial() {
    return const FreeWillAssignment(
      assignments: {0: null, 1: null, 2: null},
      swapCount: 0,
      swapHistory: [],
    );
  }

  /// Check if initial assignment is complete (all 3 actions assigned)
  bool get isComplete {
    return assignments.values.every((a) => a != null) &&
        assignments.values.toSet().length == 3;
  }

  /// Number of assigned objects
  int get assignedCount {
    return assignments.values.where((a) => a != null).length;
  }

  /// Get remaining unassigned object indices
  List<int> get unassignedIndices {
    return assignments.entries
        .where((e) => e.value == null)
        .map((e) => e.key)
        .toList();
  }

  /// Get remaining unassigned actions
  List<FreeWillAction> get unassignedActions {
    final assigned = assignments.values.whereType<FreeWillAction>().toSet();
    return FreeWillAction.values.where((a) => !assigned.contains(a)).toList();
  }

  /// Assign an action to an object
  FreeWillAssignment assign(int objectIndex, FreeWillAction action) {
    final newAssignments = Map<int, FreeWillAction?>.from(assignments);
    newAssignments[objectIndex] = action;

    // Auto-deduce 3rd if 2 are assigned
    if (newAssignments.values.where((a) => a != null).length == 2) {
      final assignedActions = newAssignments.values.whereType<FreeWillAction>().toSet();
      final remaining = FreeWillAction.values.where((a) => !assignedActions.contains(a)).toList();
      final remainingIdx = newAssignments.entries
          .where((e) => e.value == null)
          .map((e) => e.key)
          .first;
      if (remaining.length == 1) {
        newAssignments[remainingIdx] = remaining.first;
      }
    }

    return FreeWillAssignment(
      assignments: newAssignments,
      swapCount: swapCount,
      swapHistory: swapHistory,
    );
  }

  /// Perform a swap after initial assignment
  FreeWillAssignment performSwap(FreeWillSwap swap) {
    if (!isComplete) return this;

    final newAssignments = Map<int, FreeWillAction?>.from(assignments);

    switch (swap) {
      case FreeWillSwap.top:
        // Swap positions 0 & 1
        final temp = newAssignments[0];
        newAssignments[0] = newAssignments[1];
        newAssignments[1] = temp;
        break;
      case FreeWillSwap.middle:
        // Swap positions 0 & 2
        final temp = newAssignments[0];
        newAssignments[0] = newAssignments[2];
        newAssignments[2] = temp;
        break;
      case FreeWillSwap.bottom:
        // Swap positions 1 & 2
        final temp = newAssignments[1];
        newAssignments[1] = newAssignments[2];
        newAssignments[2] = temp;
        break;
    }

    return FreeWillAssignment(
      assignments: newAssignments,
      swapCount: swapCount + 1,
      swapHistory: [...swapHistory, swap],
    );
  }

  /// Get final result: which object has which action
  FreeWillResult? toResult(List<String> objects) {
    if (!isComplete) return null;

    String? takeObject, giveObject, tableObject;

    for (final entry in assignments.entries) {
      final obj = objects[entry.key];
      switch (entry.value) {
        case FreeWillAction.take:
          takeObject = obj;
          break;
        case FreeWillAction.give:
          giveObject = obj;
          break;
        case FreeWillAction.table:
          tableObject = obj;
          break;
        case null:
          break;
      }
    }

    if (takeObject == null || giveObject == null || tableObject == null) {
      return null;
    }

    return FreeWillResult(
      takeObject: takeObject,
      giveObject: giveObject,
      tableObject: tableObject,
      swapCount: swapCount,
    );
  }

  @override
  String toString() => 'FreeWillAssignment($assignments, swaps: $swapCount)';
}

/// Final result of FREE_WILL routine
class FreeWillResult {
  final String takeObject;
  final String giveObject;
  final String tableObject;
  final int swapCount;

  const FreeWillResult({
    required this.takeObject,
    required this.giveObject,
    required this.tableObject,
    required this.swapCount,
  });

  /// Bucket key for narrative bank lookup
  /// Format: "TAKE:obj|GIVE:obj|TABLE:obj"
  String get bucketKey {
    return 'TAKE:$takeObject|GIVE:$giveObject|TABLE:$tableObject';
  }

  /// Permutation index (0-5) for the 6 possible outcomes
  /// Based on which object got which role
  int getPermutationIndex(List<String> canonicalOrder) {
    final takeIdx = canonicalOrder.indexOf(takeObject);
    final giveIdx = canonicalOrder.indexOf(giveObject);
    final tableIdx = canonicalOrder.indexOf(tableObject);

    // Map (take, give, table) indices to permutation number
    // 0: (0,1,2) 1: (0,2,1) 2: (1,0,2) 3: (1,2,0) 4: (2,0,1) 5: (2,1,0)
    if (takeIdx == 0 && giveIdx == 1 && tableIdx == 2) return 0;
    if (takeIdx == 0 && giveIdx == 2 && tableIdx == 1) return 1;
    if (takeIdx == 1 && giveIdx == 0 && tableIdx == 2) return 2;
    if (takeIdx == 1 && giveIdx == 2 && tableIdx == 0) return 3;
    if (takeIdx == 2 && giveIdx == 0 && tableIdx == 1) return 4;
    if (takeIdx == 2 && giveIdx == 1 && tableIdx == 0) return 5;

    return 0; // Fallback
  }

  @override
  String toString() =>
      'FreeWillResult(take: $takeObject, give: $giveObject, table: $tableObject, swaps: $swapCount)';
}
