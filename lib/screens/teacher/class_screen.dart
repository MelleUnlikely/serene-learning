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
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Classes")),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text("Create New Class", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(controller: _classNameController, decoration: const InputDecoration(labelText: "Class Name", border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: _curriculumLevel,
                    items: ['Beginner', 'Intermediate', 'Advanced'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (val) => setState(() => _curriculumLevel = val!),
                    decoration: const InputDecoration(labelText: "Curriculum Level", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _createNewClass, child: const Text("Create Class")),
                ],
              ),
            ),
          ),
          const VerticalDivider(),

          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: _myClasses.length,
              itemBuilder: (context, index) {
                final c = _myClasses[index];
                return ListTile(
                  title: Text(c['classname']),
                  subtitle: Text("Level: ${c['curriculumlevel']} | Code: ${c['classcode']}"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {Navigator.push(context,
                        MaterialPageRoute(builder: (context) => LessonManagementScreen(
                            classId: c['classid'],
                            className: c['classname'],
                            gradeLevel: c['curriculumlevel'],
                          ),
                        ),
                      );
                    },
                );
              },
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