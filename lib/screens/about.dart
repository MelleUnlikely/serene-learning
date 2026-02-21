import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1D5A71)),
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
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(40),
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
              child: _buildAboutContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutContent() {
    return Column(
      children: [
        const Text(
          "About Serene",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D5A71),
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          "Serene is a mobile application dedicated to bridging the communication gap for deaf students. Our mission is to provide an interactive and engaging platform for learning Filipino Sign Language (FSL).",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.black87, height: 1.5),
        ),
        const SizedBox(height: 30),
        const Divider(color: Color(0xFF1D5A71)),
        const SizedBox(height: 30),
        _buildSectionTitle("Our Goal"),
        const Text(
          "To address the low literacy skills among deaf learners, and the lack of interactive and engaging learning materials and tools that are affordable and accessible through flashcards, quizzes, and instructional videos.",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        const Divider(color: Color(0xFF1D5A71)),
        const SizedBox(height: 30),
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