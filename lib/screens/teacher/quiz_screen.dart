import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/serene_header.dart';
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
        .select('*, quizquestion(count)')
        .eq('lessonid', widget.lessonId)
        .maybeSingle();

    if (quiz != null) {
      _existingQuizId = quiz['quizid'];
      int totalQuestions = (quiz['quizquestion'] != null && quiz['quizquestion'].isNotEmpty)
          ? quiz['quizquestion'][0]['count'] ?? 1 
          : 1;

      setState(() {
        _maxAttempts = quiz['max_attempts'] ?? 3;
        _selectedPolicy = quiz['grading_policy'] ?? 'average';
      });

      final resultData = await supabase
          .from('quiz_results')
          .select('score, completed_at, profiles!inner(fullname)')
          .eq('quizid', _existingQuizId!)
          .order('completed_at', ascending: false);

      //GROUPING & ADAPTIVE CALCULATION LOGIC
      Map<String, List<Map<String, dynamic>>> grouped = {};
      
      for (var res in resultData) {
        final name = res['profiles']['fullname'] ?? "Unknown Student";
        
        //Will Calculate the percentage for this specific attempt
        double percentage = (res['score'] / totalQuestions) * 100;
        res['calculated_percent'] = percentage.clamp(0, 100).toInt();

        if (!grouped.containsKey(name)) grouped[name] = [];
        grouped[name]!.add(res);
      }

      setState(() {
        _studentResults = grouped.entries.map((e) {
          final attempts = e.value;
          double finalGrade = 0;

          //Apply Teacher's Grading Policy
          if (_selectedPolicy == 'highest') {
            finalGrade = attempts
                .map((a) => (a['calculated_percent'] as int).toDouble())
                .reduce((a, b) => a > b ? a : b);
          } 
          else if (_selectedPolicy == 'average') {
            double sum = attempts
                .map((a) => (a['calculated_percent'] as int).toDouble())
                .reduce((a, b) => a + b);
            finalGrade = sum / attempts.length;
          } 
          else {
            finalGrade = (attempts.first['calculated_percent'] as int).toDouble();
          }

          return {
            'name': e.key,
            'attempts': attempts,
            'display_grade': finalGrade.toInt(), 
          };
        }).toList();
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
    color: Color(0xFFD0EDF9),
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
                    const Text("Max Attempts", style: TextStyle(fontSize: 12, color: Color(0xFF1D5A71))),
                    DropdownButton<int>(
                      dropdownColor: Colors.white,
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
                    const Text("Grading Policy", style: TextStyle(fontSize: 12, color: Color(0xFF1D5A71))),
                    DropdownButton<String>(
                      dropdownColor: Colors.white,
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
      appBar: SereneHeader(scaffoldKey: _scaffoldkey, showBackButton: true),
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
            const Text("No quiz has been created for this lesson yet.", style: TextStyle(color: Colors.grey),),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFa5ceeb),
                foregroundColor: const Color(0xFF006064),
              ),
              icon: const Icon(Icons.auto_awesome, color: Color(0xFF1D5A71)),
              label: const Text("Generate Preview", style: TextStyle(color: Color(0xFF1D5A71)),),
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
                color: Color(0xFFD0EDF9),
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
                      style: const TextStyle(fontWeight: FontWeight.w600, color:  Color(0xFF1D5A71)),
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
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: _studentResults.length,
                  itemBuilder: (context, index) {
                    final studentEntry = _studentResults[index];
                    final List attempts = studentEntry['attempts'];
                    final latestScore = attempts.first['calculated_percent'];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ExpansionTile(
                        shape: const Border(),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1D5A71),
                          child: Text(studentEntry['name'][0], style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(
                          studentEntry['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)),
                        ),
                        subtitle: Text("${attempts.length} attempts recorded"), 
                        trailing: Text(
                              "${studentEntry['display_grade']}%", 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1D5A71)),
                            ),
                        children: [
                          const Divider(height: 1),
                          Container(
                            color: const Color(0xFF1D5A71).withOpacity(0.03),
                            child: Column(
                              children: attempts.map<Widget>((attempt) {
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.history, size: 18),
                                  title: Text("Completed: ${attempt['completed_at'].toString().substring(0, 16)}"),
                                  trailing: Text(
                                    "${attempt['calculated_percent']}%",
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
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
                        Icon(Icons.delete_forever, color: Color(0xFF1D5A71)),
                        SizedBox(width: 12),
                        Text(
                          "Delete Quiz?",
                          style: TextStyle(color: Color(0xFF1D5A71), fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  content: const Padding(
                    padding: EdgeInsets.only(top: 20.0),
                    child: Text(
                      "This will permanently remove the quiz and all student scores.",
                      style: TextStyle(color: Color(0xFF1D5A71), fontSize: 16)
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel", style: TextStyle(color: Color(0xFF1D5A71))),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(context, true), 
                      child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold))
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
              Icon(Icons.quiz, color: Color(0xFF1D5A71)),
              SizedBox(width: 12),
              Text(
                "Update Quiz Rules",
                style: TextStyle(color: Color(0xFF1D5A71), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  value: _maxAttempts,
                  onChanged: (val) => setDialogState(() => _maxAttempts = val!),
                  items: [1, 2, 3, 5, 10, 99].map((int value) {
                    return DropdownMenuItem<int>(value: value, child: Text("$value Attempts"));
                  }).toList(),
                ),
                DropdownButton<String>(
                  dropdownColor: Colors.white,
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF1D5A71))),
          ),
          ElevatedButton(
             style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
            child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}