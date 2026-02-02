import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/widgets/serene_menu.dart';

class QuizScreen extends StatefulWidget {
  final int lessonId;
  const QuizScreen({super.key, required this.lessonId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  bool _isGenerating = false;
  int? _existingQuizId;
  
  int _maxAttempts = 3; 
  String _selectedPolicy = 'average';
  final List<String> _policies = ['average', 'highest', 'latest'];

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

        setState(() {
          _maxAttempts = quiz['max_attempts'] ?? 3;
          _selectedPolicy = quiz['grading_policy'] ?? 'average';
        });

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

  Widget _buildQuizSettings() {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFF1D5A71), width: 1),
      borderRadius: BorderRadius.circular(12),
    ),
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_suggest, color: Color(0xFF1D5A71)),
              SizedBox(width: 8),
              Text(
                "Quiz Configuration",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1D5A71)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Dynamic Attempt Selection
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Max Attempts", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    DropdownButton<int>(
                      isExpanded: true,
                      value: _maxAttempts,
                      items: [1, 2, 3, 5, 10, 99].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value, 
                          child: Text(value == 99 ? "Unlimited" : "$value Attempts")
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _maxAttempts = val!),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Dynamic Policy Selection
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Grading Policy", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedPolicy,
                      items: _policies.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value[0].toUpperCase() + value.substring(1)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedPolicy = val!),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
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
    // This uses the exact _maxAttempts and _selectedPolicy from the UI state
    final quizRecord = await supabase.from('quiz').insert({
      'lessonid': widget.lessonId,
      'dategenerated': DateTime.now().toIso8601String(),
      'max_attempts': _maxAttempts,     // Teacher's Choice
      'grading_policy': _selectedPolicy, // Teacher's Choice
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
    
    _showSnackBar("Quiz Published! Policy: $_selectedPolicy", Colors.green);
    await _loadInitialData(); 
    
  } catch (e) {
    debugPrint("❌ Save Error: $e");
    _showSnackBar("Failed to publish quiz settings.", Colors.red);
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

      body: _isLoading 
      ? const Center(child: CircularProgressIndicator())
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text(
                _existingQuizId == null ? "Generate Quiz" : "Manage Quiz",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D5A71),
                ),
              ),
            ),
            Expanded(
              child: _existingQuizId == null 
                ? _buildGenerateView() 
                : _buildManageView(),
            ),
          ],
        ),
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
                   if (data.isEmpty) {
                     _showSnackBar("Add flashcards to this lesson first!", Colors.orange);
                   } else {
                     setState(() {
                       _allFlashcardsFromDB = data;
                       _tempQuizData = generateAutoQuiz(data, data.length);
                     });
                   }
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
        _buildQuizSettings(), 
        Expanded(
          child: ListView.builder(
            itemCount: _tempQuizData.length,
            itemBuilder: (context, index) {
              final q = _tempQuizData[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(title: Text("Question ${index + 1}: ${q['meaning']}")),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: q['choices'].map<Widget>((url) => Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.network(url, width: 40, height: 40, fit: BoxFit.cover),
                      )).toList(),
                    ),
                    const SizedBox(height: 8),
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
        color: const Color(0xFF1D5A71).withOpacity(0.1),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: Color(0xFF1D5A71)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Current Policy: ${_selectedPolicy.toUpperCase()}\nMax Attempts: ${_maxAttempts == 99 ? 'Unlimited' : _maxAttempts}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF1D5A71)),
                  onPressed: () => _showUpdateSettingsDialog(),
                  tooltip: "Change Quiz Rules",
                )
              ],
            ),
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
                  final profile = res['profiles'];
                  final name = profile != null ? profile['fullname'] : "Unknown Student";
                  return ListTile(
                    title: Text(name),
                    subtitle: Text("Completed: ${res['completed_at'].toString().substring(0, 10)}"),
                    trailing: Text("${res['score']}%", 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1D5A71))),
                  );
                },
              ),
      ),

      const Divider(thickness: 1, color: Color(0xFF1D5A71)),
      
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

void _showUpdateSettingsDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Update Quiz Rules"),
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                isExpanded: true,
                value: _maxAttempts,
                onChanged: (val) => setDialogState(() => _maxAttempts = val!),
                items: [1, 2, 3, 5, 10, 99].map((int value) {
                  return DropdownMenuItem<int>(value: value, child: Text("$value Attempts"));
                }).toList(),
              ),
              DropdownButton<String>(
                isExpanded: true,
                value: _selectedPolicy,
                onChanged: (val) => setDialogState(() => _selectedPolicy = val!),
                items: _policies.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase()));
                }).toList(),
              ),
            ],
          );
        }
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            try {
              await supabase.from('quiz').update({
                'max_attempts': _maxAttempts,
                'grading_policy': _selectedPolicy,
              }).eq('quizid', _existingQuizId!);
              Navigator.pop(context);
              setState(() {});
              _showSnackBar("Settings updated!", Colors.green);
            } catch (e) {
              _showSnackBar("Update failed", Colors.red);
            }
          },
          child: const Text("Save Changes"),
        )
      ],
    ),
  );
}
}