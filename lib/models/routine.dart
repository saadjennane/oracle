import 'package:uuid/uuid.dart';

class Routine {
  final String id;
  final String name;
  final List<String> inputOrder;  // Preset IDs in performance/input order
  final List<String> outputOrder; // Preset IDs in text assembly order

  Routine({
    String? id,
    required this.name,
    required this.inputOrder,
    List<String>? outputOrder,
  })  : id = id ?? const Uuid().v4(),
        outputOrder = outputOrder ?? List.from(inputOrder);

  Routine copyWith({
    String? name,
    List<String>? inputOrder,
    List<String>? outputOrder,
  }) {
    return Routine(
      id: id,
      name: name ?? this.name,
      inputOrder: inputOrder ?? List.from(this.inputOrder),
      outputOrder: outputOrder ?? List.from(this.outputOrder),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'inputOrder': inputOrder,
    'outputOrder': outputOrder,
  };

  factory Routine.fromJson(Map<String, dynamic> json) {
    final inputOrder = (json['inputOrder'] as List<dynamic>).cast<String>();
    return Routine(
      id: json['id'] as String,
      name: json['name'] as String,
      inputOrder: inputOrder,
      outputOrder: json['outputOrder'] != null
          ? (json['outputOrder'] as List<dynamic>).cast<String>()
          : List.from(inputOrder),
    );
  }

  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) errors.add('Name is required');
    if (inputOrder.length < 2) errors.add('At least 2 presets required');
    if (outputOrder.length != inputOrder.length) {
      errors.add('Input and output orders must have the same presets');
    }
    return errors;
  }
}
