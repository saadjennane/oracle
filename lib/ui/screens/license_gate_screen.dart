import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/license_service.dart';
import '../../ui/theme/app_theme.dart';
import 'home_screen.dart';

class LicenseGateScreen extends StatefulWidget {
  const LicenseGateScreen({super.key});

  @override
  State<LicenseGateScreen> createState() => _LicenseGateScreenState();
}

class _LicenseGateScreenState extends State<LicenseGateScreen> {
  final _service = LicenseService();
  final _licenseCtrl = TextEditingController();

  bool _loading = true;
  bool _activating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final result = await _service.validate();
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }
    setState(() {
      _loading = false;
      _error = result.message;
    });
  }

  Future<void> _buy() async {
    final uri = Uri.parse(LicenseService.checkoutUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _activate() async {
    setState(() {
      _activating = true;
      _error = null;
    });

    final result = await _service.activate(_licenseCtrl.text);
    if (!mounted) return;

    if (result.ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    String msg = result.message ?? 'Activation failed';
    if (result.code == 'COOLDOWN_ACTIVE' && result.retryInSeconds != null) {
      final h = (result.retryInSeconds! / 3600).ceil();
      msg = 'This license was transferred recently. For security, you can activate it on this phone in about $h hour(s).';
    }

    setState(() {
      _activating = false;
      _error = msg;
    });
  }

  void _enterWithoutLicense() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Oracle License', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Active ta licence pour débloquer l\'app.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _licenseCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Clé licence',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _activating ? null : _activate,
                  child: Text(_activating ? 'Activation...' : 'Activer ma licence'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _buy,
                  child: const Text('Acheter une licence'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _enterWithoutLicense,
                  child: const Text('Enter without license'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
