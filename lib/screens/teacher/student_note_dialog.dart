import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentNoteDialog extends StatefulWidget {
  final String studentUuid;
  final String studentName;
  final int classId;
  final int? quizResultId;
  final String? quizTitle;

  const StudentNoteDialog({
    super.key,
    required this.studentUuid,
    required this.studentName,
    required this.classId,
    this.quizResultId,
    this.quizTitle,
  });

  bool get isQuizMode => quizResultId != null;

  @override
  State<StudentNoteDialog> createState() => _StudentNoteDialogState();
}

class _StudentNoteDialogState extends State<StudentNoteDialog> {
  final supabase = Supabase.instance.client;
  final _noteController = TextEditingController();

  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<int?> _getTeacherId() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final profile = await supabase
        .from('profiles')
        .select('userid')
        .eq('uid', uid)
        .single();
    final int profileUserId = profile['userid'] as int;
    final teacher = await supabase
        .from('teacher')
        .select('userid')
        .eq('userid', profileUserId)
        .single();
    return teacher['userid'] as int;
  }

  Future<void> _fetchNotes() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('student_notes')
          .select('''
            *,
            quiz_results:quiz_result_id (
              quizid,
              quiz:quizid (
                lessonid,
                lesson:lessonid ( lessontitle )
              )
            )
          ''')
          .eq('classid', widget.classId)
          .eq('studentid', widget.studentUuid)
          .order('created_at', ascending: false);

      if (mounted) setState(() => _notes = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('Error fetching notes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final teacherId = await _getTeacherId();
      if (teacherId == null) throw Exception('Could not resolve teacher ID');

      await supabase.from('student_notes').insert({
        'teacherid': teacherId,
        'studentid': widget.studentUuid,
        'classid': widget.classId,
        'note_text': text,
        'category': widget.isQuizMode ? 'quiz_assessment' : 'general',
        if (widget.isQuizMode) 'quiz_result_id': widget.quizResultId,
      });

      _noteController.clear();
      await _fetchNotes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save note: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildNoteInput(),
            const Divider(height: 1, color: Color(0xFFD0EDF9)),
            Expanded(child: _buildHistory()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
          const Icon(Icons.note_alt_outlined, color: Color(0xFF1D5A71)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isQuizMode ? 'Quiz Assessment' : 'Student Observation',
                  style: const TextStyle(
                    color: Color(0xFF1D5A71),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.studentName,
                  style: const TextStyle(color: Color(0xFF1D5A71), fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1D5A71)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isQuizMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1D5A71).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.quiz_outlined, size: 14, color: Color(0xFF1D5A71)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.quizTitle ?? 'Quiz Assessment',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1D5A71), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          TextField(
            controller: _noteController,
            maxLines: 3,
            cursorColor: const Color(0xFF1D5A71),
            decoration: InputDecoration(
              hintText: widget.isQuizMode
                  ? 'Write your assessment for this quiz attempt...'
                  : 'Write a general observation about this student...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF7AA9CA)),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF1D5A71), width: 2),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFa5ceeb),
                foregroundColor: const Color(0xFF1D5A71),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSaving ? null : _saveNote,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D5A71)),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save Note', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1D5A71)),
        ),
      );
    }
    if (_notes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu_outlined, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('No observations recorded yet.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildNoteCard(_notes[index]),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final bool isQuiz = note['category'] == 'quiz_assessment';
    final String rawDate = note['created_at']?.toString() ?? '';
    final String date = rawDate.length >= 16 ? rawDate.substring(0, 16).replaceAll('T', ' ') : rawDate;

    // Resolve quiz title from nested join: quiz_results → quiz → lesson
    String? resolvedQuizTitle;
    if (isQuiz) {
      final quizResult = note['quiz_results'];
      final quizData = quizResult?['quiz'];
      final lessonData = quizData?['lesson'];
      resolvedQuizTitle = lessonData?['lessontitle'] as String?;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isQuiz
            ? const Color(0xFF1D5A71).withOpacity(0.05)
            : const Color(0xFFD0EDF9).withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isQuiz ? const Color(0xFF1D5A71).withOpacity(0.2) : const Color(0xFFD0EDF9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isQuiz ? Icons.quiz_outlined : Icons.person_outline,
                size: 14,
                color: const Color(0xFF1D5A71),
              ),
              const SizedBox(width: 6),
              Text(
                isQuiz ? 'Quiz Assessment' : 'General Observation',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D5A71),
                ),
              ),
              const Spacer(),
              Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          if (isQuiz && resolvedQuizTitle != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.book_outlined, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  resolvedQuizTitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            note['note_text'] ?? '',
            style: const TextStyle(fontSize: 13, color: Color(0xFF1D5A71)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Color(0xFF1D5A71))),
        ),
      ),
    );
  }
}
