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
            "New Lesson for ${widget.className}",
            style: const TextStyle(
              color: Color(0xFF1D5A71),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: SizedBox(
          width: 500,
          child: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: TextField(
              cursorColor: Color(0xFF1D5A71),
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Lesson Title",
                labelStyle: TextStyle(color: Color(0xFF1D5A71)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0XFF7AA9CA), width: 1),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF1D5A71), width: 2)
                  ),
              ),
            ),
          ),    
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF1D5A71))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFa5ceeb),
              foregroundColor: const Color(0xFF1D5A71),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                await _createNewLesson(titleController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _deleteLesson(int id) async {
  try {
    // We target the specific lessonid
    await Supabase.instance.client
        .from('lesson')
        .delete()
        .eq('lessonid', id); 

    _fetchLessons(); 
    _showSnackBar("Lesson deleted successfully", Colors.green);
  } catch (e) {
    _showSnackBar("Failed to delete lesson: $e", Colors.red);
  }
}

Future<String> _copyFile(String fullUrl, String folder) async {
  final String bucketPathSegment = '/public/media/';
  if (!fullUrl.contains(bucketPathSegment)) {
    throw Exception("Invalid storage URL format");
  }
  
  String relativePath = fullUrl.split(bucketPathSegment).last;

  final fileName = relativePath.split('/').last;
  final String newRelativePath = "$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName";
  
  await Supabase.instance.client.storage
      .from('media')
      .copy(relativePath, newRelativePath);
  
  return Supabase.instance.client.storage
      .from('media')
      .getPublicUrl(newRelativePath);
}

Future<void> _duplicateLessonWithContent({
  required int originalLessonId,
  required int targetClassId,
}) async {
  if (_isLoading) return; 

  setState(() => _isLoading = true);

  try {
    final lessonData = await Supabase.instance.client
        .from('lesson')
        .select()
        .eq('lessonid', originalLessonId)
        .single();

    final newLesson = await Supabase.instance.client.from('lesson').insert({
      'classid': targetClassId,
      'lessontitle': "${lessonData['lessontitle']} (Copy)",
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    final int newLessonId = newLesson['lessonid'];

    final List<dynamic> originalCards = await Supabase.instance.client
        .from('flashcard')
        .select()
        .eq('lessonid', originalLessonId);

    for (var card in originalCards) {
      String? newImgUrl;
      String? newVideoUrl;

      // Handle Image Copying
      if (card['imgurl'] != null && card['imgurl'].toString().isNotEmpty) {
        try {
          newImgUrl = await _copyFile(card['imgurl'], 'images');
        } catch (e) {
          debugPrint("Image copy failed for card ${card['flashcardid']}: $e");
        }
      }

      // Handle Video Copying
      if (card['videourl'] != null && card['videourl'].toString().isNotEmpty) {
        try {
          newVideoUrl = await _copyFile(card['videourl'], 'videos');
        } catch (e) {
          debugPrint("Video copy failed for card ${card['flashcardid']}: $e");
        }
      }

      await Supabase.instance.client.from('flashcard').insert({
        'lessonid': newLessonId,
        'signmeaning': card['signmeaning'],
        'imgurl': newImgUrl,
        'videourl': newVideoUrl,
      });
    }

    _showSnackBar("Lesson successfully imported to the selected class!", Colors.green);

    _fetchLessons(); 

  } catch (e) {
    debugPrint("Deep Copy Error: $e");
    _showSnackBar("An error occurred during the import process.", Colors.red);
  } finally {
    setState(() => _isLoading = false);
  }
}

  // Dialog to select destination class
  Future<void> _showImportDialog(int lessonId) async {
    try {
      final classesData = await Supabase.instance.client
          .from('class')
          .select('classid, classname')
          .neq('classid', widget.classId);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Import Lesson to...", style: TextStyle(color: Color(0xFF1D5A71))),
          content: SizedBox(
            width: double.maxFinite,
            child: classesData.isEmpty 
              ? const Text("No other classes found.")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: classesData.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.class_, color: Color(0xFF1D5A71)),
                      title: Text(classesData[index]['classname']),
                      onTap: _isLoading ? null : () {
                        Navigator.pop(context);
                        
                        _duplicateLessonWithContent(
                          originalLessonId: lessonId,
                          targetClassId: classesData[index]['classid'],
                        );
                      },
                    );
                  },
                ),
          ),
        ),
      );
    } catch (e) {
      _showSnackBar("Could not load classes", Colors.red);
    }
  }



  @override
Widget build(BuildContext context) {
  return Stack(
    children: [
      // Main UI Layer
      Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
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

            // Content Section
            Expanded(
<<<<<<< HEAD
              child: _lessons.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : _buildLessonList(),
=======
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _lessons.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          "No lessons created yet!",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 0),
                    itemCount: _lessons.length,
                    itemBuilder: (context, index) {
                      final lesson = _lessons[index];
                      return Card(
                        color: Color(0xFFA5CEEB), 
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
                                icon: const Icon(Icons.quiz, color: Colors.white),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => QuizScreen(lessonId: lesson['lessonid'])),
                                  );
                                },
                              ),
                              IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
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
                                      child: const Row(
                                        children: [
                                          Icon(Icons.logout, color: Color(0xFF1D5A71)),
                                          SizedBox(width: 12),
                                          Text(
                                            "Delete Lesson?",
                                            style: TextStyle(color: Color(0xFF1D5A71), fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    content: Padding(
                                        padding: EdgeInsets.only(top: 20.0),
                                        child: Text(
                                          "Are you sure you want to delete '${lesson['lessontitle']}'? This action cannot be undone.",
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
                                          _deleteLesson(lesson['lessonid']);
                                          Navigator.pop(context);
                                        },
                                        child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) =>CreateFlashcardScreen (
                                  lessonId: lesson['lessonid'],
                                  lessontitle: lesson['lessontitle']
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
>>>>>>> ec3fd0f4cab830f957e42c4a3de771566fde5a9c
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateLessonDialog,
          label: const Text("Add Lesson", style: TextStyle(color: Color(0xFF1D5A71))),
          icon: const Icon(Icons.add, color: Color(0XFF1d5a71)),
          backgroundColor: const Color(0xFFa5ceeb),
        ),
      ),

      if (_isLoading)
        Container(
          color: Colors.black.withOpacity(0.4), 
          child: Center(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1D5A71)),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Please wait...",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D5A71),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Updating your curriculum",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

// Helper method for the Empty State UI
Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          "No lessons created yet!",
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// Helper method to build the scrollable list of lessons
Widget _buildLessonList() {
  return ListView.builder(
    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100, top: 0),
    itemCount: _lessons.length,
    itemBuilder: (context, index) {
      final lesson = _lessons[index];
      return Card(
        color: const Color(0xFFa5ceeb),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          leading: const Icon(Icons.book, color: Color(0XFF1d5a71)),
          title: Text(
            lesson['lessontitle'],
            style: const TextStyle(color: Color(0xFF1D5A71), fontWeight: FontWeight.bold),
          ),
          subtitle: const Text("Manage materials", style: TextStyle(color: Color(0xFF1D5A71))),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.content_copy, color: Colors.white, size: 20),
                tooltip: "Import to another class",
                onPressed: () => _showImportDialog(lesson['lessonid']),
              ),
              IconButton(
                icon: const Icon(Icons.quiz, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => QuizScreen(lessonId: lesson['lessonid'])),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteConfirmDialog(lesson), // Ensure this method is implemented
              ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateFlashcardScreen(
                  lessonId: lesson['lessonid'],
                  lessontitle: lesson['lessontitle'],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

Future<void> _showDeleteConfirmDialog(Map<String, dynamic> lesson) async {
  return showDialog(
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
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFF1D5A71)),
            SizedBox(width: 12),
            Text(
              "Confirm Deletion",
              style: TextStyle(
                color: Color(0xFF1D5A71),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 15.0),
        child: Text(
          "Are you sure you want to delete '${lesson['lessontitle']}'? This action will permanently remove all associated flashcards and media.",
          style: const TextStyle(color: Color(0xFF1D5A71), fontSize: 16),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Cancel",
            style: TextStyle(color: Color(0xFF1D5A71)),
          ),
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
            _deleteLesson(lesson['lessonid']); 
          },
          child: const Text(
            "Delete",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
        
        //mageseset ng bottom margin to push it to the top of the screen
        margin: EdgeInsets.only(
          bottom: screenHeight - 100, //para mapunta sa taas ung snackbar
          left: screenWidth * 0.8,
          right: 20,
        ),
        
        dismissDirection: DismissDirection.up, // Allows user to swipe it away upwards
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}