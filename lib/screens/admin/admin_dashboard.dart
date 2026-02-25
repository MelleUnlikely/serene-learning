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
  List<dynamic> _currentRawData = [];
  
  int? _selectedId;
  int? _parentClassId;
  String _currentTitle = "School Overview";

  bool includeLessons = false;
  bool includeStudents = false;

  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
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
        fetchedData = await client.from('class_performance_stats').select().eq('schoolid', widget.schoolId);
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
  List<BarChartGroupData> newGraphData = [];

  for (int i = 0; i < fetchedData.length; i++) {
    final item = fetchedData[i];
    double score = 0.0;
    String label = "";

    if (_currentView == DashboardView.school) {
      label = item['classname']?.toString() ?? '';
      score = (item['average_accuracy'] as num? ?? 0.0).toDouble();
    } 
    else if (_currentView == DashboardView.classDetail) {
      label = item['lessontitle']?.toString() ?? '';
 
      final attempts = await Supabase.instance.client
          .from('student_lesson_stats')
          .select()
          .eq('lessonid', item['lessonid']);
      
      score = _calculatePolicyScore(attempts, item['grading_policy'] ?? 'highest');
    } 
    else if (_currentView == DashboardView.lessonDetail) {
      label = item['fullname']?.toString() ?? '';
      score = (item['final_score'] as num? ?? 0.0).toDouble();
    }

    newLabels.add(label);
    newGraphData.add(
      BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: score,
            color: const Color(0xFF1D5A71),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          )
        ],
      ),
    );
  }

  if (mounted) {
    setState(() {
      labels = newLabels;
      graphData = newGraphData;
    });
  }
}
  
  void _handleNavigation(int index) {
    if (index < 0 || index >= _currentRawData.length) return;
    final item = _currentRawData[index];

    setState(() {
      if (_currentView == DashboardView.school) {
        // Drills down into a specific class
        _currentView = DashboardView.classDetail;
        _selectedId = item['classid'] ?? item['class_id']; 
        _currentTitle = "Class: ${item['classname'] ?? 'Unknown'}";
      } else if (_currentView == DashboardView.classDetail) {
        // Drills down into a specific lesson
        _parentClassId = _selectedId; 
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
      height: 500,
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
                        _currentTitle = "Class View";
                      } else {
                        _currentView = DashboardView.school;
                        _currentTitle = "School Overview";
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
          const SizedBox(height: 30),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
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
                              return BarTooltipItem(
                                '${labels[groupIndex]}\n',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                children: [
                                  TextSpan(
                                    text: '${rod.toY.toStringAsFixed(1)}%',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
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
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                      ),
                    ),
          ),
        ],
      ),
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
      builder: (BuildContext context) {
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
                    Text("$roletype Directory", 
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Color(0xFF1D5A71))),
                  ],
                ),
                const Divider(color: Color(0xFF1D5A71)),
                Expanded(
                  child: FutureBuilder(
                    future: Supabase.instance.client
                        .from('profiles')
                        .select('email, fullname, schoolid, status')
                        .eq('roletype', roletype)
                        .eq('schoolid', widget.schoolId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}"));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
                        return const Center(child: Text("No records found."));
                      }

                      final users = snapshot.data as List<dynamic>;

                      return ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (context, index) => const Divider(color: Color(0xFF1D5A71)),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1D5A71),
                              child: Text(user['fullname']?[0] ?? user['email'][0].toUpperCase(), 
                                style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(user['fullname'] ?? 'No Name Provided', 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user['email']),
                                Text("Status: ${user['status']}", 
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}