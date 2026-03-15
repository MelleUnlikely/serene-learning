import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LibraryDialog extends StatefulWidget {
  final int classId;
  final VoidCallback onImportSuccess;

  @visibleForTesting
  final List<Map<String, dynamic>>? initialLessons;

  const LibraryDialog({
    super.key,
    required this.classId,
    required this.onImportSuccess,
    this.initialLessons,
  });

  @visibleForTesting
  static Widget buildLessonListContent({
    required List<Map<String, dynamic>> lessons,
    bool isLoading = false,
    VoidCallback? onImport,
  }) {
    return ListView(
      shrinkWrap: true,
      children: lessons.map((lesson) => ListTile(
        leading: const Icon(Icons.book, color: Color(0xFF1D5A71)),
        title: Text(
          lesson['lessontitle'] ?? '',
          style: const TextStyle(color: Color(0xFF1D5A71), fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          lesson['visibility'] ?? '',
          style: const TextStyle(color: Color(0xFF1D5A71), fontSize: 12),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFa5ceeb),
            foregroundColor: const Color(0xFF1D5A71),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: isLoading ? null : onImport,
          child: const Text("Import", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      )).toList(),
    );
  }

  @override
  State<LibraryDialog> createState() => _LibraryDialogState();
}

class _LibraryDialogState extends State<LibraryDialog> {
  List<Map<String, dynamic>> _lessons = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialLessons != null) {
      _lessons = List<Map<String, dynamic>>.from(widget.initialLessons!);
    } else {
      _fetchLibraryLessons();
    }
  }

    Future<void> _fetchLibraryLessons() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final String userUuid = Supabase.instance.client.auth.currentUser!.id;

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('schoolid')
          .eq('uid', userUuid) 
          .single();

      final int userSchoolId = profileData['schoolid'] as int;
      
      final publicData = await Supabase.instance.client
          .from('lesson')
          .select('lessonid, lessontitle, visibility, classid')
          .eq('visibility', 'public');

      final classRows = await Supabase.instance.client
          .from('class_with_school')
          .select('classid')
          .eq('teacher_school_id', userSchoolId);
      final schoolClassIds = (classRows as List)
          .map((r) => r['classid'])
          .toList();

      final schoolData = schoolClassIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await Supabase.instance.client
              .from('lesson')
              .select('lessonid, lessontitle, visibility, classid')
              .eq('visibility', 'school')
              .inFilter('classid', schoolClassIds);

      final Map<int, Map<String, dynamic>> seen = {};
      for (final lesson in [...publicData, ...schoolData]) {
        final id = lesson['lessonid'] as int;
        seen[id] = lesson;
      }

      setState(() => _lessons = seen.values.toList());
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _importLesson(int lessonId) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.rpc(
        'duplicate_lesson_with_flashcards',
        params: {
          'target_lesson_id': lessonId,
          'target_class_id': widget.classId,
        },
      );
      widget.onImportSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to import lesson: $e",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Widget _buildLessonList() {
    return ListView(
      children: _lessons.map((lesson) => ListTile(
        leading: const Icon(Icons.book, color: Color(0xFF1D5A71)),
        title: Text(
          lesson['lessontitle'] ?? '',
          style: const TextStyle(color: Color(0xFF1D5A71), fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          lesson['visibility'] ?? '',
          style: const TextStyle(color: Color(0xFF1D5A71), fontSize: 12),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFa5ceeb),
            foregroundColor: const Color(0xFF1D5A71),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isLoading ? null : () => _importLesson(lesson['lessonid'] as int),
          child: const Text("Import", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      )).toList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            "No shared lessons available",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? "An error occurred",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF1D5A71)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFa5ceeb),
              foregroundColor: const Color(0xFF1D5A71),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => setState(() => _errorMessage = null),
            child: const Text("Dismiss", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1D5A71)),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _lessons.isEmpty) return _buildLoadingIndicator();
    if (_errorMessage != null) return _buildErrorState();
    if (_lessons.isEmpty) return _buildEmptyState();
    return _buildLessonList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFD0EDF9),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.library_books, color: Color(0xFF1D5A71)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Lesson Library",
                      style: TextStyle(
                        color: Color(0xFF1D5A71),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_isLoading && _lessons.isNotEmpty)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1D5A71)),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF1D5A71)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(child: _buildBody()),
            // Footer close button
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(color: Color(0xFF1D5A71))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
