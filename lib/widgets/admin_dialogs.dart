import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDirectoryDialog extends StatefulWidget {
  final String roletype;
  final int schoolId;

  const UserDirectoryDialog({required this.roletype, required this.schoolId});

  @override
  State<UserDirectoryDialog> createState() => _UserDirectoryDialogState();
}

class _UserDirectoryDialogState extends State<UserDirectoryDialog> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _allUsers.where((u) {
        final name = (u['fullname'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchUsers() async {
    try {
      final data = await supabase
          .from('profiles')
          .select('email, fullname, status')
          .eq('roletype', widget.roletype)
          .eq('schoolid', widget.schoolId)
          .order('fullname');

      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(data);
          _filtered = _allUsers;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.roletype} Directory',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D5A71),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF1D5A71)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              cursorColor: const Color(0xFF1D5A71),
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1D5A71)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF7AA9CA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1D5A71), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 6),
            const Divider(color: Color(0xFF1D5A71)),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1D5A71)),
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage'));
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? 'No records found.' : 'No results for "${_searchController.text}".',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFFD0EDF9)),
      itemBuilder: (_, index) {
        final user = _filtered[index];
        final String initial = (user['fullname']?.isNotEmpty == true)
            ? user['fullname'][0].toUpperCase()
            : (user['email']?.isNotEmpty == true ? user['email'][0].toUpperCase() : '?');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF1D5A71),
            child: Text(initial, style: const TextStyle(color: Colors.white)),
          ),
          title: Text(
            user['fullname'] ?? 'No Name Provided',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user['email'] ?? ''),
              Text(
                'Status: ${user['status'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }
}


class HighRiskNotesDialog extends StatefulWidget {
  final String studentId;
  final String studentName;
  final int? classId;
  final int? lessonId;
  final double score;

  const HighRiskNotesDialog({
    required this.studentId,
    required this.studentName,
    this.classId,
    this.lessonId,
    required this.score,
  });

  @override
  State<HighRiskNotesDialog> createState() => _HighRiskNotesDialogState();
}

class _HighRiskNotesDialogState extends State<HighRiskNotesDialog> {
  final supabase = Supabase.instance.client;  
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  Future<void> _fetchNotes() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      var query = supabase
          .from('student_notes')
          .select(
            'note_text, category, created_at, '
            'quiz_results:quiz_result_id!inner ( '
            '  quiz:quizid!inner ( lessonid, lesson:lessonid ( lessontitle ) ) '
            ')',
          )
          .eq('studentid', widget.studentId)
          .eq('quiz_results.quiz.lessonid', widget.lessonId!);
      if (widget.classId != null) query = query.eq('classid', widget.classId!);
      final data = await query.order('created_at', ascending: false);
      if (mounted) setState(() => _notes = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('High risk notes fetch error: $e');
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 580),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF1D5A71))),
                ),
              ),
            ),
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
        borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.studentName,
                    style: const TextStyle(color: Color(0xFF1D5A71), fontSize: 17, fontWeight: FontWeight.bold)),
                Text('Score: ${widget.score.toStringAsFixed(1)}% — High Risk',
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, color: Color(0xFF1D5A71)), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1D5A71))));
    if (_errorMessage != null) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Failed to load notes: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))));
    if (_notes.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.notes_outlined, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text('No teacher observations recorded for this lesson.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildNoteCard(_notes[i]),
    );
  }

 Widget _buildNoteCard(Map<String, dynamic> note) {
  final bool isQuiz = note['category'] == 'quiz_assessment';
  final String rawDate = note['created_at']?.toString() ?? '';
  final String date = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;

  // 1. Declare as a nullable String
  String? quizTitle;

  if (isQuiz) {
    // 2. Extract and cast each level individually
    final dynamic quizResultsRaw = note['quiz_results'];
    
    if (quizResultsRaw is Map) {
      final dynamic quizRaw = quizResultsRaw['quiz'];
      
      if (quizRaw is Map) {
        final dynamic lessonRaw = quizRaw['lesson'];
        
        if (lessonRaw is Map) {
          // 3. Final extraction with a forced String conversion
          quizTitle = lessonRaw['lessontitle']?.toString();
        }
      }
    }
  }

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isQuiz 
          ? const Color(0xFF1D5A71).withOpacity(0.05) 
          : const Color(0xFFD0EDF9).withOpacity(0.5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: isQuiz 
              ? const Color(0xFF1D5A71).withOpacity(0.2) 
              : const Color(0xFFD0EDF9)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(isQuiz ? Icons.quiz_outlined : Icons.person_outline, 
              size: 14, color: const Color(0xFF1D5A71)),
          const SizedBox(width: 6),
          Text(isQuiz ? 'Quiz Assessment' : 'General Observation',
              style: const TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF1D5A71))),
          const Spacer(),
          Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        if (isQuiz && quizTitle != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.book_outlined, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            // Added Expanded to prevent overflow if the title is too long
            Expanded(
              child: Text(
                quizTitle,
                style: const TextStyle(
                    fontSize: 11, 
                    color: Colors.grey, 
                    fontStyle: FontStyle.italic),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ],
        const SizedBox(height: 6),
        Text(note['note_text'] ?? '', 
            style: const TextStyle(fontSize: 13, color: Color(0xFF1D5A71))),
      ],
    ),
  );
}
}