import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/serene_menu.dart';

class AboutPage extends StatelessWidget {
  AboutPage({super.key});
  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldkey,
      endDrawer: const SereneDrawer(),

      //header mo dito...
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Serene",
          style: TextStyle(
            color: Color(0xFF1D5A71),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Color(0xFF1D5A71)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1D5A71)),
            onPressed: () {
              _scaffoldkey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: 15),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, color: Color(0xFF1D5A71)),
        ),
      ),

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
              constraints: const BoxConstraints(maxWidth: 800),
              margin: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
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
                    child: _buildAboutContent(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutContent(BuildContext context) {
  return Column(
    children: [
      Stack(
        alignment: Alignment.center, // Keeps the title in the absolute middle
        children: [
          // Use a Row here to ensure the title doesn't get covered
          const Center(
            child: Text(
              "About Serene",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D5A71),
              ),
            ),
          ),
          // Position the close button to the far right
          Positioned(
            right: -10, // Adjust this to nudge the 'X' closer to the edge
            top: -10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF1D5A71), size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
        const Text(
          "Serene is a mobile application dedicated to bridging the communication gap for deaf students. Our mission is to provide an interactive and engaging platform for learning Filipino Sign Language (FSL).",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.black87, height: 1.5),
        ),
        const SizedBox(height: 20),
        const Divider(color: Color(0xFF1D5A71)),
        const SizedBox(height: 20),
        _buildSectionTitle("Our Goal"),
        const Text(
          "To address the low literacy skills among deaf learners, and the lack of interactive and engaging learning materials and tools that are affordable and accessible through flashcards, quizzes, and instructional videos.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 30),
        const Divider(color: Color(0xFF1D5A71)),
        const SizedBox(height: 20),
        _buildSectionTitle("Meet the Team"),
        const SizedBox(height: 20),

        Wrap(
          spacing: 40, //space between sa members
          alignment: WrapAlignment.center,
          children: [
            _buildTeamMember("Sophia Narcelles", "Chief Operating Officer", "assets/images/Narcelles.png"),
            _buildTeamMember("Shamelle Climaco", "Chief Executive Officer", "assets/images/Climaco.png"),
            _buildTeamMember("Keithly Padaoan", "Chief Financial Officer", "assets/images/Padaoan.png"),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1D5A71),
        ),
      ),
    );
  }

  Widget _buildTeamMember(String name, String role, String imagePath) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD0EDF9),
            border: Border.all(
              color: const Color(0xFF1D5A71),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.person, size: 60, color: Color(0xFF1D5A71));
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)),
        ),
        Text(role, style: const TextStyle(color: Colors.black54, fontSize: 14)),
      ],
    );
  }
}