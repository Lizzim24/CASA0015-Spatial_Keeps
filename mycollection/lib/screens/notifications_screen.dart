import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ProfileService _profileService = ProfileService();

  bool _isLoading = true;
  bool _isSaving = false;

  bool _notificationsEnabled = true;
  bool _weeklyInsights = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _profileService.getUserSettings();
      _notificationsEnabled =
          (settings['notificationsEnabled'] ?? true) == true;
      _weeklyInsights = (settings['weeklyInsights'] ?? true) == true;
    } catch (e) {
      debugPrint('Notification settings load error: $e');
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
        'notificationsEnabled': _notificationsEnabled,
        'weeklyInsights': _weeklyInsights,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification settings updated')),
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
        title: const Text('Notifications'),
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
                  title: const Text('Enable notifications'),
                  subtitle: const Text('Receive app updates and reminders.'),
                  value: _notificationsEnabled,
                  onChanged: (v) {
                    setState(() {
                      _notificationsEnabled = v;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Weekly spatial insights'),
                  subtitle: const Text(
                    'Receive a summary of your spatial archive activity.',
                  ),
                  value: _weeklyInsights,
                  onChanged: (v) {
                    setState(() {
                      _weeklyInsights = v;
                    });
                  },
                ),
              ],
            ),
    );
  }
}
