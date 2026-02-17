import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

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
    // Only call the initializer, it handles both fetches
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

  Future<void> _fetchCounts() async {
    try {
      final studentRes = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('roletype', 'Student')
          .count(CountOption.exact);

      final teacherRes = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('roletype', 'Teacher')
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
    // 1. CHANGE THIS TABLE NAME to match your new SQL View
    final List<dynamic> data = await Supabase.instance.client
        .from('curriculum_level_performance') 
        .select();

    if (mounted) {
      setState(() {
        labels = data.map((e) => e['curriculumlevel'].toString()).toList();
        
        graphData = data.asMap().entries.map((entry) {
          int index = entry.key;
          var row = entry.value;
          
          double score = (row['average_accuracy'] ?? 0.0).toDouble();
          
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

  void _showUserList(String roletype) {
    debugPrint("Navigating to $roletype list");
    // This is where you'll push the new screen we discussed
    /*
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserListScreen(roletype: roletype),
      ),
    );
    */
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
                _buildHeader(), // Simplified Header
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

  // 1. Clean Header (Title + Minimal Icons)
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

  // 2. Metric Cards (Clickable)
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
      onTap: () => _showUserPopup("Student"), // Updated to popup
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
                            // FIX: Use getTooltipColor instead of tooltipBgColor
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
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                if (index >= 0 && index < labels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 10.0),
                                    child: Text(
                                      labels[index],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D4B5F),
                                      ),
                                    ),
                                  );
                                }
                                return const Text("");
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) {
                                if (value == 0 || value == 50 || value == 100) {
                                  return Text(
                                    "${value.toInt()}%",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                                return const Text("");
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                      ),
                    ),
        ),
      ],
    ),
  );
}

BarChartGroupData _makeGroupData(int x, double y, String label) {
    return BarChartGroupData(
      x: x, 
      barRods: [
        BarChartRodData(
          toY: y,
          color: const Color(0xFF2D4B5F),
          width: 22,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
        )
      ],
      // You can store the label in the tooltip or use titlesData
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
          _actionTile(Icons.assignment_outlined, "Generate Progress Report"),
          _actionTile(Icons.calendar_today_outlined, "Academic Calendar"),
          _actionTile(Icons.settings_outlined, "System Configurations"),
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

  Widget _actionTile(IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2D4B5F)),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {},
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
                      .eq('roletype', roletype),
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
                              Text("ID: ${user['schoolid']} | Status: ${user['status']}", 
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