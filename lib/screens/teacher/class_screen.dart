
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
  List<Map<String, dynamic>> _activityLogs = [];

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

  // Mark one specific notification as read when tapped
  Future<void> _markSingleAsRead(int id) async {
    await Supabase.instance.client
        .from('notification')
        .update({'is_read': true})
        .eq('id', id);
  }

  // Mark everything for this teacher as read
  Future<void> _markAllAsRead() async {
    try {
      await Supabase.instance.client
          .from('notification')
          .update({'is_read': true})
          .eq('teacher_id', widget.teacherId)
          .eq('is_read', false);
      _showSnackBar("All caught up!", Colors.green);
    } catch (e) {
      debugPrint("Error updating notifications: $e");
    }
  }

  void _createClassDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // StatefulBuilder allows dropdown to work inside dialog
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: _buildDialogHeader("Create New Class", icon: Icons.add_business_rounded),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  TextField(
                    controller: _classNameController,
                    decoration: _buildInputDecoration("Class Name"),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _curriculumLevel,
                    dropdownColor: Colors.white,
                    items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (val) => setDialogState(() => _curriculumLevel = val!),
                    decoration: _buildInputDecoration("Curriculum Level"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              _buildPrimaryButton("Create", () async {
                _createNewClass();
                Navigator.pop(context);
              }),
            ],
          );
        }
      ),
    );
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
      appBar: SereneHeader(scaffoldKey: _scaffoldkey, showNotificationIcon: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClassDialog,
        backgroundColor: const Color(0xFFa5ceeb),
        icon: const Icon(Icons.add, color: Color(0xFF1D5A71)),
        label: const Text("Create Class", style: TextStyle(color: Color(0xFF1D5A71))),
      ),
      body: Row(
        children: [
          Expanded( //this is ung create class part (ung left)
            flex: 1,
            child: _buildActivityLog(),
          ),

          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF1D5A71)),

          Expanded( //this is the one in the right (manage class)
            flex: 3,
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

  Widget _buildActivityLog() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER WITH UNREAD COUNT AND MARK ALL ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Activities",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)),
              ),
              TextButton(
                onPressed: _markAllAsRead,
                child: const Text("Mark all as read", style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // --- STREAM OF NOTIFICATIONS ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('notification')
                  .stream(primaryKey: ['id'])
                  .eq('teacher_id', widget.teacherId)
                  .order('created_at', ascending: false)
                  .limit(15),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final logs = snapshot.data!;

                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final notif = logs[index];
                    final bool isUnread = notif['is_read'] == false;

                    return GestureDetector(
                      onTap: () => _markSingleAsRead(notif['id']),
                      child: Card(
                        elevation: 0,
                        // Unread items get a slightly different background
                        color: isUnread ? const Color(0xFFF0F9FF) : const Color(0xFFF5F9FA),
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: isUnread 
                              ? const BorderSide(color: Color(0xFF7AA9CA), width: 1) 
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Stack(
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0xFFD0EDF9),
                                child: Icon(Icons.assignment_ind_rounded, size: 14, color: Color(0xFF1D5A71)),
                              ),
                              if (isUnread)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            notif['message'] ?? "",
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                              color: const Color(0xFF1D5A71),
                            ),
                          ),
                          subtitle: Text(_formatTimestamp(notif['created_at']), style: const TextStyle(fontSize: 10)),
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

  // Copy this from your Header so the times match
  String _formatTimestamp(String? isoString) {
    if (isoString == null) return "";
    final date = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final timeStr = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    if (date.year == now.year && date.month == now.month && date.day == now.day) return "Today • $timeStr";
    return "${date.month}/${date.day} • $timeStr";
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
          bottom: screenHeight - 150, //para mapunta sa taas ung snackbar
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

  Widget _buildDialogHeader(String title, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFD0EDF9),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, color: const Color(0xFF1D5A71)), const SizedBox(width: 12)],
          Text(title, style: const TextStyle(color: Color(0xFF1D5A71), fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF1D5A71)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1D5A71), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1D5A71), width: 2.0),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFa5ceeb),
        foregroundColor: const Color(0xFF1D5A71),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

}