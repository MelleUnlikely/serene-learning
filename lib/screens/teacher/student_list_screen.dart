import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/serene_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/widgets/serene_menu.dart';

class StudentListScreen extends StatefulWidget {
  final int classId;
  final String className;

  const StudentListScreen({super.key, required this.classId, required this.className});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('enrollmentrecord')
          .select('*, profiles(fullname, email)')
          .eq('classid', widget.classId);

      if (mounted) {
      setState(() {
        _students = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    }
    
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching students: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeStudent(String userId, String studentName) async {
  try {
    await supabase
        .from('enrollmentrecord')
        .delete()
        .eq('classid', widget.classId)
        .eq('studentid', userId);

    setState(() {
      _students.removeWhere((enrollment) => 
        enrollment['studentid'].toString() == userId
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$studentName has been unenrolled."),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
    
  } catch (e) {
    debugPrint("Error: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to unenroll: $e"), backgroundColor: Colors.red),
      );
    }
  }
}

  void _confirmRemoval(String userId, String name) {
  showDialog(
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
        child: Text(
          "Unenroll Student?",
          style: const TextStyle(
            color: Color(0xFF1D5A71),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      content: Padding(
        padding: EdgeInsets.only(top: 20.0),
        child: Text(
          "Are you sure you want to remove $name from this class? They will no longer see the class materials, but their previous quiz records will be preserved in the system.",
          style: TextStyle(color: Color(0xFF1D5A71), fontSize: 16)
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Color(0xFF1D5A71))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            Navigator.pop(context);
            _removeStudent(userId, name);
          },
          child: const Text("Unenroll", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldkey,
      endDrawer: const SereneDrawer(),
      appBar: SereneHeader(scaffoldKey: _scaffoldkey, showBackButton: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Text(
                    "Students: ${widget.className}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)),
                  ),
                ),
                Expanded(
                  child: _students.isEmpty
                      ? const Center(
                          child: Text("No students enrolled yet.", style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final enrollment = _students[index];
                            final student = enrollment['profiles'];
                            
                            final String userId = enrollment['studentid'].toString();
                            final String name = student['fullname'] ?? "Unknown Student";
                            final firstLetter = name.isNotEmpty ? name[0] : "?";

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF1D5A71),
                                child: Text(firstLetter, style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(name),
                              subtitle: Text(student['email'] ?? ""),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                                onPressed: () => _confirmRemoval(userId, name),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}