import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../teacher/lesson_screen.dart'; 

class CreateClassScreen extends StatefulWidget {
  final int teacherId; // The userID of the teacher
  
  const CreateClassScreen({super.key, required this.teacherId});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _classNameController = TextEditingController();
  String _curriculumLevel = 'Beginner';
  bool _isLoading = false;
  List<Map<String, dynamic>> _myClasses = [];

  @override
  void initState() {
    super.initState();
    _fetchMyClasses();
  }

  // Fetch classes
  Future<void> _fetchMyClasses() async {
    final data = await Supabase.instance.client
        .from('class')
        .select()
        .eq('teacherid', widget.teacherId);
    setState(() => _myClasses = List<Map<String, dynamic>>.from(data));
  }

  // Generate class code
  String _generateClassCode() {
    return (Random().nextInt(9000) + 1000).toString();
  }

//curriculum lebels
final String _selectedGrade = 'Grade 1';
final List<String> _gradeLevels = [
  'Grade 1', 
  'Grade 2', 
  'Grade 3', 
  'Grade 4', 
  'Grade 5', 
  'Grade 6'
];

//create class
  Future<void> _createNewClass() async {
    if (_classNameController.text.isEmpty) {
      _showSnackBar("Please enter a class name", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    final String code = _generateClassCode();

    try {
      await Supabase.instance.client.from('class').insert({
        'teacherid': widget.teacherId,
        'classname': _classNameController.text.trim(),
        'classcode': code,
        'curriculumlevel': _selectedGrade,
      });

      _classNameController.clear();
      _fetchMyClasses(); 
      _showSnackBar("Class Created! Students use code: $code", Colors.green);
    } catch (e) {
      _showSnackBar("Error creating class: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( //think header lah. your header.
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5, // Thin gray line separator
        centerTitle: false,
        title: const Text(
          "Serene",
          style: TextStyle(
            color: Color(0xFF1D5A71), // Dark teal from your reference
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
            onPressed: () {},
          ),
          const SizedBox(width: 15),
        ],
      ),
      
      body: Row(
        children: [
          // Left Side: Create New Class Form
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 50.0),
              child: Column(
                children: [
                  const Text(
                    "Create New Class",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _classNameController,
                    decoration: const InputDecoration(
                      labelText: "Class Name",
                      border: OutlineInputBorder(), // Keeping your current style
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _curriculumLevel,
                    decoration: const InputDecoration(
                      labelText: "Curriculum Level",
                      border: OutlineInputBorder(),
                    ),
                    items: ['Beginner', 'Intermediate', 'Advanced']
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (val) => setState(() => _curriculumLevel = val!),
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF3E5F5), // Light purple button
                            foregroundColor: const Color(0xFF7B1FA2),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          onPressed: _createNewClass,
                          child: const Text("Create Class"),
                        ),
                ],
              ),
            ),
          ),
          
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF1D5A71)),

          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subsection Title
                const Padding(
                  padding: EdgeInsets.only(left: 30, top: 20, bottom: 10),
                  child: Text(
                    "Manage Classes",
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _myClasses.length,
                    itemBuilder: (context, index) {
                      final c = _myClasses[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
                        title: Text(
                          c['classname'],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                        ),
                        subtitle: Text(
                          "Level: ${c['curriculumlevel']} | Code: ${c['classcode']}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Navigation to LessonManagementScreen
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}