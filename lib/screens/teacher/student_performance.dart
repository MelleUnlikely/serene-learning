import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StudentPerformanceScreen extends StatefulWidget {
  final int classId;

  const StudentPerformanceScreen({super.key, required this.classId});

  @override
  State<StudentPerformanceScreen> createState() => _StudentPerformanceScreenState();
}

class _StudentPerformanceScreenState extends State<StudentPerformanceScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  List<Map<String, dynamic>> _students = [];
  List<FlSpot> _weeklySpots = [];
  int _activeCount = 0;
  int _totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      debugPrint("Fetching data for class: ${widget.classId}");

      // 1. Fetch Students from the View we just fixed
      final List<dynamic> data = await supabase
          .from('student_activity_view')
          .select()
          .eq('classid', widget.classId);
      
      debugPrint("View Data received: ${data.length} students");

      final response = await supabase
        .from('student_activity_view')
        .select()
        .eq('classid', widget.classId);

      debugPrint("RAW JSON FROM VIEW: $response");

      // 2. Fetch Weekly Activity Trend
      final List<dynamic> weeklyData = await supabase
          .rpc('get_weekly_login_activity', params: {'p_class_id': widget.classId});

      if (mounted) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(data);
          _totalStudents = _students.length;

          // Donut Chart Logic: Count logins for TODAY
          final now = DateTime.now();
          _activeCount = _students.where((s) {
            if (s['last_sign_in_at'] == null) return false;
            DateTime loginDate = DateTime.parse(s['last_sign_in_at']);
            return loginDate.year == now.year &&
                   loginDate.month == now.month &&
                   loginDate.day == now.day;
          }).length;

          // Line Chart Logic: Map the 7-day trend
          _weeklySpots = weeklyData.asMap().entries.map((entry) {
            return FlSpot(
              entry.key.toDouble(), 
              (entry.value['student_count'] ?? 0).toDouble()
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("DATABASE ERROR: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Performance Table
          Expanded(
            flex: 2,
            child: _buildPerformanceTable(),
          ),
          const SizedBox(width: 24),
          // Right: Analytics
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildStudentActivityDonut(),
                const SizedBox(height: 24),
                _buildWeeklyTrendChart(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF1D5A71)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("Student Performance", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)))),
                Expanded(flex: 1, child: Text("Accuracy", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)))),
                Expanded(flex: 1, child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)))),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF1D5A71)),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Using person_off or people_outline for "No students"
                          Icon(
                            Icons.person, 
                            size: 64, 
                            color: Colors.grey
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No students enrolled in this class.",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          double grade = (student['overall_grade'] ?? 0.0).toDouble();

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2, 
                                  child: Text(
                                    student['fullname'] ?? "Unknown",
                                    style: const TextStyle(color: Colors.black),
                                  )
                                ),
                                // flex: 1 matches accuracy
                                Expanded(
                                  flex: 1, 
                                  child: Text("${grade.toStringAsFixed(1)}%")
                                ), 
                                // flex: 1 matches status
                                Expanded(
                                  flex: 1, 
                                  child: Align(
                                    alignment: Alignment.centerLeft, // Align badge to left of its space
                                    child: _buildRemarksBadge(grade)
                                  )
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksBadge(double grade) {
    bool isPassed = grade >= 60.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPassed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPassed ? "Passed" : "Failed",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isPassed ? Colors.green : Colors.red,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStudentActivityDonut() {
    String formattedDate = DateFormat('MMMM d, yyyy').format(DateTime.now());
    double activeValue = _activeCount.toDouble();
    double inactiveValue = (_totalStudents - _activeCount).toDouble();
    if (_totalStudents == 0) inactiveValue = 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF1D5A71)),
      ),
      child: Column(
        children: [
          const Text("Student Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))),
          const SizedBox(height: 30),
          SizedBox(
            height: 180,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 70,
                    centerSpaceColor: Colors.white,
                    sectionsSpace: 0,
                    sections: [
                      PieChartSectionData(
                        color: const Color(0xFF1D5A71), 
                        value: _activeCount.toDouble(), 
                        showTitle: false, 
                        radius: 20
                      ),
                      PieChartSectionData(
                        color: const Color(0xFFE0E0E0), 
                        value: (_totalStudents - _activeCount).toDouble(), 
                        showTitle: false, 
                        radius: 20
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("$_activeCount", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))),
                      const Text("Logged in\nStudents", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF1D5A71))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Text("as of $formattedDate", style: const TextStyle(fontSize: 12, color: Color(0xFF1D5A71))),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF1D5A71)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Weekly Activity Trend",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _weeklySpots.isEmpty ? [const FlSpot(0, 0)] : _weeklySpots,
                    isCurved: true,
                    color: const Color(0xFF1D5A71),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFF1D5A71).withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}