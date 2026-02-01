import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizScreen extends StatefulWidget {
  final int lessonId;
  const QuizScreen({super.key, required this.lessonId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isGenerating = false;
  int? _existingQuizId;
  List<Map<String, dynamic>> _studentResults = [];
  List<Map<String, dynamic>> _tempQuizData = [];
  List<dynamic> _allFlashcardsFromDB = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final quiz = await supabase
          .from('quiz')
          .select()
          .eq('lessonid', widget.lessonId)
          .maybeSingle();

      if (quiz != null) {
        _existingQuizId = quiz['quizid'];

        // Updated: Join with 'profiles' using 'fullname' 
        // Ensure 'studentid' is the FK in quiz_results pointing to profiles(uid)
        final resultData = await supabase
            .from('quiz_results')
            .select('score, completed_at, profiles!inner(fullname)') 
            .eq('quizid', _existingQuizId!)
            .order('completed_at', ascending: false);

        setState(() {
          _studentResults = List<Map<String, dynamic>>.from(resultData);
        });
      } else {
        setState(() {
          _existingQuizId = null;
          _tempQuizData = [];
        });
      }
    } catch (e) {
      debugPrint("❌ Load Error: $e");
      _showSnackBar("Could not load quiz details", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> generateAutoQuiz(List<dynamic> flashcards, int numItems) {
    List<dynamic> copy = List.from(flashcards);
    copy.shuffle();
    final selected = copy.take(numItems).toList();

    return selected.map((flashcard) {
      String correctImage = flashcard['imgurl'] ?? "";
      List<dynamic> others = flashcards.where((f) => f['flashcardid'] != flashcard['flashcardid']).toList();
      others.shuffle();
      
      List<String> choices = [
        correctImage,
        ...others.take(3).map((f) => f['imgurl'].toString())
      ];
      choices.shuffle();

      return {
        'flashcardid': flashcard['flashcardid'],
        'video_url': flashcard['videourl'],
        'meaning': flashcard['signmeaning'],
        'choices': choices,
        'answer': correctImage,
      };
    }).toList();
  }

Future<void> _saveGeneratedQuiz(List<Map<String, dynamic>> quizData) async {
    setState(() => _isGenerating = true);
    try {
      final quizRecord = await supabase.from('quiz').insert({
        'lessonid': widget.lessonId,
        'dategenerated': DateTime.now().toIso8601String(),
      }).select().single();

      final int quizId = quizRecord['quizid'];

      for (var item in quizData) {
        final qRecord = await supabase.from('quizquestion').insert({
          'quizid': quizId,
          'flashcardid': item['flashcardid'],
        }).select().single();

        final choices = item['choices'].map((url) => {
          'questionid': qRecord['questionid'],
          'choicetext': url,
          'iscorrect': url == item['answer'],
        }).toList();

        await supabase.from('questionchoice').insert(choices);
      }
      
      _showSnackBar("Quiz Published!", Colors.green);
      
      await _loadInitialData(); 
      
    } catch (e) {
      debugPrint("❌ Save Error: $e");
      _showSnackBar("Error: A quiz might already exist for this lesson.", Colors.red);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(_existingQuizId == null ? "Generate Quiz" : "Manage Quiz")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _existingQuizId == null 
            ? _buildGenerateView() 
            : _buildManageView(),
    );
  }

  Widget _buildGenerateView() {
    if (_tempQuizData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("No quiz has been created for this lesson yet."),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Generate Preview"),
              onPressed: () async {
                setState(() => _isLoading = true);
                try {
                  final data = await supabase.from('flashcard').select().eq('lessonid', widget.lessonId);
                  debugPrint("Fetched ${data.length} flashcards.");

                  if (data.isEmpty) {
                    _showSnackBar("Add flashcards to this lesson first!", Colors.orange);
                  } else {
                    setState(() {
                      _allFlashcardsFromDB = data;
                      _tempQuizData = generateAutoQuiz(data, data.length);
                    });
                  }
                } catch (e) {
                  _showSnackBar("Error fetching cards: $e", Colors.red);
                } finally {
                  setState(() => _isLoading = false);
                }
              },
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _tempQuizData.length,
            itemBuilder: (context, index) {
              final q = _tempQuizData[index];
              return Card(
                margin: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    ListTile(title: Text("Question ${index + 1}: ${q['meaning']}")),
                    const Icon(Icons.play_circle_fill, size: 40, color: Colors.blue),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: q['choices'].map<Widget>((url) => Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Container(
                          decoration: BoxDecoration(border: Border.all(color: url == q['answer'] ? Colors.green : Colors.grey)),
                          child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: _isGenerating ? null : () => _saveGeneratedQuiz(_tempQuizData),
              child: _isGenerating ? const CircularProgressIndicator(color: Colors.white) : const Text("Confirm & Publish Quiz"),
            ),
          ),
        )
      ],
    );
  }

Widget _buildManageView() {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.blue.withOpacity(0.1),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text("Students can see this quiz. Below are their current scores.")),
          ],
        ),
      ),
      Expanded(
        child: _studentResults.isEmpty
          ? const Center(child: Text("No students have taken this quiz yet."))
          : ListView.builder(
              itemCount: _studentResults.length,
              itemBuilder: (context, index) {
                final res = _studentResults[index];
                // Updated: Match the 'fullname' column name
                final profile = res['profiles'];
                final name = profile != null ? profile['fullname'] : "Unknown Student";
                
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?"),
                  ),
                  title: Text(name),
                  subtitle: Text("Completed: ${res['completed_at'].toString().substring(0, 10)}"),
                  trailing: Text(
                    "${res['score']}%", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)
                  ),
                );
              },
            ),
      ),
      const Divider(),
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: TextButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Delete Quiz?"),
                content: const Text("This will permanently remove the quiz and all student scores."),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true), 
                    child: const Text("Delete", style: TextStyle(color: Colors.red))
                  ),
                ],
              ),
            );

            if (confirm == true) {
              try {
                await supabase.from('quiz').delete().eq('quizid', _existingQuizId!);
                _loadInitialData(); 
              } catch (e) {
                _showSnackBar("Delete failed: $e", Colors.red);
              }
            }
          },
          icon: const Icon(Icons.delete_forever, color: Colors.red),
          label: const Text("Delete Quiz & Reset Scores", style: TextStyle(color: Colors.red)),
        ),
      )
    ],
  );
}

}