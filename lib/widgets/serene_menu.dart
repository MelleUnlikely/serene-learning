import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/about.dart';


class SereneDrawer extends StatelessWidget {
  const SereneDrawer({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final supabase = Supabase.instance.client;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFFD0EDF9),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout, color: Color(0xFF1D5A71)),
              SizedBox(width: 12),
              Text(
                "Log Out",
                style: TextStyle(color: Color(0xFF1D5A71), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 20.0),
          child: Text(
            "Are you sure you want to sign out?",
            style: TextStyle(color: Color(0xFF1D5A71), fontSize: 16)
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF1D5A71))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.auth.signOut();

        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error logging out: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

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
          const Divider(indent: 20, endIndent: 20, thickness: 1, color: Color(0xFF1D5A71)),
          _buildMenuItem(Icons.help_outline, "About",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AboutPage()));
            }),
          _buildMenuItem(Icons.logout, "Logout", () => _handleLogout(context)),
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