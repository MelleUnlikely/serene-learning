import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../teacher/create_flashcard_screen.dart';
import '../teacher/quiz_screen.dart';  


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
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 8),
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
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 0),
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
                          trailing: IconButton(
                            icon: const Icon(Icons.quiz, color: Colors.white),
                            onPressed: (){
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) =>
                                QuizScreen(lessonId: lesson['lessonid']))
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
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
            
          ],//children
        ),
        Positioned(
          bottom: 30, // Distance from the bottom of the screen
          right: 30,  // Distance from the right of the screen
          child: FloatingActionButton.extended(
            onPressed: _showCreateLessonDialog,
            label: const Text("Add Lesson",
              style: TextStyle(color: Color(0xFF1D5A71))),
            icon: const Icon(Icons.add, color: Color(0XFF1d5a71)),
            backgroundColor: const Color(0xFFa5ceeb),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}