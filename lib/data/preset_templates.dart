import '../models/models.dart';

/// Hardcoded "starter pack" templates shipped with the app. Empty by
/// default — templates now live in Firebase and are managed by the admin
/// from inside the app. Add a `PresetTemplate(...)` here only if you need
/// a binary-bundled template that ships even without network.
class PresetTemplate {
  final String name;
  final String description;
  final Preset Function() build;

  const PresetTemplate({
    required this.name,
    required this.description,
    required this.build,
  });
}

final List<PresetTemplate> presetTemplates = <PresetTemplate>[];
