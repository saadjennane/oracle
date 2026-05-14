import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LicenseService {
  static const String backendBaseUrl = 'https://license.asmagicapps.com';
  static const String appToken = 'ORACLE_MOBILE_V1';
  static const Duration offlineGrace = Duration(hours: 72);

  static const _deviceIdKey = 'license_device_id';
  static const _licenseKeyKey = 'license_key';
  static const _lastValidatedAtKey = 'license_last_validated_at';

  static final Uuid _uuid = const Uuid();

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _uuid.v4();
    await prefs.setString(_deviceIdKey, created);
    return created;
  }

  Future<String?> getSavedLicenseKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_licenseKeyKey);
  }

  Future<bool> hasSavedLicenseKey() async {
    final key = await getSavedLicenseKey();
    return key != null && key.isNotEmpty;
  }

  Future<void> clearLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKeyKey);
    await prefs.remove(_lastValidatedAtKey);
  }

  Future<LicenseResult> activate(String licenseKey) async {
    try {
      final deviceId = await getOrCreateDeviceId();
      final uri = Uri.parse('$backendBaseUrl/license/activate');

      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-app-token': appToken,
            },
            body: jsonEncode({
              'licenseKey': licenseKey.trim(),
              'deviceId': deviceId,
              'instanceName': 'Oracle Mobile',
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = _decode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_licenseKeyKey, licenseKey.trim());
        await prefs.setString(_lastValidatedAtKey, DateTime.now().toUtc().toIso8601String());
        return const LicenseResult(ok: true);
      }

      final retry = data['retryInSeconds'];
      return LicenseResult(
        ok: false,
        message: data['error']?.toString() ?? 'Activation failed',
        retryInSeconds: retry is int ? retry : int.tryParse('${retry ?? ''}'),
        code: data['code']?.toString(),
      );
    } on TimeoutException {
      return const LicenseResult(ok: false, message: 'Network timeout. Please try again.');
    } catch (_) {
      return const LicenseResult(ok: false, message: 'Network error. Please try again.');
    }
  }

  Future<LicenseResult> validate() async {
    final prefs = await SharedPreferences.getInstance();
    final licenseKey = prefs.getString(_licenseKeyKey);
    if (licenseKey == null || licenseKey.isEmpty) {
      return const LicenseResult(ok: false, message: 'No license saved');
    }

    final deviceId = await getOrCreateDeviceId();
    final uri = Uri.parse('$backendBaseUrl/license/validate');

    try {
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-app-token': appToken,
        },
        body: jsonEncode({'licenseKey': licenseKey, 'deviceId': deviceId}),
      ).timeout(const Duration(seconds: 10));
      final data = _decode(res.body);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        await prefs.setString(_lastValidatedAtKey, DateTime.now().toUtc().toIso8601String());
        return const LicenseResult(ok: true);
      }

      return LicenseResult(
        ok: false,
        message: data['error']?.toString() ?? 'License invalid',
        code: data['code']?.toString(),
      );
    } catch (_) {
      final ts = prefs.getString(_lastValidatedAtKey);
      if (ts != null) {
        final last = DateTime.tryParse(ts);
        if (last != null && DateTime.now().toUtc().difference(last) <= offlineGrace) {
          return const LicenseResult(ok: true, fromOfflineGrace: true);
        }
      }
      return const LicenseResult(ok: false, message: 'Offline grace expired');
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return {};
    try {
      final v = jsonDecode(body);
      return v is Map<String, dynamic> ? v : {};
    } catch (_) {
      return {};
    }
  }
}

class LicenseResult {
  final bool ok;
  final String? message;
  final String? code;
  final int? retryInSeconds;
  final bool fromOfflineGrace;

  const LicenseResult({
    required this.ok,
    this.message,
    this.code,
    this.retryInSeconds,
    this.fromOfflineGrace = false,
  });
}
