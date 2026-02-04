import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/teacher/lesson_screen.dart';
import 'package:flutter_application_1/screens/teacher/student_performance.dart';
import 'package:flutter_application_1/widgets/serene_menu.dart';

class TeacherDashboard extends StatefulWidget {
  final int classId;      // Changed to int to match LessonManagementScreen
  final String className;
  final String gradeLevel; // Added this missing variable

  const TeacherDashboard({
    super.key, 
    required this.classId, 
    required this.className,
    required this.gradeLevel, // Include it in the constructor
  });

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0; // 0 for Lessons, 1 for Analytics

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldkey,
      endDrawer: const SereneDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackButton(color: Color(0xFF1D5A71)),
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
            icon: const Icon(Icons.notifications_none, color: Color(0xFF1D4E5F)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1D4E5F)),
            onPressed: () {
              _scaffoldkey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: 15),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Color(0xFF1D5A71),
            height: 1.0,
          )),
      ),
      body: Row(
        children: [
          // THE SIDEBAR
          Container(
            width: 250,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Colors.black12)),
            ),
            child: Column(
              children: [
                _buildSidebarItem("Lessons", 0),
                _buildSidebarItem("Student Performance", 1),
              ],
            ),
          ),
          // THE DYNAMIC CONTENT
          Expanded(
            child: _selectedIndex == 0 
              ? LessonManagementScreen(
                classId: widget.classId, 
                className: widget.className, 
                gradeLevel: widget.gradeLevel
              ) 
              : StudentPerformanceScreen(classId: widget.classId)
          ),
        ],
      ),
    );
  }

    Widget _buildSidebarItem(String title, int index) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
          color: _selectedIndex == index ? const Color(0xFF1D5A71) : Colors.black54,
        ),
      ),
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }
}