import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StudentPerformanceScreen extends StatefulWidget{
  final int classId;

  const StudentPerformanceScreen({super.key, required this.classId});

  @override
  State<StudentPerformanceScreen> createState() => _StudentPerformanceScreenState();
}

class _StudentPerformanceScreenState extends State<StudentPerformanceScreen>{
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  List<Map<String, dynamic>> _students = []; 

  int _activeCount = 0;
  int _totalStudents = 0;
  
  @override
  void initState() {
    super.initState();
    _fetchStudentData(); // Call the fetch function when the page opens
  }

  Future<void> _fetchStudentData() async {
    setState(() => _isLoading = true);
    try {
      // This query gets students assigned to this specific class
      // Replace 'profiles' and 'enrollments' with your actual table names
      final data = await supabase
          .from('profiles') 
          .select('fullname, grade, last_login')
          .eq('classid', widget.classId);

      setState(() {
        _students = List<Map<String, dynamic>>.from(data);
        _totalStudents = _students.length;
        
        // Calculate how many logged in today for the donut
        final today = DateTime.now().toIso8601String().split('T')[0];
        _activeCount = _students.where((s) => 
          s['last_login'] != null && s['last_login'].toString().startsWith(today)
        ).length;
      });
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //this is for the list
          Expanded(
            flex: 2,
            child: _buildPerformanceTable(),
          ),
          const SizedBox(width: 24),
          //eto ung charts / summary
          Expanded(
            flex: 1,
            child: _buildStudentActivityDonut(),
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
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("Student Performance", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))),
          ),
          // Table Headers
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text("Student", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text("Grade", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text("Remarks", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text("Last Login", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const Divider(),
          // Scrollable List
          Expanded(
            child: ListView.builder(
              itemCount: _students.length, //papalit nito into like, data from the supabase.
              itemBuilder: (context, index) {
                final student = _students[index];
                String lastLogin = student['last_login'] != null 
                  ? DateFormat('MMM d, h:mm a').format(DateTime.parse(student['last_login']))
                  : "Never";

                return ListTile(
                  title: Row(
                    children: [
                      Expanded(flex: 2, child: Text(student['full_name'])),
                      Expanded(child: Text("${student['grade']}%")),
                      // 2. THE DATA: Showing the last login time
                      Expanded(
                        child: Text(
                          lastLogin,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: student['grade'] >= 75 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            student['grade'] >= 75 ? "Passed" : "Failed",
                            style: TextStyle(
                              color: student['grade'] >= 75 ? Colors.green : Colors.red, 
                              fontSize: 12,
                              fontWeight: FontWeight.bold
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
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

  Widget _buildStudentActivityDonut() {
    // Get current date formatted like "November 27, 2025"
    String formattedDate = DateFormat('MMMM d, yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          const Text(
            "Student Activity", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71)),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 70,
                    sections: [
                      // Blue section: Students currently logged in
                      PieChartSectionData(color: const Color(0xFF1D5A71), value: 24, showTitle: false, radius: 20),
                      // Gray section: Students not yet logged in today
                      PieChartSectionData(color: Colors.black12, value: 6, showTitle: false, radius: 20),
                    ],
                  ),
                ),
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [ //eto ay hardcoded. i belib
                      Text("24", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))),
                      Text("Logged in\nStudents", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // DYNAMIC DATE TEXT
          Text(
            "as of $formattedDate", 
            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}