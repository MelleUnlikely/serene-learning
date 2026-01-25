import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentListScreen extends StatefulWidget {
  final int classId;
  final String className;

  const StudentListScreen({super.key, required this.classId, required this.className});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

Future<void> _fetchStudents() async {
  try {
    final data = await supabase
        .from('enrollmentrecord')
        .select('profiles(fullname, email)') 
        .eq('classid', widget.classId);

    setState(() {
      _students = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
    });
  } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching students: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Students: ${widget.className}")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? const Center(child: Text("No students enrolled yet."))
              : ListView.builder(
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index]['profiles'];
                    final name = student['fullname'] ?? "Unknown Student";
                    final firstLetter = name.isNotEmpty ? name[0] : "?";

                    return ListTile(
                      leading: CircleAvatar(child: Text(firstLetter)),
                      title: Text(name),
                      subtitle: Text(student['email'] ?? ""),
                    );
                  },
                ),
    );
  }
}