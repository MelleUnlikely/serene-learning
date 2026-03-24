import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../teacher/create_flashcard_screen.dart';
import '../teacher/library_dialog.dart';
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

  //Data Logic

  Future<void> _fetchLessons() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('lesson')
          .select('lessonid, lessontitle, visibility')
          .eq('classid', widget.classId)
          .order('created_at');
      setState(() => _lessons = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      _showSnackBar("Error loading lessons: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewLesson(String title, String visibility) async {
    try {
      await Supabase.instance.client.from('lesson').insert({
        'classid': widget.classId,
        'lessontitle': title,
        'visibility': visibility,
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

  Future<void> _updateLessonSettings(int lessonId, String newTitle, String newVisibility) async {
    try {
      await Supabase.instance.client
          .from('lesson')
          .update({'lessontitle': newTitle, 'visibility': newVisibility}).eq('lessonid', lessonId);
      _fetchLessons();
      _showSnackBar("Lesson updated successfully", Colors.green);
    } catch (e) {
      _showSnackBar("Failed to update lesson: $e", Colors.red);
    }
  }

  //Dialogs & UI Helpers
  void _showLibraryDialog() {
    showDialog(
      context: context,
      builder: (context) => LibraryDialog(
        classId: widget.classId,
        onImportSuccess: () {
          Navigator.pop(context);
          _showSuccessSnackBar();
          _fetchLessons();
        },
      ),
    );
  }

  void _showSuccessSnackBar() {
    _showSnackBar("Lesson imported successfully", Colors.green);
  }

  Future<void> _showCreateLessonDialog() async {
    final titleController = TextEditingController();
    String selectedVisibility = 'private';
    const visibilityOptions = {
      'Private': 'private',
      'School': 'school',
      'Share with everyone': 'public',
    };
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          titlePadding: EdgeInsets.zero,
          title: _buildDialogHeader("New Lesson for ${widget.className}"),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(titleController, "Lesson Title"),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedVisibility,
                  decoration: const InputDecoration(
                    labelText: "Visibility",
                    labelStyle: TextStyle(color: Color(0xFF1D5A71)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0XFF7AA9CA))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1D5A71), width: 2)),
                  ),
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Color(0xFF1D5A71)),
                  items: visibilityOptions.entries
                      .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedVisibility = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF1D5A71))),
            ),
            _buildPrimaryButton("Create", () async {
              if (titleController.text.isNotEmpty) {
                await _createNewLesson(titleController.text.trim(), selectedVisibility);
                Navigator.pop(context);
              }
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditLessonDialog(Map<String, dynamic> lesson) async {
    final editController = TextEditingController(text: lesson['lessontitle']);
    String selectedVisibility = lesson['visibility'] ?? 'private';
    const visibilityOptions = {
      'Private': 'private',
      'School': 'school',
      'Share with everyone': 'public',
    };
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          titlePadding: EdgeInsets.zero,
          title: _buildDialogHeader("Edit Lesson", icon: Icons.edit),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(editController, "Lesson Title"),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: visibilityOptions.containsValue(selectedVisibility)
                      ? selectedVisibility
                      : 'private',
                  decoration: const InputDecoration(
                    labelText: "Visibility",
                    labelStyle: TextStyle(color: Color(0xFF1D5A71)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0XFF7AA9CA))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1D5A71), width: 2)),
                  ),
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Color(0xFF1D5A71)),
                  items: visibilityOptions.entries
                      .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedVisibility = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF1D5A71))),
            ),
            _buildPrimaryButton("Save Changes", () async {
              if (editController.text.isNotEmpty) {
                await _updateLessonSettings(
                  lesson['lessonid'],
                  editController.text.trim(),
                  selectedVisibility,
                );
                Navigator.pop(context);
              }
            }),
          ],
        ),
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

  //UI Components
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

  Widget _buildActionSegment({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isLast = false,
  }) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 50,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
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
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'library',
                onPressed: _showLibraryDialog,
                label: const Text("Add from Library", style: TextStyle(color: Color(0xFF1D5A71))),
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1D5A71)),
                backgroundColor: const Color(0xFFa5ceeb),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'addLesson',
                onPressed: _showCreateLessonDialog,
                label: const Text("Add Lesson", style: TextStyle(color: Color(0xFF1D5A71))),
                icon: const Icon(Icons.add, color: Color(0xFF1D5A71)),
                backgroundColor: const Color(0xFFa5ceeb),
              ),
            ],
          ),
        ),
        if (_isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildLessonList() {
    return ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    itemCount: _lessons.length,
    itemBuilder: (context, index) {
      final lesson = _lessons[index];
      return Card(
        color: const Color(0xFFA5CEEB),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => CreateFlashcardScreen(
                          lessonId: lesson['lessonid'], 
                          lessontitle: lesson['lessontitle']
                        )
                      )
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.book, color: Color(0XFF1d5a71)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lesson['lessontitle'], 
                                style: const TextStyle(color: Color(0xFF1D5A71), fontWeight: FontWeight.bold)),
                              const Text("Manage materials", 
                                style: TextStyle(color: Color(0xFF1D5A71), fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
                
                _buildActionSegment(
                  icon: Icons.edit,
                  color: const Color(0xFF7F9BBC).withOpacity(0.6),
                  onPressed: () => _showEditLessonDialog(lesson),
                ),
                _buildActionSegment(
                  icon: Icons.quiz,
                  color: const Color(0xFF7F9BBC),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(lessonId: lesson['lessonid'], classId: widget.classId, quizTitle: lesson['lessontitle'] ?? ''))),
                ),
                _buildActionSegment(
                  icon: Icons.delete,
                  color: const Color(0xFFDC6460),
                  isLast: true, 
                  onPressed: () => _showDeleteConfirmDialog(lesson),
                ),
              ],
            ),
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