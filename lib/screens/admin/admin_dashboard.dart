import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_application_1/widgets/serene_menu.dart';
import 'package:flutter_application_1/widgets/serene_header.dart';
import 'package:flutter_application_1/widgets/admin_dialogs.dart';

enum DashboardView { school, classDetail, lessonDetail }

class AdminDashboard extends StatefulWidget {
  final int schoolId;
  const AdminDashboard({super.key, required this.schoolId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

double _calculatePolicyScore(List<dynamic> attempts, String policy) {
  if (attempts.isEmpty) return 0.0;

  Map<String, List<double>> studentScores = {};
  Map<String, DateTime> latestDates = {};
  Map<String, double> latestScores = {};

  for (var record in attempts) {
    String sId = record['studentid'].toString();
    double score = (record['final_score'] as num? ?? 0).toDouble();
    DateTime date = DateTime.parse(record['created_at'] ?? DateTime.now().toString());

    studentScores.putIfAbsent(sId, () => []).add(score);

    if (!latestDates.containsKey(sId) || date.isAfter(latestDates[sId]!)) {
      latestDates[sId] = date;
      latestScores[sId] = score;
    }
  }

  List<double> finalGrades = [];
  studentScores.forEach((sId, scores) {
    switch (policy.toLowerCase()) {
      case 'average':
        finalGrades.add(scores.reduce((a, b) => a + b) / scores.length);
        break;
      case 'latest':
        finalGrades.add(latestScores[sId]!);
        break;
      case 'highest':
      default:
        finalGrades.add(scores.reduce((a, b) => a > b ? a : b));
        break;
    }
  });

  return finalGrades.reduce((a, b) => a + b) / finalGrades.length;
}

Color _scoreColor(double score) {
  if (score < 60) return Colors.red;
  if (score < 71) return Colors.orange;
  if (score < 81) return Colors.yellow.shade700;
  if (score < 91) return Colors.lightGreen;
  return const Color(0xFF1B5E20);
}

class ReportData {
  final String className;
  final double classAverage;
  final List<LessonReport>? lessons; 

  ReportData({required this.className, required this.classAverage, this.lessons});
}

class LessonReport {
  final String lessonTitle;
  final double lessonAverage;
  final List<StudentReport>? students; 

  LessonReport({required this.lessonTitle, required this.lessonAverage, this.students});
}

class StudentReport {
  final String studentName;
  final double score;

  StudentReport({required this.studentName, required this.score});
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool isGenerating = false;
  bool isLoading = true;
  DashboardView _currentView = DashboardView.school;
  
  int studentCount = 0;
  int teacherCount = 0;
  String schoolName = "Loading...";
  List<BarChartGroupData> graphData = [];
  List<String> labels = [];
  List<String> tooltipExtras = [];
  List<dynamic> _currentRawData = [];
  Map<int, Map<String, dynamic>> _schoolBarMeta = {}; // index -> {classname, classid (first year's)}

  // Multi-year comparison (school view only)
  List<String> _availableYears = [];
  List<String> _selectedYears = [];
  static const List<Color> _yearColors = [
    Color(0xFF1D5A71),
    Color(0xFF64B5F6),
    Color(0xFFB0BEC5),
  ];

  // Teacher filter (school view only)
  List<Map<String, dynamic>> _availableTeachers = [];
  List<int> _selectedTeacherIds = [];
  
  int? _selectedId;
  int? _parentClassId;
  String _parentClassTitle = '';
  String _currentTitle = "School Overview";

  bool includeLessons = false;
  bool includeStudents = false;

  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _selectedYears = [_getCurrentAY()];
    _initializeDashboard();
  }

  String _getCurrentAY() {
    final now = DateTime.now();
    final year = now.month >= 8 ? now.year : now.year - 1;
    return '$year-${year + 1}';
  }
  void _showProgressReport() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  SizedBox(width: 12),
                  Text(
                    "School Progress Report",
                    style: TextStyle(color: Color(0xFF1D5A71), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            content: Container(
              width: 500,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text("Include Lessons"),
                    value: includeLessons,
                    onChanged: (val) => setDialogState(() => includeLessons = val!),
                  ),
                  CheckboxListTile(
                    title: const Text("Include Students"),
                    value: includeStudents,
                    enabled: includeLessons,
                    onChanged: (val) => setDialogState(() => includeStudents = val!),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFa5ceeb),
                      foregroundColor: const Color(0xFF006064),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(200, 45),
                    ),
                    onPressed: isGenerating ? null : () async {
                    setDialogState(() => isGenerating = true);
                    try {
                      await generateDetailedReport(); 
                    } catch (e) {
                      debugPrint("Export Error: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to generate report: $e")),
                      );
                    } finally {
                      if (mounted) setDialogState(() => isGenerating = false);
                    }
                  },
                    icon: isGenerating 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.description),
                    label: Text(isGenerating ? "Processing..." : "Generate Detailed Report", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _fetchSchoolName() async {
    try {
      final res = await Supabase.instance.client
          .from('schools')
          .select('schoolname')
          .eq('schoolid', widget.schoolId)
          .single();
      if (mounted) setState(() => schoolName = res['schoolname'] ?? "Unknown School");
    } catch (e) {
      debugPrint("School Name Error: $e");
    }
  }

  Future<void> _initializeDashboard() async {
    try {
      await _fetchFilterOptions();
      await Future.wait([
        _fetchSchoolName(),
        _fetchCounts(),
        _fetchGraphData(),
      ]);
    } catch (e) {
      debugPrint("Dashboard Init Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchFilterOptions() async {
    await Future.wait([_fetchAvailableYears(), _fetchAvailableTeachers()]);
  }

Future<void> _fetchAvailableYears() async {
    try {
      final data = await Supabase.instance.client
          .from('classes_with_ay')
          .select('school_year')
          .eq('schoolid', widget.schoolId);

      final years = data
          .map((r) => r['school_year']?.toString() ?? '')
          .where((y) => y.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a)); // descending

      if (mounted) {
        setState(() {
          _availableYears = years;
          if (years.isNotEmpty) {
            final currentAY = _getCurrentAY();
            // Keep current selection if it exists in DB, otherwise fallback to most recent
            final validSelected = _selectedYears.where((y) => years.contains(y)).toList();
            if (validSelected.isNotEmpty) {
              _selectedYears = validSelected;
            } else {
              // Current AY not in DB — fallback to most recent
              _selectedYears = [years.first];
              debugPrint("AY $currentAY not found in DB, falling back to ${years.first}");
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Fetch Years Error: $e");
    }
  }

  Future<void> _fetchAvailableTeachers() async {
    try {
      // Get distinct teacherids for this school from classes_with_ay
      final data = await Supabase.instance.client
          .from('classes_with_ay')
          .select('teacherid')
          .eq('schoolid', widget.schoolId);

      final teacherIds = data
          .map((r) => r['teacherid'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (teacherIds.isEmpty) return;

      // Fetch fullnames from profiles
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('userid, fullname')
          .inFilter('userid', teacherIds);

      final teachers = profiles
          .map((p) => {
            'teacherid': p['userid'],
            'fullname': p['fullname']?.toString() ?? 'Unknown',
          })
          .toList()
        ..sort((a, b) => (a['fullname'] as String).compareTo(b['fullname'] as String));

      if (mounted) {
        setState(() {
          _availableTeachers = List<Map<String, dynamic>>.from(teachers);
          // Default: all teachers selected
          _selectedTeacherIds = _availableTeachers
              .map((t) => t['teacherid'] as int)
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Fetch Teachers Error: $e");
    }
  }

  Future<void> generateDetailedReport() async {
    final client = Supabase.instance.client;
    
    final classData = await client
        .from('class_performance_stats')
        .select()
        .eq('schoolid', widget.schoolId);

    if (classData.isEmpty) throw "No class data found for this school.";

    final pdf = pw.Document();
    List<pw.Widget> reportContent = [
      pw.Header(
        level: 0, 
        child: pw.Text("School Performance Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))
      ),
      pw.Text("Generated: ${DateTime.now().toLocal()}"),
      pw.SizedBox(height: 20),
    ];

    for (var classItem in classData) {
      List<double> lessonAveragesForClass = [];

      if (includeLessons) {
        final lessonData = await client
            .from('lesson_performance_stats')
            .select()
            .eq('classid', classItem['classid']);

        List<pw.Widget> lessonWidgets = [];

        for (var lesson in lessonData) {
          final studentData = await client
              .from('student_lesson_stats')
              .select()
              .eq('lessonid', lesson['lessonid']);

          double lessonAccuracy = 0;
          List<List<String>> studentRows = [];

          if (studentData.isNotEmpty) {
            String policy = (lesson['grading_policy'] ?? 'highest').toString().toLowerCase();
            
            Map<String, List<double>> studentMap = {};
            Map<String, String> studentNames = {};
            Map<String, DateTime> latestDates = {};
            Map<String, double> latestScores = {};

            for (var s in studentData) {
              String id = s['studentid'].toString();
              double score = (s['final_score'] as num? ?? 0).toDouble();
              DateTime date = DateTime.parse(s['created_at'] ?? DateTime.now().toString());
              
              studentNames[id] = s['fullname'] ?? 'N/A';
              studentMap.putIfAbsent(id, () => []).add(score);
              
              if (!latestDates.containsKey(id) || date.isAfter(latestDates[id]!)) {
                latestDates[id] = date;
                latestScores[id] = score;
              }
            }

            List<double> finalGrades = [];
            studentMap.forEach((id, scores) {
              double finalGrade;
              if (policy == 'average') {
                finalGrade = scores.reduce((a, b) => a + b) / scores.length;
              } else if (policy == 'latest') {
                finalGrade = latestScores[id]!;
              } else { 
                finalGrade = scores.reduce((a, b) => a > b ? a : b);
              }
              finalGrades.add(finalGrade);
              studentRows.add([studentNames[id]!, "${finalGrade.toStringAsFixed(1)}%"]);
            });

            lessonAccuracy = finalGrades.reduce((a, b) => a + b) / finalGrades.length;
            lessonAveragesForClass.add(lessonAccuracy);
          }

          lessonWidgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                "Lesson: ${lesson['lessontitle']} (${lessonAccuracy.toStringAsFixed(1)}%) - Policy: ${lesson['grading_policy'] ?? 'Highest'}",
                style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
              ),
            )
          );

          if (includeStudents && studentRows.isNotEmpty) {
            lessonWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 40, top: 5),
                child: pw.TableHelper.fromTextArray(
                  border: null,
                  headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  headers: ['Student', 'Final Grade'],
                  data: studentRows,
                ),
              )
            );
          }
        }

        double classAvg = lessonAveragesForClass.isNotEmpty 
            ? lessonAveragesForClass.reduce((a, b) => a + b) / lessonAveragesForClass.length 
            : (classItem['average_accuracy'] as num? ?? 0).toDouble();

        reportContent.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(5),
            color: PdfColors.grey200,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Class: ${classItem['classname']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Corrected Avg: ${classAvg.toStringAsFixed(1)}%"),
              ],
            ),
          )
        );
        
        reportContent.addAll(lessonWidgets);
      }
      
      reportContent.add(pw.SizedBox(height: 15));
      reportContent.add(pw.Divider(thickness: 0.5, color: PdfColors.grey400));
    }

    pdf.addPage(pw.MultiPage(build: (context) => reportContent));
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

    
    Future<void> _fetchCounts() async {
      try {
        final studentRes = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('roletype', 'Student')
            .eq('schoolid', widget.schoolId) 
            .count(CountOption.exact);

        final teacherRes = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('roletype', 'Teacher')
            .eq('schoolid', widget.schoolId) 
            .count(CountOption.exact);

        if (mounted) {  
          setState(() {
            studentCount = studentRes.count;
            teacherCount = teacherRes.count;
          });
        }
      } catch (e) {
        debugPrint("Supabase Stats Error: $e");
      }
    }

  Future<void> _fetchGraphData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final client = Supabase.instance.client;
      List<dynamic> fetchedData = [];

      switch (_currentView) {
        case DashboardView.school:
          if (_selectedYears.isEmpty) {
            fetchedData = [];
          } else {
            var query = client
                .from('classes_with_ay')
                .select('teacherid, classname, school_year')
                .eq('schoolid', widget.schoolId)
                .inFilter('school_year', _selectedYears);
            if (_selectedTeacherIds.isNotEmpty) {
              query = query.inFilter('teacherid', _selectedTeacherIds);
            }
            fetchedData = await query;
          }
          break;
        case DashboardView.classDetail:
          fetchedData = await client.from('lesson_performance_stats').select().eq('classid', _selectedId!);
          break;
        case DashboardView.lessonDetail:
          fetchedData = await client.from('student_lesson_stats').select().eq('lessonid', _selectedId!);
          break;
      }

      await _processGraphPoints(fetchedData);

      if (mounted) {
        setState(() {
          _currentRawData = fetchedData;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Data Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _processGraphPoints(List<dynamic> fetchedData) async {
    List<String> newLabels = [];
    List<String> newTooltipExtras = [];
    List<BarChartGroupData> newGraphData = [];

    if (_currentView == DashboardView.school) {
      _schoolBarMeta = {};
      final client = Supabase.instance.client;

      // Group rows by classname, track which years exist for each class
      // fetchedData rows: { teacherid, classname, school_year }
      final Map<String, Set<String>> classnameYears = {};
      for (final row in fetchedData) {
        final name = row['classname']?.toString() ?? '';
        final year = row['school_year']?.toString() ?? '';
        if (name.isEmpty || year.isEmpty) continue;
        classnameYears.putIfAbsent(name, () => {}).add(year);
      }

      // Resolve classid for each classname from class_performance_stats
      final Map<String, int> classnameToId = {};
      final perfStats = await client
          .from('class_performance_stats')
          .select('classid, classname')
          .eq('schoolid', widget.schoolId);
      for (final row in perfStats) {
        final name = row['classname']?.toString() ?? '';
        final cid = row['classid'] as int?;
        if (name.isNotEmpty && cid != null) classnameToId[name] = cid;
      }

      final sortedNames = classnameYears.keys.toList()..sort();

      for (int i = 0; i < sortedNames.length; i++) {
        final name = sortedNames[i];
        final yearsForClass = classnameYears[name]!;
        final cid = classnameToId[name];
        List<BarChartRodData> rods = [];

        for (int yi = 0; yi < _selectedYears.length; yi++) {
          final year = _selectedYears[yi];
          double score = 0.0;
          // Only fetch score if this class exists for this year
          if (yearsForClass.contains(year) && cid != null) {
            final stats = await client
                .from('class_performance_stats')
                .select('average_accuracy')
                .eq('classid', cid)
                .maybeSingle();
            score = (stats?['average_accuracy'] as num? ?? 0.0).toDouble();
          }
          rods.add(BarChartRodData(
            toY: score,
            color: _yearColors[yi % _yearColors.length],
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ));
        }

        newLabels.add(name);
        _schoolBarMeta[i] = {'classname': name, 'classid': cid};
        newTooltipExtras.add('');
        newGraphData.add(BarChartGroupData(
          x: i,
          groupVertically: false,
          barsSpace: 1,
          barRods: rods,
        ));
      }
    } else {
      for (int i = 0; i < fetchedData.length; i++) {
        final item = fetchedData[i];
        double score = 0.0;
        String label = "";

        if (_currentView == DashboardView.classDetail) {
          label = item['lessontitle']?.toString() ?? '';
          final attempts = await Supabase.instance.client
              .from('student_lesson_stats')
              .select()
              .eq('lessonid', item['lessonid']);
          final String policy = (item['grading_policy'] ?? 'highest').toString();
          score = _calculatePolicyScore(attempts, policy);
          newTooltipExtras.add('Policy: ${policy[0].toUpperCase()}${policy.substring(1)}');
        } else if (_currentView == DashboardView.lessonDetail) {
          label = item['fullname']?.toString() ?? '';
          score = (item['final_score'] as num? ?? 0.0).toDouble();
          newTooltipExtras.add('');
        }

        newLabels.add(label);
        newGraphData.add(BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: score,
              color: _scoreColor(score),
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            )
          ],
        ));
      }
    }

    if (mounted) {
      setState(() {
        labels = newLabels;
        graphData = newGraphData;
        tooltipExtras = newTooltipExtras;
      });
    }
  }
  
  void _handleNavigation(int index) {
    if (index < 0) return;

    setState(() {
      if (_currentView == DashboardView.school) {
        // Step 1: School Overview -> Class Detail
        final meta = _schoolBarMeta[index];
        if (meta != null) {
          _currentView = DashboardView.classDetail;
          _selectedId = meta['classid'] as int?;
          _currentTitle = "Class: ${meta['classname']}";
        }
      } else if (_currentView == DashboardView.classDetail) {
        // Step 2: Class Detail -> Lesson Detail
        if (index < _currentRawData.length) {
          final item = _currentRawData[index];
          _parentClassId = _selectedId; // Store parent for back button
          _parentClassTitle = _currentTitle;
          _currentView = DashboardView.lessonDetail;
          _selectedId = item['lessonid']; // Fetching lessons for this class
          _currentTitle = "Lesson: ${item['lessontitle']}";
        }
      } else if (_currentView == DashboardView.lessonDetail) {
        // Step 3: Lesson Detail (Quizzes/Students)
        if (index < _currentRawData.length) {
          final item = _currentRawData[index];
          final double score = (item['final_score'] as num? ?? 0).toDouble();
          
          // If a student bar is red (High Risk), show the notes dialog
          if (score < 60) {
            _showHighRiskNotesDrillDown(item, score);
          }
        }
        return; // Stop here; lesson is usually the deepest chart level
      }
    });
    
    _fetchGraphData(); // Always refresh data after changing view
  }

  void _showHighRiskNotesDrillDown(Map<String, dynamic> item, double score) {
    final String studentId = item['studentid']?.toString() ?? '';
    final String studentName = item['fullname']?.toString() ?? 'Unknown Student';
    final int? classId = item['classid'] as int?;
    final int? lessonId = _selectedId; // lessonDetail view — _selectedId is the lessonid

    showDialog(
      context: context,
      builder: (_) => HighRiskNotesDialog(
        studentId: studentId,
        studentName: studentName,
        classId: classId,
        lessonId: lessonId,
        score: score,
      ),
    );
  }

  void _resetToHome(String reason) {
    debugPrint(reason);
    setState(() {
      _currentView = DashboardView.school;
      _currentTitle = "School Overview";
      _selectedId = null;
    });
    _fetchGraphData();
  }

  Future<void> _refreshGraphData() async {
    final rawData = await Supabase.instance.client
        .from('student_lesson_stats')
        .select('*, quiz(grading_policy)')
        .eq('schoolid', widget.schoolId);

  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldkey,
      endDrawer: const SereneDrawer(),
      appBar: SereneHeader(scaffoldKey: _scaffoldkey),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 900;
          
          // Define the sidebar stack once
          final sidebar = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKPICards(),
              const SizedBox(height: 24),
              _buildQuickActions(),
            ],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: isMobile 
              ? Column(children: [_buildGraphSection(), const SizedBox(height: 24), sidebar])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildGraphSection()),
                    const SizedBox(width: 24),
                    Expanded(child: sidebar),
                  ],
                ),
          );
        },
      ),
    );
  }

  Widget _buildKPICards() {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _kpiCard(
          title: "Total Students",
          value: "$studentCount",
          icon: Icons.school,
          color: const Color(0xFFB3D8EE),
          onTap: () => _showUserPopup("Student"), 
        ),
        _kpiCard(
          title: "Total Teachers",
          value: "$teacherCount",
          icon: Icons.person,
          color: const Color(0xFFB3D8EE),
          onTap: () => _showUserPopup("Teacher"),
        ),
      ],
    );
  }

  Widget _kpiCard({required String title, required String value, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color, 
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1D5A71))),
                Text(value, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))),
              ],
            ),
            Icon(icon, size: 45, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 680,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1D5A71), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- TOP HEADER ROW ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SIDE: Back Button + Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_currentView != DashboardView.school)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                            onPressed: () {
                              setState(() {
                                if (_currentView == DashboardView.lessonDetail) {
                                  _currentView = DashboardView.classDetail;
                                  _selectedId = _parentClassId;
                                  _currentTitle = _parentClassTitle.isNotEmpty ? _parentClassTitle : "Class View";
                                } else {
                                  _currentView = DashboardView.school;
                                  _currentTitle = "School Overview";
                                  _selectedId = null;
                                }
                              });
                              _fetchGraphData();
                            },
                          ),
                        Flexible(
                          child: Text(
                            _currentTitle,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentView == DashboardView.lessonDetail 
                          ? "Student Performance Comparison" 
                          : "Performance Accuracy Table",
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1D5A71), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              // RIGHT SIDE: Filters (Only in School View)
              if (_currentView == DashboardView.school)
                Row(
                  children: [
                    _buildFilterMenu(
                      label: "Year",
                      icon: Icons.calendar_today,
                      items: _availableYears,
                      selectedItems: _selectedYears,
                      onChanged: (val, year) {
                        setState(() {
                          if (val == true) {
                            if (_selectedYears.length < 3) _selectedYears.add(year);
                          } else {
                            if (_selectedYears.length > 1) _selectedYears.remove(year);
                          }
                        });
                        _fetchGraphData();
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildFilterMenu(
                      label: "Teacher",
                      icon: Icons.people_alt_rounded,
                      items: _availableTeachers.map((t) => t['fullname'].toString()).toList(),
                      selectedItems: _selectedTeacherIds.map((id) {
                        return _availableTeachers.firstWhere((t) => t['teacherid'] == id, orElse: () => {'fullname': 'Unknown'})['fullname'].toString();
                      }).toList(),
                      onChanged: (val, name) {
                        final teacher = _availableTeachers.firstWhere((t) => t['fullname'] == name);
                        final tid = teacher['teacherid'] as int;
                        setState(() {
                          if (val == true) {
                            if (!_selectedTeacherIds.contains(tid)) _selectedTeacherIds.add(tid);
                          } else {
                            if (_selectedTeacherIds.length > 1) _selectedTeacherIds.remove(tid);
                          }
                        });
                        _fetchGraphData();
                      },
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 20),
          if (_currentView == DashboardView.school) ...[
          _buildYearLegend(),
          const SizedBox(height: 20),
        ],

          // --- CHART CONTENT ---
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_selectedYears.isEmpty || (_currentView == DashboardView.school && _selectedTeacherIds.isEmpty))
                    ? const Center(child: Text("Please select filters to view data"))
                    : graphData.isEmpty
                        ? const Center(child: Text("No performance data found"))
                        : BarChart(
                            BarChartData(
                              maxY: 100,
                              barTouchData: BarTouchData(
                                touchCallback: (FlTouchEvent event, barTouchResponse) {
                                  if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) return;
                                  if (event is FlTapUpEvent) {
                                    _handleNavigation(barTouchResponse.spot!.touchedBarGroupIndex);
                                  }
                                },
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipColor: (_) => const Color(0xFF1D5A71),
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      '${labels[groupIndex]}\n${rod.toY.toStringAsFixed(1)}%',
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    );
                                  },
                                ),
                              ),
                              barGroups: graphData,
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      int index = value.toInt();
                                      if (index >= 0 && index < labels.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(labels[index], style: const TextStyle(fontSize: 10, color: Color(0xFF1D5A71))),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 20,
                                    getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: const TextStyle(fontSize: 10)),
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterMenu({
    required String label,
    required IconData icon,
    required List<String> items,
    required List<String> selectedItems,
    required Function(bool?, String) onChanged,
  }) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => items.map((item) {
        return PopupMenuItem<String>(
          enabled: false, // Keeps the menu open when clicking
          child: StatefulBuilder(
            builder: (context, setMenuState) {
              final bool isSelected = selectedItems.contains(item);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item, style: const TextStyle(fontSize: 13)),
                value: isSelected,
                activeColor: const Color(0xFF1D5A71),
                onChanged: (val) {
                  // 1. Update global dashboard state
                  onChanged(val, item);
                  // 2. Update local checkbox state so it checks immediately
                  setMenuState(() {}); 
                },
              );
            },
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF7AA9CA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1D5A71)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Color(0xFF1D5A71), fontSize: 13, fontWeight: FontWeight.w600)),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF1D5A71)),
          ],
        ),
      ),
    );
  }

  Widget _buildYearLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: List.generate(_selectedYears.length, (yi) {
        final year = _selectedYears[yi];
        final color = _yearColors[yi % _yearColors.length];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text(year, style: const TextStyle(fontSize: 11, color: Color(0xFF1D5A71))),
          ],
        );
      }),
    );
  }
  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1D5A71),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Text("Administrative Tools",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))
          ),
          const SizedBox(height: 15),
          _actionTile(
            Icons.assignment_outlined, 
            "Generate Progress Report",
            onTap: () => _showProgressReport(),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1D5A71)),
      title: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF1D5A71))),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF1D5A71)),
      onTap: onTap, 
    );
  }


  void _showUserPopup(String roletype) {
    showDialog(
      context: context,
      builder: (_) => UserDirectoryDialog(
        roletype: roletype,
        schoolId: widget.schoolId,
      ),
    );
  }
}