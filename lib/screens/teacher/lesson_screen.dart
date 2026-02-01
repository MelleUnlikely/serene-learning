import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../teacher/create_flashcard_screen.dart';
import '../teacher/quiz_screen.dart';  
import 'package:flutter_application_1/widgets/serene_menu.dart';

class LessonManagementScreen extends StatefulWidget {
  final int classId;
  final String className;
  final String gradeLevel;

  const LessonManagementScreen({
    super.key, 
    required this.classId, 
    required this.className,
    required this.gradeLevel,
  });

  @override
  State<LessonManagementScreen> createState() => _LessonManagementScreenState();
}

class _LessonManagementScreenState extends State<LessonManagementScreen> {
  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> _lessons = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLessons();
  }

  //get lessons for this class

  Future<void> _fetchLessons() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('lesson')
          .select('lessonid, lessontitle')
          .eq('classid', widget.classId)
          .order('created_at');
      setState(() => _lessons = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      _showSnackBar("Error loading lessons: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // create lesson
  Future<void> _showCreateLessonDialog() async {
    final titleController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("New Lesson for ${widget.gradeLevel}"),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: "Lesson Title"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                await _createNewLesson(titleController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewLesson(String title) async {
    try {
      await Supabase.instance.client.from('lesson').insert({
        'classid': widget.classId,
        'lessontitle': title,
      });
      _fetchLessons();
    } catch (e) {
      _showSnackBar("Failed to create lesson", Colors.red);
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

      body: Row(
        children: [
          //for the sidebar
          Container(
            width: 250,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xFF1D5A71), 
                width: 1.0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildSidebarItem("Upload Lesson", isSelected: true),
                _buildSidebarItem("Student's Performance", isSelected: false),
              ],
            ),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //"parang title" to see which class is currently being "edited/viewed"
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "${widget.className} - ${widget.gradeLevel}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D5A71),
                    ),
                  ),
                ),
                
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _lessons.length,
                            itemBuilder: (context, index) {
                              final lesson = _lessons[index];
                              return Card(
                                color: Color(0xFFa5ceeb), 
                                child: ListTile(
                                  leading: const Icon(Icons.book, color: Color(0XFF1d5a71)), //icon for the lesson
                                  title: Text(lesson['lessontitle'],
                                    style: TextStyle(color: Color(0xFF1D5A71), fontWeight: FontWeight.bold),),
                                  subtitle: const Text("Manage materials",
                                    style: TextStyle(color: Color(0xFF1D5A71))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.quiz, color:Colors.white),
                                        tooltip: 'Generate Quiz',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => QuizScreen(lessonId: lesson['lessonid']),
                                            ),
                                          );
                                        },
                                      ),
                                      const Icon(Icons.chevron_right, color: Color(0XFF1d5a71)),
                                    ],
                                  ),
                                  onTap: () {Navigator.push(context,
                                        MaterialPageRoute(builder: (context) =>CreateFlashcardScreen (
                                            lessonId: lesson['lessonid']
                                          ),
                                        ),
                                      );
                                    },
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateLessonDialog,
        label: const Text("Add Lesson",
          style: TextStyle(color: Color(0xFF1D5A71))),
        icon: const Icon(Icons.add, color: Color(0XFF1d5a71)),
        backgroundColor: const Color(0xFFa5ceeb),
      ),
    );
  }

  // Helper widget to keep the sidebar code clean
  Widget _buildSidebarItem(String title, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        border: isSelected 
          ? const Border(left: BorderSide(color: Color(0xFF1D5A71), width: 5)) 
          : null,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isSelected ? const Color(0xFF1D5A71) : Colors.black54,
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}