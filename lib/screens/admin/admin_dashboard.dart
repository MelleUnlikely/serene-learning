import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminDashboard extends StatefulWidget {
  final int schoolId; 
  const AdminDashboard({super.key, required this.schoolId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int studentCount = 0;
  int teacherCount = 0;
  bool isLoading = true;
  List<BarChartGroupData> graphData = [];
  List<String> labels = [];

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    try {
      await Future.wait([
        _fetchCounts(),
        _fetchGraphData(),
      ]);
    } catch (e) {
      debugPrint("Dashboard Init Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _generatePDFReport(List<dynamic> data) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("School Progress Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text("Generated on: ${DateTime.now().toString()}"),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: ['Class Name', 'Average Accuracy'],
              data: data.map((item) => [
                item['classname'] ?? 'Unnamed',
                "${(item['average_accuracy'] as num? ?? 0).toStringAsFixed(1)}%"
              ]).toList(),
            ),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
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
  try {
    // 1. Fetch from the new class-based view
    final List<dynamic> data = await Supabase.instance.client
        .from('class_performance_stats') 
        .select()
        .eq('schoolid', widget.schoolId);

    if (mounted) {
      setState(() {
        // 2. Map classname instead of curriculumlevel
        labels = data.map((e) => e['classname']?.toString() ?? 'Unknown Class').toList();
        
        graphData = data.asMap().entries.map((entry) {
          int index = entry.key;
          var row = entry.value;
          
          // 3. Ensure we use the calculated average_accuracy from SQL
          double score = (row['average_accuracy'] as num? ?? 0.0).toDouble();
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: score,
                color: const Color(0xFF2D4B5F),
                width: 22,
                borderRadius: BorderRadius.circular(4),
              )
            ],
          );
        }).toList();
      });
    }
  } catch (e) {
    debugPrint("Graph Data Error: $e");
    if (mounted) setState(() => graphData = []); 
  }
}


void _showProgressReport() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.analytics, color: Color(0xFF2D4B5F)),
          SizedBox(width: 10),
          Text("School Progress Report"),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: FutureBuilder(
          future: Supabase.instance.client
              .from('class_performance_stats')
              .select()
              .eq('schoolid', widget.schoolId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            
            final data = snapshot.data as List<dynamic>? ?? [];
            if (data.isEmpty) return const Text("No class data available for this school.");

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Average Accuracy by Class", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 15),
                // Wrap the list in a Flexible or constrained box if it gets too long
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView(
                    shrinkWrap: true,
                    children: data.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(child: Text(item['classname'] ?? 'Unnamed Class')),
                          Text(
                            "${(item['average_accuracy'] as num? ?? 0).toStringAsFixed(1)}%",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: (item['average_accuracy'] as num? ?? 0) / 100,
                              backgroundColor: Colors.grey[200],
                              color: const Color(0xFF2D4B5F),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                // MOVE YOUR BUTTONS HERE
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Generating PDF..."), duration: Duration(seconds: 1)),
                        );
                        await _generatePDFReport(data); // Now 'data' is defined!
                      },
                      icon: const Icon(Icons.download),
                      label: const Text("Download PDF"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D4B5F), 
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                )
              ],
            );
          },
        ),
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildKPICards(),
                const SizedBox(height: 32),
                _buildMainContent(constraints),
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _buildHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Serene", 
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D4B5F))),
            Text("School Administrator Portal", 
              style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        Row(
          children: [
            Icon(Icons.notifications_none, color: Colors.blueGrey),
            SizedBox(width: 15),
            Icon(Icons.account_circle_outlined, color: Colors.blueGrey, size: 30),
          ],
        ),
      ],
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
      color: const Color(0xFF94AFB9),
      onTap: () => _showUserPopup("Teacher"), // Updated to popup
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
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Text(value, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
              ],
            ),
            Icon(icon, size: 45, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  

  // 3. Graph and Action Summary
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
    height: 450,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 10,
        )
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Academic Performance Index",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Text(
          "Real-time Average Accuracy (%)",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 40),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : graphData.isEmpty
                  ? const Center(child: Text("No performance data found"))
                  : BarChart(
                      BarChartData(
                        maxY: 100,
                        minY: 0,
                        alignment: BarChartAlignment.spaceAround,
                        groupsSpace: 12,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: graphData,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => const Color(0xFF2D4B5F),
                            tooltipRoundedRadius: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                "${labels[groupIndex]}\n",
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: "${rod.toY.toStringAsFixed(1)}%",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60, // Space for the rotated text
                            getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            
                            if (index >= 0 && index < labels.length) {
                              return SideTitleWidget(
                                meta: meta, 
                                space: 12,
                                angle: 0.5, 
                                child: Text(
                                  labels[index],
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D4B5F),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          ),
                        ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                if (value % 25 == 0) { 
                                  return Text(
                                    "${value.toInt()}%",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Text("Administrative Tools", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
            _actionTile(
              Icons.assignment_outlined, 
              "Generate Progress Report",
              onTap: () => _showProgressReport(),
            ),
          const Divider(height: 40),
          ElevatedButton.icon(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[50],
              foregroundColor: Colors.red,
              elevation: 0,
            ),
          )
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, {VoidCallback? onTap}) {
  return ListTile(
    leading: Icon(icon, color: const Color(0xFF2D4B5F)),
    title: Text(label, style: const TextStyle(fontSize: 14)),
    trailing: const Icon(Icons.chevron_right, size: 18),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("$roletype Directory", 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D4B5F))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
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
                      separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F1F1)),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF2D4B5F),
                            child: Text(user['fullname']?[0] ?? user['email'][0].toUpperCase(), 
                              style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(user['fullname'] ?? 'No Name Provided', 
                            style: const TextStyle(fontWeight: FontWeight.bold)),
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