import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/serene_menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../teacher/teacher_dashboard.dart';
import '../teacher/student_list_screen.dart';  

class CreateClassScreen extends StatefulWidget {
  final int teacherId; // The userID of the teacher
  
  const CreateClassScreen({super.key, required this.teacherId});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _classNameController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();

  String _curriculumLevel = 'Beginner';
  bool _isLoading = false;
  List<Map<String, dynamic>> _myClasses = [];

  final List<String> _levels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _fetchMyClasses();
  }

  // Fetch classes
  Future<void> _fetchMyClasses() async {

    final userId = widget.teacherId == 0 
        ? Supabase.instance.client.auth.currentUser?.id 
        : widget.teacherId;

    if (userId == null) return;
    
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

  Future<void> _deleteClass(int classId) async {
    try {
      await Supabase.instance.client.from('class').delete().eq('classid', classId);
      _fetchMyClasses();
      _showSnackBar("Class deleted", Colors.grey);
    } catch (e) {
      _showSnackBar("Could not delete class", Colors.red);
    }
  }


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
        'curriculumlevel': _curriculumLevel,
      });

      _classNameController.clear();

      setState(() => _curriculumLevel = 'Beginner');

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
      backgroundColor: Colors.white,
      key: _scaffoldkey,
      endDrawer: const SereneDrawer(),
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
          Expanded( //this is ung create class part (ung left)
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text("Create New Class",
                    style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  TextField(controller: _classNameController,
                    decoration: const InputDecoration(labelText: "Class Name",
                    border: OutlineInputBorder())),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    initialValue: _curriculumLevel,
                    dropdownColor: Colors.white,
                    items: _levels.map((l) => DropdownMenuItem(value: l,
                      child: Text(l))).toList(),
                    onChanged: (val) => setState(() => _curriculumLevel = val!),
                    decoration: const InputDecoration(labelText: "Curriculum Level", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  _isLoading ? const CircularProgressIndicator() :
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFa5ceeb),
                        foregroundColor: const Color(0xFF006064),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(200, 45),
                      ),
                      onPressed: _createNewClass,
                      child: const Text("Create Class", 
                        style: TextStyle(color: Color(0xFF1D5A71)))),
                ],
              ),
            ),
          ),

          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF1D5A71)),


          Expanded( //this is the one in the right (manage class)
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      "Manage Class",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: _myClasses.length,
                      itemBuilder: (context, index) {
                        final c = _myClasses[index];
                        return ListTile(
                          title: Text(c['classname']),
                          subtitle: Text("Level: ${c['curriculumlevel']} | Code: ${c['classcode']}"),
                          trailing: SizedBox(
                                  width: 100, 
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.people_outline, color: Color(0xFF1D4E5F)),
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => StudentListScreen(
                                            classId: c['classid'],
                                            className: c['classname'],
                                          )));
                                        },
                                      ),
                                      IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        // Trigger the confirmation dialog
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text("Delete Class?"),
                                              content: const Text(
                                                "This action cannot be undone. All lessons and student enrollments linked to this class will be permanently deleted.",
                                              ),
                                              actions: [
                                                // Cancel Button
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                                ),
                                                // Confirm Delete Button
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _deleteClass(c['classid']); 
                                                  },
                                                  child: const Text(
                                                    "Delete",
                                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    ],
                                  ),
                                ),
                            onTap: () {
                             Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TeacherDashboard(
                                    classId: c['classid'],      // passing the int
                                    className: c['classname'],
                                    gradeLevel: c['curriculumlevel'], // passing the level
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
            )
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}