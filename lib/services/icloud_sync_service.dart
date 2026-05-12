import 'dart:async';
import 'dart:convert';
import '../data/local_storage.dart';
import '../models/preset.dart';
import '../models/confabulation_preset.dart';
import 'icloud_kv_service.dart';
import 'tombstone_store.dart';

/// Syncs presets, confab presets, routines and settings to/from iCloud KV.
/// Uses id-based merge with per-item `updatedAt` timestamps when available.
class ICloudSyncService {
  static const _settingsKeysToSync = [
    'assistant_id',
    'haptic_feedback',
    'haptic_intensity',
    'test_mode_enabled',
    'auto_copy_narrative',
    'shortcut_name',
    'openai_api_key',
    'remote_enabled',
    'remote_key_up',
    'remote_key_down',
    'remote_key_left',
    'remote_key_right',
    'free_text_redirect_url',
    'free_text_transform_prompt',
    'free_text_acrostic_enabled',
    'inject_id',
    'elips_id',
    'elips_api_key',
    'high_score_api_key',
    'app_language',
    'visual_feedback_enabled',
    'double_tap_fallback_enabled',
    'pre_screen_enabled',
    'pre_screen_type',
    'reveal_theme_mode',
    'auto_start_preset_id',
  ];

  // Collection keys used in iCloud KV (list-style blobs)
  static const _presetsKey = 'presets';
  static const _confabKey = 'confabulation_presets';
  static const _routinesKey = 'routines';

  /// Keys stored as JSON strings in SharedPreferences (NOT as List<String>).
  /// Calling `getStringList` on them throws a type-cast error — must use
  /// `getString`. Includes static keys plus per-language acrostic data
  /// discovered at sync time (`acrostic_bank_<lang>`, `acrostic_favs_<lang>`).
  static const _otherStringKeys = [
    'reveal_skin_config',
    'acrostic_languages',
  ];

  /// Returns all per-language acrostic keys currently in local storage.
  static List<String> _discoverAcrosticKeys(LocalStorage storage) {
    return storage
        .getKeys()
        .where((k) => k.startsWith('acrostic_bank_') || k.startsWith('acrostic_favs_'))
        .toList();
  }

  // --- Debounced auto-push ---
  static Timer? _debounce;
  static DateTime? _lastPushAt;
  static final _statusController = StreamController<_SyncStatus>.broadcast();

  static Stream<_SyncStatus> get onStatusChange => _statusController.stream;
  static DateTime? get lastPushAt => _lastPushAt;

  /// Schedule a push after a short delay. Multiple rapid calls coalesce.
  static void scheduleAutoPush({Duration delay = const Duration(seconds: 2)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, () async {
      final storage = LocalStorage();
      await storage.init();
      await pushToCloud(storage);
    });
  }

  static void _emit(String state) => _statusController.add(_SyncStatus(state, DateTime.now()));

  // --- Push ---
  /// Push all local data to iCloud (merge-friendly structure).
  static Future<void> pushToCloud(LocalStorage storage) async {
    final available = await ICloudKVService.isAvailable();
    if (!available) { _emit('unavailable'); return; }
    _emit('pushing');

    // Presets: store as id-keyed map with updatedAt preserved.
    try {
      final localPresets = _decodePresets(storage.getStringList(_presetsKey));
      await ICloudKVService.setString(_presetsKey, _encodePresetList(localPresets));
    } catch (_) {}

    try {
      final localConfabs = _decodeConfabs(storage.getStringList(_confabKey));
      await ICloudKVService.setString(_confabKey, _encodeConfabList(localConfabs));
    } catch (_) {}

    // Routines: stored as List<String> locally → wrap as JSON list in cloud.
    final routinesList = storage.getStringList(_routinesKey);
    if (routinesList != null) {
      await ICloudKVService.setString(_routinesKey, jsonEncode(routinesList));
    }

    // Other keys (reveal config, acrostic banks/langs/favs): already JSON
    // strings locally — push as-is. Per-language acrostic keys are discovered
    // dynamically. Wrapped in try/catch per key so one bad value can't kill
    // the whole backup.
    final stringKeys = [..._otherStringKeys, ..._discoverAcrosticKeys(storage)];
    for (final k in stringKeys) {
      try {
        final v = storage.getString(k);
        if (v != null) await ICloudKVService.setString(k, v);
      } catch (_) {
        // Skip silently — sync continues with the other keys.
      }
    }

    // Tombstones
    final tomb = {
      'presets': (await TombstoneStore.getDeletedPresets()).toList(),
      'confab': (await TombstoneStore.getDeletedConfabs()).toList(),
      'routines': (await TombstoneStore.getDeletedRoutines()).toList(),
    };
    await ICloudKVService.setString('_tombstones', jsonEncode(tomb));

    // Settings (typed encoding). Use the raw `prefs.get(key)` accessor so we
    // never trip over a key stored with a different type than what the
    // typed getter expects (e.g. an old String where we now store a bool).
    // Each key is read defensively — a single bad value can't kill backup.
    final settingsMap = <String, String?>{};
    final prefs = storage.prefs;
    for (final key in _settingsKeysToSync) {
      try {
        final raw = prefs.get(key);
        if (raw == null) continue;
        if (raw is String) {
          settingsMap[key] = 's:$raw';
        } else if (raw is bool) {
          settingsMap[key] = 'b:${raw ? '1' : '0'}';
        } else if (raw is int) {
          settingsMap[key] = 'i:$raw';
        }
        // Other types (double, List<String>) are intentionally skipped.
      } catch (_) {
        // Skip the offending key.
      }
    }
    await ICloudKVService.setString('_settings', jsonEncode(settingsMap));

    final now = DateTime.now().toUtc().toIso8601String();
    await ICloudKVService.setString('_lastSync', now);
    await ICloudKVService.synchronize();
    _lastPushAt = DateTime.now();
    _emit('pushed');
  }

  // --- Pull / Merge ---
  /// Merge cloud data into local storage by id + updatedAt (last-write-wins per item).
  /// Returns true if any data was merged.
  static Future<bool> pullAndMerge(LocalStorage storage) async {
    final available = await ICloudKVService.isAvailable();
    if (!available) { _emit('unavailable'); return false; }
    _emit('pulling');

    bool changed = false;

    // Tombstones (fetch first so we can suppress resurrected items)
    final tombJson = await ICloudKVService.getString('_tombstones');
    Set<String> cloudTombPresets = {};
    Set<String> cloudTombConfabs = {};
    Set<String> cloudTombRoutines = {};
    if (tombJson != null) {
      try {
        final map = jsonDecode(tombJson) as Map<String, dynamic>;
        cloudTombPresets = ((map['presets'] as List?) ?? []).cast<String>().toSet();
        cloudTombConfabs = ((map['confab'] as List?) ?? []).cast<String>().toSet();
        cloudTombRoutines = ((map['routines'] as List?) ?? []).cast<String>().toSet();
      } catch (_) {}
    }
    await TombstoneStore.mergeCloudTombstones(
      cloudPresets: cloudTombPresets,
      cloudConfabs: cloudTombConfabs,
      cloudRoutines: cloudTombRoutines,
    );
    final localTombPresets = await TombstoneStore.getDeletedPresets();
    final localTombConfabs = await TombstoneStore.getDeletedConfabs();
    final localTombRoutines = await TombstoneStore.getDeletedRoutines();

    // Presets merge
    final cloudPresetsRaw = await ICloudKVService.getString(_presetsKey);
    if (cloudPresetsRaw != null) {
      final cloudPresets = _decodePresetPayload(cloudPresetsRaw);
      final localPresets = _decodePresets(storage.getStringList(_presetsKey));
      final merged = _mergeById<Preset>(
        local: localPresets,
        cloud: cloudPresets,
        getId: (p) => p.id,
        getUpdated: (p) => p.updatedAt,
        tombstones: localTombPresets,
      );
      await storage.setStringList(_presetsKey, merged.map((p) => jsonEncode(p.toJson())).toList());
      if (!_sameIdOrder(merged, localPresets)) changed = true;
    }

    // Confab presets merge
    final cloudConfabsRaw = await ICloudKVService.getString(_confabKey);
    if (cloudConfabsRaw != null) {
      final cloudConfabs = _decodeConfabPayload(cloudConfabsRaw);
      final localConfabs = _decodeConfabs(storage.getStringList(_confabKey));
      final merged = _mergeById<ConfabulationPreset>(
        local: localConfabs,
        cloud: cloudConfabs,
        getId: (c) => c.id,
        getUpdated: (c) => c.updatedAt,
        tombstones: localTombConfabs,
      );
      await storage.setStringList(_confabKey, merged.map((c) => jsonEncode(c.toJson())).toList());
      if (!_sameIdOrder(merged, localConfabs)) changed = true;
    }

    // Routines and other list blobs: union-by-id where possible, else overwrite.
    final cloudRoutines = await ICloudKVService.getString(_routinesKey);
    if (cloudRoutines != null) {
      try {
        final cloudList = (jsonDecode(cloudRoutines) as List).cast<String>();
        final localList = storage.getStringList(_routinesKey) ?? [];
        final merged = _mergeGenericById(localList, cloudList, localTombRoutines);
        await storage.setStringList(_routinesKey, merged);
        if (merged.length != localList.length) changed = true;
      } catch (_) {}
    }
    // Pull JSON-string keys (reveal config, acrostic_languages, per-language
    // acrostic banks/favs). Cloud wins. Discover the per-language keys both
    // from local storage AND from cloud (someone else's device may have
    // pushed a new language we don't have yet).
    final localAcrosticKeys = _discoverAcrosticKeys(storage);
    final stringKeysToPull = {..._otherStringKeys, ...localAcrosticKeys};
    for (final k in stringKeysToPull) {
      try {
        final cloudVal = await ICloudKVService.getString(k);
        if (cloudVal != null) {
          await storage.setString(k, cloudVal);
          changed = true;
        }
      } catch (_) {}
    }

    // Settings (cloud wins). Per-entry try/catch + remove the key first to
    // wipe any leftover value with a mismatched type, so rewrites are safe.
    final settingsJson = await ICloudKVService.getString('_settings');
    if (settingsJson != null) {
      try {
        final map = (jsonDecode(settingsJson) as Map<String, dynamic>).cast<String, String?>();
        for (final entry in map.entries) {
          if (entry.value == null) continue;
          final val = entry.value!;
          try {
            await storage.remove(entry.key);
            if (val.startsWith('s:')) {
              await storage.setString(entry.key, val.substring(2));
            } else if (val.startsWith('b:')) {
              await storage.setBool(entry.key, val.substring(2) == '1');
            } else if (val.startsWith('i:')) {
              await storage.setInt(entry.key, int.tryParse(val.substring(2)) ?? 0);
            }
            changed = true;
          } catch (_) {}
        }
      } catch (_) {}
    }

    _emit('pulled');
    return changed;
  }

  /// Legacy helpers preserved for existing UI.
  static Future<bool> pullFromCloud(LocalStorage storage) => pullAndMerge(storage);

  static Future<String?> getLastSyncTime() => ICloudKVService.getString('_lastSync');
  static Future<bool> hasCloudData() async {
    final available = await ICloudKVService.isAvailable();
    if (!available) return false;
    return (await ICloudKVService.getString('_lastSync')) != null;
  }

  // --- Helpers ---
  static List<Preset> _decodePresets(List<String>? list) {
    if (list == null) return [];
    final out = <Preset>[];
    for (final s in list) {
      try { out.add(Preset.fromJson(jsonDecode(s) as Map<String, dynamic>)); } catch (_) {}
    }
    return out;
  }

  static List<ConfabulationPreset> _decodeConfabs(List<String>? list) {
    if (list == null) return [];
    final out = <ConfabulationPreset>[];
    for (final s in list) {
      try { out.add(ConfabulationPreset.fromJson(jsonDecode(s) as Map<String, dynamic>)); } catch (_) {}
    }
    return out;
  }

  static String _encodePresetList(List<Preset> items) {
    return jsonEncode(items.map((p) => p.toJson()).toList());
  }

  static String _encodeConfabList(List<ConfabulationPreset> items) {
    return jsonEncode(items.map((c) => c.toJson()).toList());
  }

  static List<Preset> _decodePresetPayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      // Support both legacy (List<String>) and new (List<Map>) payloads.
      if (decoded is List) {
        return decoded.map<Preset?>((e) {
          if (e is String) {
            try { return Preset.fromJson(jsonDecode(e) as Map<String, dynamic>); } catch (_) { return null; }
          }
          if (e is Map<String, dynamic>) {
            try { return Preset.fromJson(e); } catch (_) { return null; }
          }
          return null;
        }).whereType<Preset>().toList();
      }
    } catch (_) {}
    return [];
  }

  static List<ConfabulationPreset> _decodeConfabPayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map<ConfabulationPreset?>((e) {
          if (e is String) {
            try { return ConfabulationPreset.fromJson(jsonDecode(e) as Map<String, dynamic>); } catch (_) { return null; }
          }
          if (e is Map<String, dynamic>) {
            try { return ConfabulationPreset.fromJson(e); } catch (_) { return null; }
          }
          return null;
        }).whereType<ConfabulationPreset>().toList();
      }
    } catch (_) {}
    return [];
  }

  /// Merge local + cloud by id. Keep the newer version (by `updatedAt`).
  /// Items with id in `tombstones` are excluded (they were deleted locally).
  static List<T> _mergeById<T>({
    required List<T> local,
    required List<T> cloud,
    required String Function(T) getId,
    required DateTime? Function(T) getUpdated,
    required Set<String> tombstones,
  }) {
    final byId = <String, T>{};
    final order = <String>[]; // Preserve local order, then cloud-only at end.
    for (final item in local) {
      final id = getId(item);
      if (tombstones.contains(id)) continue;
      byId[id] = item;
      order.add(id);
    }
    for (final item in cloud) {
      final id = getId(item);
      if (tombstones.contains(id)) continue;
      final existing = byId[id];
      if (existing == null) {
        byId[id] = item;
        order.add(id);
      } else {
        final lu = getUpdated(existing);
        final cu = getUpdated(item);
        if (lu == null && cu != null) {
          byId[id] = item;
        } else if (lu != null && cu != null && cu.isAfter(lu)) {
          byId[id] = item;
        }
        // else keep local (newer or unknown)
      }
    }
    return [for (final id in order) byId[id]!];
  }

  /// Merge for routines (no stable typed model here) — parses each JSON string
  /// for an `id` field, de-dupes, prefers local.
  static List<String> _mergeGenericById(List<String> local, List<String> cloud, Set<String> tombstones) {
    String? idOf(String jsonStr) {
      try {
        final m = jsonDecode(jsonStr) as Map<String, dynamic>;
        return m['id'] as String?;
      } catch (_) { return null; }
    }
    final byId = <String, String>{};
    final order = <String>[];
    for (final s in local) {
      final id = idOf(s);
      if (id == null) continue;
      if (tombstones.contains(id)) continue;
      byId[id] = s;
      order.add(id);
    }
    for (final s in cloud) {
      final id = idOf(s);
      if (id == null) continue;
      if (tombstones.contains(id)) continue;
      if (!byId.containsKey(id)) {
        byId[id] = s;
        order.add(id);
      }
    }
    return [for (final id in order) byId[id]!];
  }

  static bool _sameIdOrder(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    String idOf(dynamic x) {
      if (x is Preset) return x.id;
      if (x is ConfabulationPreset) return x.id;
      return '';
    }
    for (int i = 0; i < a.length; i++) {
      if (idOf(a[i]) != idOf(b[i])) return false;
    }
    return true;
  }
}

class _SyncStatus {
  final String state; // 'pushing', 'pushed', 'pulling', 'pulled', 'unavailable'
  final DateTime at;
  _SyncStatus(this.state, this.at);
}
