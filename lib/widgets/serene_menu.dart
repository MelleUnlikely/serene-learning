import 'package:flutter/material.dart';

class SereneDrawer extends StatelessWidget {
  const SereneDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF1D5A71)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    "Menu",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D5A71),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildMenuItem(Icons.person_outline, "Account", () {}),
          _buildMenuItem(Icons.notifications_none, "Notifications", () {}),
          const Divider(indent: 20, endIndent: 20, thickness: 1, color: Color(0xFF1D5A71)),
          _buildMenuItem(Icons.help_outline, "About", () {}),
          _buildMenuItem(Icons.logout, "Logout", () {}),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
      leading: Icon(icon, color: const Color(0xFF1D5A71), size: 28),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          color: Color(0xFF1D5A71),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}