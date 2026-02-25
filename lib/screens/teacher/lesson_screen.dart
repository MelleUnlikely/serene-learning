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

  // --- Data Logic ---

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
      await Supabase.instance.client.from('lesson').delete().eq('lessonid', id);
      _fetchLessons();
      _showSnackBar("Lesson deleted successfully", Colors.green);
    } catch (e) {
      _showSnackBar("Failed to delete lesson: $e", Colors.red);
    }
  }

  Future<void> _updateLessonTitle(int lessonId, String newTitle) async {
    try {
      await Supabase.instance.client
          .from('lesson')
          .update({'lessontitle': newTitle}).eq('lessonid', lessonId);
      _fetchLessons();
      _showSnackBar("Lesson updated successfully", Colors.green);
    } catch (e) {
      _showSnackBar("Failed to update lesson: $e", Colors.red);
    }
  }

  // --- Import / Deep Copy Logic ---

  Future<String> _copyFile(String fullUrl, String folder) async {
    const String bucketPathSegment = '/public/media/';
    if (!fullUrl.contains(bucketPathSegment)) {
      throw Exception("Invalid storage URL format");
    }
    String relativePath = fullUrl.split(bucketPathSegment).last;
    final fileName = relativePath.split('/').last;
    final String newRelativePath = "$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName";

    await Supabase.instance.client.storage
        .from('media')
        .copy(relativePath, newRelativePath);

    return Supabase.instance.client.storage.from('media').getPublicUrl(newRelativePath);
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

        if (card['imgurl'] != null && card['imgurl'].toString().isNotEmpty) {
          try { newImgUrl = await _copyFile(card['imgurl'], 'images'); } catch (e) {}
        }
        if (card['videourl'] != null && card['videourl'].toString().isNotEmpty) {
          try { newVideoUrl = await _copyFile(card['videourl'], 'videos'); } catch (e) {}
        }

        await Supabase.instance.client.from('flashcard').insert({
          'lessonid': newLessonId,
          'signmeaning': card['signmeaning'],
          'imgurl': newImgUrl,
          'videourl': newVideoUrl,
        });
      }
      _showSnackBar("Lesson successfully imported!", Colors.green);
      _fetchLessons();
    } catch (e) {
      _showSnackBar("An error occurred during the import process.", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Dialogs & UI Helpers ---

  Future<void> _showCreateLessonDialog() async {
    final titleController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        titlePadding: EdgeInsets.zero,
        title: _buildDialogHeader("New Lesson for ${widget.className}"),
        content: _buildDialogTextField(titleController, "Lesson Title"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF1D5A71))),
          ),
          _buildPrimaryButton("Create", () async {
            if (titleController.text.isNotEmpty) {
              await _createNewLesson(titleController.text.trim());
              Navigator.pop(context);
            }
          }),
        ],
      ),
    );
  }

  Future<void> _showEditLessonDialog(Map<String, dynamic> lesson) async {
    final editController = TextEditingController(text: lesson['lessontitle']);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        titlePadding: EdgeInsets.zero,
        title: _buildDialogHeader("Edit Lesson Title", icon: Icons.edit),
        content: _buildDialogTextField(editController, "Lesson Title"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF1D5A71))),
          ),
          _buildPrimaryButton("Save Changes", () async {
            if (editController.text.isNotEmpty) {
              await _updateLessonTitle(lesson['lessonid'], editController.text.trim());
              Navigator.pop(context);
            }
          }),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmDialog(Map<String, dynamic> lesson) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        titlePadding: EdgeInsets.zero,
        title: _buildDialogHeader("Delete Lesson?", icon: Icons.warning_amber_rounded),
        content: Padding(
          padding: const EdgeInsets.only(top: 15.0),
          child: Text(
            "Are you sure you want to delete '${lesson['lessontitle']}'? This action cannot be undone.",
            style: const TextStyle(color: Color(0xFF1D5A71), fontSize: 16),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteLesson(lesson['lessonid']);
            },
            child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

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

  // --- UI Components ---

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

  Widget _buildDialogTextField(TextEditingController controller, String label) {
    return SizedBox(
      width: 500,
      child: TextField(
        controller: controller,
        cursorColor: const Color(0xFF1D5A71),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF1D5A71)),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0XFF7AA9CA))),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1D5A71), width: 2)),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 8),
                child: Text(
                  "${widget.className} - ${widget.gradeLevel}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1D5A71)),
                ),
              ),
              Expanded(
                child: _lessons.isEmpty && !_isLoading
                    ? _buildEmptyState()
                    : _buildLessonList(),
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
        if (_isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildLessonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      itemCount: _lessons.length,
      itemBuilder: (context, index) {
        final lesson = _lessons[index];
        return Card(
          color: const Color(0xFFA5CEEB),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.book, color: Color(0XFF1d5a71)),
            title: Text(lesson['lessontitle'], style: const TextStyle(color: Color(0xFF1D5A71), fontWeight: FontWeight.bold)),
            subtitle: const Text("Manage materials", style: TextStyle(color: Color(0xFF1D5A71))),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.white, size: 20), onPressed: () => _showEditLessonDialog(lesson)),
                IconButton(icon: const Icon(Icons.content_copy, color: Colors.white, size: 20), onPressed: () => _showImportDialog(lesson['lessonid'])),
                IconButton(icon: const Icon(Icons.quiz, color: Colors.white), onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(lessonId: lesson['lessonid'])));
                }),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _showDeleteConfirmDialog(lesson)),
              ],
            ),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => CreateFlashcardScreen(lessonId: lesson['lessonid'], lessontitle: lesson['lessontitle'])));
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("No lessons created yet!", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1D5A71))),
                SizedBox(height: 20),
                Text("Please wait...", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))),
                SizedBox(height: 5),
                Text("Updating your curriculum", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 100, left: MediaQuery.of(context).size.width * 0.1, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
    );
  }
}