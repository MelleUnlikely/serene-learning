import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_application_1/widgets/serene_menu.dart';
import 'package:flutter_application_1/widgets/serene_header.dart';

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
            padding: const pw.EdgeInsets.only(left: 20, top: 10),
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
        barsSpace: 4,
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
    // High-risk drill-down: show teacher notes for red bars at student level
    if (_currentView == DashboardView.lessonDetail) {
      if (index < 0 || index >= _currentRawData.length) return;
      final item = _currentRawData[index];
      final double score = (item['final_score'] as num? ?? 0).toDouble();
      if (score < 60) {
        _showHighRiskNotesDrillDown(item, score);
      }
      return;
    }

    if (_currentView == DashboardView.school) {
      // School view uses _schoolBarMeta for drill-down (multi-year grouped bars)
      final meta = _schoolBarMeta[index];
      if (meta == null) return;
      setState(() {
        _currentView = DashboardView.classDetail;
        _selectedId = meta['classid'] as int?;
        _currentTitle = "Class: ${meta['classname'] ?? 'Unknown'}";
      });
      if (_selectedId == null) { _resetToHome("Navigation Error: classid null"); return; }
      _fetchGraphData();
      return;
    }

    if (index < 0 || index >= _currentRawData.length) return;
    final item = _currentRawData[index];

    setState(() {
      if (_currentView == DashboardView.classDetail) {
        _parentClassId = _selectedId;
        _parentClassTitle = _currentTitle;
        _currentView = DashboardView.lessonDetail;
        _selectedId = item['lessonid'] ?? item['lesson_id'];
        _currentTitle = "Lesson: ${item['lessontitle'] ?? 'Unknown'}";
      }
    });

    if (_selectedId == null) {
      _resetToHome("Navigation Error: ID was null");
      return;
    }

    _fetchGraphData();
  }

  void _showHighRiskNotesDrillDown(Map<String, dynamic> item, double score) {
    final String studentId = item['studentid']?.toString() ?? '';
    final String studentName = item['fullname']?.toString() ?? 'Unknown Student';
    final int? classId = item['classid'] as int?;
    final int? lessonId = _selectedId; // lessonDetail view — _selectedId is the lessonid

    showDialog(
      context: context,
      builder: (_) => _HighRiskNotesDialog(
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
      key: _scaffoldkey,
      backgroundColor: const Color(0xFFF5F7FB),
      endDrawer: const SereneDrawer(),
      appBar: SereneHeader(scaffoldKey: _scaffoldkey),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: double.infinity,
            height: constraints.maxHeight,
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildKPICards(),
                  const SizedBox(height: 25),
                  _buildMainContent(constraints),
                ],
              ),
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
        width: 320,
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

  Widget _buildMainContent(BoxConstraints constraints) {
    bool isMobile = constraints.maxWidth < 900;
    
    return isMobile 
        ? Column(children: [_buildGraphSection(), const SizedBox(height: 24), _buildQuickActions()])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Expanded(flex: 3, child: _buildGraphSection()),
              const SizedBox(width: 24),
              Expanded(child: _buildQuickActions()),
            ]
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
              Expanded(
                child: Text(
                  _currentTitle,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentView == DashboardView.lessonDetail 
                ? "Student Performance Comparison" 
                : "Performance Accuracy Table",
            style: const TextStyle(fontSize: 14, color: Color(0xFF1D5A71), fontWeight: FontWeight.w500),
          ),
          if (_currentView == DashboardView.school) ...[  
            const SizedBox(height: 12),
            // ── Year filter ──
            if (_availableYears.isNotEmpty) ...[
              const Text("Filter by Year",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D5A71))),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(_availableYears.length, (yi) {
                  final year = _availableYears[yi];
                  final isSelected = _selectedYears.contains(year);
                  return FilterChip(
                    label: Text(year, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF1D5A71))),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1D5A71),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? const Color(0xFF1D5A71) : const Color(0xFF7AA9CA)),
                    showCheckmark: false,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          if (_selectedYears.length < 3) _selectedYears.add(year);
                        } else {
                          if (_selectedYears.length > 1) _selectedYears.remove(year);
                        }
                      });
                      _fetchGraphData();
                    },
                  );
                }),
              ),
              const SizedBox(height: 4),
              _buildYearLegend(),
            ],
            // ── Teacher filter ──
            if (_availableTeachers.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text("Filter by Teacher",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D5A71))),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _availableTeachers.map((t) {
                  final int tid = t['teacherid'] as int;
                  final String name = t['fullname'] as String;
                  final bool isSelected = _selectedTeacherIds.contains(tid);
                  return FilterChip(
                    label: Text(name, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF1D5A71))),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1D5A71),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? const Color(0xFF1D5A71) : const Color(0xFF7AA9CA)),
                    showCheckmark: false,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedTeacherIds.add(tid);
                        } else {
                          if (_selectedTeacherIds.length > 1) _selectedTeacherIds.remove(tid);
                        }
                      });
                      _fetchGraphData();
                    },
                  );
                }).toList(),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_selectedYears.isEmpty || (_currentView == DashboardView.school && _selectedTeacherIds.isEmpty))
                    ? const Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.filter_list_off, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text("Please select filters to view data",
                              style: TextStyle(color: Colors.grey)),
                        ]),
                      )
                    : graphData.isEmpty
                        ? const Center(child: Text("No performance data found"))
                    : BarChart(
                      BarChartData(
                        maxY: 100,
                        barTouchData: BarTouchData(
                          touchCallback: (FlTouchEvent event, barTouchResponse) {
                            if (!event.isInterestedForInteractions ||
                                barTouchResponse == null ||
                                barTouchResponse.spot == null) {
                              return;
                            }

                            if (event is FlTapUpEvent) {
                              final index = barTouchResponse.spot!.touchedBarGroupIndex;
                              _handleNavigation(index);
                            }
                          },
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => const Color(0xFF1D5A71),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final String extra = groupIndex < tooltipExtras.length ? tooltipExtras[groupIndex] : '';
                              String yearLabel = '';
                              if (_currentView == DashboardView.school && rodIndex < _selectedYears.length) {
                                yearLabel = _selectedYears[rodIndex];
                              }
                              return BarTooltipItem(
                                '${labels[groupIndex]}\n',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                children: [
                                  if (yearLabel.isNotEmpty)
                                    TextSpan(
                                      text: '$yearLabel\n',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  TextSpan(
                                    text: '${rod.toY.toStringAsFixed(1)}%',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
                                  ),
                                  if (extra.isNotEmpty)
                                    TextSpan(
                                      text: '\n$extra',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                ],
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
                                    child: Text(
                                      labels[index], 
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF1D5A71)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 20,
                              getTitlesWidget: (value, meta) {
                                if (value % 20 == 0) {
                                  return Text(
                                    '${value.toInt()}%',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF1D5A71)),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 20,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.grey.withOpacity(0.15),
                            strokeWidth: 1,
                          ),
                        ),
                      ),
                    ),
          ),
        ],
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
      builder: (_) => _UserDirectoryDialog(
        roletype: roletype,
        schoolId: widget.schoolId,
      ),
    );
  }
}

class _UserDirectoryDialog extends StatefulWidget {
  final String roletype;
  final int schoolId;

  const _UserDirectoryDialog({required this.roletype, required this.schoolId});

  @override
  State<_UserDirectoryDialog> createState() => _UserDirectoryDialogState();
}

class _UserDirectoryDialogState extends State<_UserDirectoryDialog> {
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
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 8),
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

class _HighRiskNotesDialog extends StatefulWidget {
  final String studentId;
  final String studentName;
  final int? classId;
  final int? lessonId;
  final double score;

  const _HighRiskNotesDialog({
    required this.studentId,
    required this.studentName,
    this.classId,
    this.lessonId,
    required this.score,
  });

  @override
  State<_HighRiskNotesDialog> createState() => _HighRiskNotesDialogState();
}

class _HighRiskNotesDialogState extends State<_HighRiskNotesDialog> {
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