import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_service.dart';
import 'account_settings_screen.dart';
import 'export_spatial_data_screen.dart';
import 'notifications_screen.dart';
import 'privacy_security_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadProfilePage();
  }

  Future<void> _loadProfilePage() async {
    try {
      final profile = await _profileService.getUserProfile();
      final stats = await _profileService.getProfileStats();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _stats = stats;
      });
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    } finally {
      if (mounted) {  
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _profileService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  String _displayName(User? user) {
    final stored = (_profile['displayName'] ?? '').toString().trim();
    if (stored.isNotEmpty) return stored;

    final authName = (user?.displayName ?? '').trim();
    if (authName.isNotEmpty) return authName;

    return 'Spatial Curator';
  }

  String _email(User? user) {
    final stored = (_profile['email'] ?? '').toString().trim();
    if (stored.isNotEmpty) return stored;
    return user?.email ?? '';
  }

  String _photoUrl(User? user) {
    final stored = (_profile['photoUrl'] ?? '').toString().trim();
    if (stored.isNotEmpty) return stored;
    return user?.photoURL ?? '';
  }

  String _bio() {
    return (_profile['bio'] ?? '').toString().trim();
  }

  String _buildProfileSummary({
    required int captures,
    required int activeDays,
    required int shared,
    required int places,
  }) {
    if (captures == 0) {
      return 'You have not created a spatial archive yet. Start capturing light, place, and perspective to build your personal record of environmental experience.';
    }

    final sharingStyle =
        shared == 0 ? 'mostly private' : 'partly shared with others';
    final activityStyle =
        activeDays <= 3 ? 'a growing archive' : 'a steadily developing archive';

    return 'You have built $activityStyle with $captures captures across $activeDays active day${activeDays == 1 ? '' : 's'}, covering $places place${places == 1 ? '' : 's'}. Your archive is $sharingStyle and reflects an ongoing practice of recording personal spatial experience.';
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

    if (picked == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final file = File(picked.path);
      await _profileService.uploadAvatar(file);
      await _loadProfilePage();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) {  
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeAvatar() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _profileService.removeAvatar();
      await _loadProfilePage();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar removed')),
      );
    } catch (e) {
      debugPrint('Remove avatar error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove avatar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final displayName = _displayName(user);
    final email = _email(user);
    final photoUrl = _photoUrl(user);
    final bio = _bio();

    final captures = (_stats['captures'] ?? 0) as int;
    final tags = (_stats['tags'] ?? 0) as int;
    final shared = (_stats['shared'] ?? 0) as int;
    final places = (_stats['locations'] ?? 0) as int;
    final activeDays = (_stats['activeDays'] ?? 0) as int;

    final profileSummary = _buildProfileSummary(
      captures: captures,
      activeDays: activeDays,
      shared: shared,
      places: places,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfilePage,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 80),

                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _showAvatarOptions,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE6D5B8),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: photoUrl.isNotEmpty
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 42,
                                        color: Colors.black45,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x33E6D5B8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'SPATIAL MEMBER',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB5A48B),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                bio,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PROFILE SUMMARY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.02),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              profileSummary,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ARCHIVE SUMMARY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildStatCard(
                                'Captures',
                                captures.toString(),
                                Icons.camera_outlined,
                                flex: 2,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                'Active Days',
                                activeDays.toString(),
                                Icons.calendar_today_outlined,
                                flex: 1,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatCard(
                                'Shared',
                                shared.toString(),
                                Icons.share_outlined,
                                flex: 1,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                'Places',
                                places.toString(),
                                Icons.location_on_outlined,
                                flex: 1,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                'Tags',
                                tags.toString(),
                                Icons.tag_outlined,
                                flex: 1,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PREFERENCES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSettingsItem(
                            title: 'Account Settings',
                            icon: Icons.person_outline,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AccountSettingsScreen(),
                                ),
                              );
                              _loadProfilePage();
                            },
                          ),
                          _buildSettingsItem(
                            title: 'Privacy & Security',
                            icon: Icons.lock_outline,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const PrivacySecurityScreen(),
                                ),
                              );
                            },
                          ),
                          _buildSettingsItem(
                            title: 'Notifications',
                            icon: Icons.notifications_none_outlined,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const NotificationsScreen(),
                                ),
                              );
                            },
                          ),
                          _buildSettingsItem(
                            title: 'Export Spatial Data',
                            icon: Icons.ios_share_outlined,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ExportSpatialDataScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSettingsItem(
                            title: 'Logout',
                            icon: Icons.logout,
                            isDestructive: true,
                            onTap: _handleLogout,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon, {
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.02),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFE6D5B8)),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : Colors.black87,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.redAccent : Colors.black87,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
        size: 18,
      ),
      onTap: onTap,
    );
  }
}
