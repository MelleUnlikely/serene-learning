
import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/serene_header.dart';
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
      _showSnackBar("Class deleted", Colors.orange);
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
      appBar: SereneHeader(scaffoldKey: _scaffoldkey),
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
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D5A71))),
                  const SizedBox(height: 30),
                  TextField(controller: _classNameController,
                    decoration: InputDecoration(
                      labelText: "Class Name",
                      labelStyle: const TextStyle(color: Color(0xFF1D5A71)),
                     enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1D5A71), width: 1.0),
                      ),
                      
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1D5A71), width: 2.0),
                      ),
                      
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red, width: 1.0),
                      ),
                    )
                  ),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    initialValue: _curriculumLevel,
                    dropdownColor: Colors.white,
                    items: _levels.map((l) => DropdownMenuItem(value: l,
                      child: Text(l, style: TextStyle(color: Color(0xFF1D5A71)),))).toList(),
                    onChanged: (val) => setState(() => _curriculumLevel = val!),
                    decoration: InputDecoration(
                      labelText: "Curriculum Level",
                      labelStyle: const TextStyle(color: Color(0xFF1D5A71)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1D5A71), width: 1.0),
                      ),
                      
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1D5A71), width: 2.0),
                      ),
                      
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red, width: 1.0),
                      ),
                    ),
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
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)),
                    ),
                  
                  Expanded(
                    child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      :_myClasses.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            "No classes made yet",
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF1D5A71),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Text(
                            "Use the form on the left to get started.",
                            style: TextStyle(color: Colors.grey),
                          ),
                            ],
                          ),
                        )
                    : ListView.builder(
                      itemCount: _myClasses.length,
                      itemBuilder: (context, index) {
                        final c = _myClasses[index];
                        return ListTile(
                          title: Text(c['classname'], style: TextStyle(color: Color(0xFF1D5A71)),),
                          subtitle: Text("Level: ${c['curriculumlevel']} | Code: ${c['classcode']}", style: TextStyle(color: Color(0xFF1D5A71)),),
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
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.delete_forever, color: Color(0xFF1D5A71)),
                                                    SizedBox(width: 10),
                                                    Text(
                                                      "Delete Class?",
                                                      style: TextStyle(color: Color(0xFF1D5A71), fontSize: 18, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              content: const Padding(
                                                padding: EdgeInsets.only(top: 5.0),
                                                child: Text(
                                                  "This action cannot be undone. All lessons and student enrollments linked to this class will be permanently deleted.",
                                                  style: TextStyle(color: Color(0xFF1D5A71), fontSize: 16)
                                                ),
                                              ),
                                              actions: [
                                                // Cancel Button
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text("Cancel", style: TextStyle(color: Color(0xFF1D4E5F))),
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
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        
        margin: EdgeInsets.only(
          bottom: screenHeight - 100, //para mapunta sa taas ung snackbar
          left: screenWidth * 0.8,
          right: 20,
        ),
        
        dismissDirection: DismissDirection.up, 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}