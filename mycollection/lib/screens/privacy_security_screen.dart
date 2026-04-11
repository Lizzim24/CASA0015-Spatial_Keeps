import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  final ProfileService _profileService = ProfileService();

  bool _isLoading = true;
  bool _isSaving = false;

  bool _privateByDefault = false;
  bool _allowPublicSharing = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _profileService.getUserSettings();
      _privateByDefault = (settings['privateByDefault'] ?? false) == true;
      _allowPublicSharing = (settings['allowPublicSharing'] ?? true) == true;
    } catch (e) {
      debugPrint('Privacy settings load error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    try {
      setState(() {
        _isSaving = true;
      });

      await _profileService.updateUserSettings({
        'privateByDefault': _privateByDefault,
        'allowPublicSharing': _allowPublicSharing,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy settings updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SwitchListTile(
                  title: const Text('Private by default'),
                  subtitle: const Text(
                    'New captures are private unless changed manually.',
                  ),
                  value: _privateByDefault,
                  onChanged: (v) {
                    setState(() {
                      _privateByDefault = v;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Allow public sharing'),
                  subtitle: const Text(
                    'Allow selected captures to appear in public views.',
                  ),
                  value: _allowPublicSharing,
                  onChanged: (v) {
                    setState(() {
                      _allowPublicSharing = v;
                    });
                  },
                ),
              ],
            ),
    );
  }
}
