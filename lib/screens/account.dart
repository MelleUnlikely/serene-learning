import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/serene_header.dart';
import 'package:flutter_application_1/widgets/serene_menu.dart';

class AccountPage extends StatelessWidget {
  final String userName;
  final String schoolName;
  final String employeeId;

  AccountPage({
    super.key,
    required this.userName,
    required this.schoolName,
    required this.employeeId,
  });

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: const SereneDrawer(),
      appBar: SereneHeader(scaffoldKey: _scaffoldKey, showBackButton: false),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: _buildAccountContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountContent(BuildContext context) {
    return Column(
      children: [
        Stack(
        alignment: Alignment.center,
        children: [
          const Center(
            child: Text(
              "Account Profile",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D5A71),
              ),
            ),
          ),
          Positioned(
            right: -10,
            top: -10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF1D5A71), size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
        const SizedBox(height: 10),
        const Divider(color: Color(0xFF1D5A71)),
        const SizedBox(height: 30),
        
        // Account Details Section
        _buildInfoTile(Icons.person, "Full Name", userName),
        _buildInfoTile(Icons.school, "School", schoolName),
        _buildInfoTile(Icons.badge, "Employee ID", employeeId),
        
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD0EDF9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF1D5A71)),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1D5A71)),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D5A71),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}