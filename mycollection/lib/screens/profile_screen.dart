import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 80),
            
            // 1. Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE6D5B8), width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage('https://picsum.photos/seed/curator/200'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Ethereal Curator",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  const Text(
                    "lazyw506@gmail.com",
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x33E6D5B8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "PRO MEMBER",
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFB5A48B), letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 2. Stats Bento Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SPATIAL STATS",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 2),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatCard("Captures", "128", Icons.camera_outlined, flex: 2),
                      const SizedBox(width: 12),
                      _buildStatCard("Tags", "42", Icons.tag_outlined, flex: 1),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatCard("Shared", "15", Icons.share_outlined, flex: 1),
                      const SizedBox(width: 12),
                      _buildStatCard("Cities", "4", Icons.location_city_outlined, flex: 2),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 3. Settings List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "PREFERENCES",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  _buildSettingsItem("Account Settings", Icons.person_outline),
                  _buildSettingsItem("Privacy & Security", Icons.lock_outline),
                  _buildSettingsItem("Notifications", Icons.notifications_none_outlined),
                  _buildSettingsItem("Export Spatial Data", Icons.ios_share_outlined),
                  const SizedBox(height: 16),
                  _buildSettingsItem("Logout", Icons.logout, isDestructive: true),
                ],
              ),
            ),
            
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFE6D5B8)),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, {bool isDestructive = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.black87, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.redAccent : Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
      onTap: () {},
    );
  }
}