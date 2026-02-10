import 'package:flutter/material.dart';
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
      
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Text(
                  "Students: ${widget.className}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D5A71),
                  ),
                ),
              ),

              Expanded(
                child: _students.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person, 
                      size: 64, 
                      color: Colors.grey
                    ),
                    const SizedBox(height: 16),
                    Text("No students enrolled yet.", style: TextStyle(color: Colors.grey),)
                  ],
                )
              )
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
              ),
            ],
          ),
    );
  }
}