import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/widgets/serene_header.dart';
import 'package:flutter_application_1/widgets/serene_menu.dart';

class AccountPage extends StatefulWidget {
  final String uid;

  const AccountPage({super.key, required this.uid});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String _userName = "";
  String _schoolName = "";
  String? _employeeId;

  @override
  void initState() {
    super.initState();
    _fetchAccountInfo();
  }

Future<void> _fetchAccountInfo() async {
  try {
    final data = await supabase
        .from('profiles')
        .select('''
          fullname, 
          schools(schoolname), 
          teacher(employeeid)
        ''')
        .eq('uid', widget.uid)
        .maybeSingle();

    if (data != null && mounted) {
      setState(() {
        _userName = data['fullname'] ?? "N/A";

        final schoolData = data['schools'];
        if (schoolData is List && schoolData.isNotEmpty) {
           _schoolName = schoolData[0]['schoolname'] ?? "N/A";
        } else if (schoolData is Map) {
           _schoolName = schoolData['schoolname'] ?? "N/A";
        } else {
           _schoolName = "No School Linked";
        }

        final teacherData = data['teacher'];
        if (teacherData != null) {
          if (teacherData is List && teacherData.isNotEmpty) {
            _employeeId = teacherData[0]['employeeid']?.toString();
          } else if (teacherData is Map) {
            _employeeId = teacherData['employeeid']?.toString();
          }
        } else {
          _employeeId = null; 
        }

        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  } catch (e) {
    debugPrint("Fetch Error: $e");
    if (mounted) setState(() => _isLoading = false);
  }
}

Future<void> _editName() async {
  final TextEditingController nameController = TextEditingController(text: _userName);

  return showDialog(
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
              Icon(Icons.edit, color: Color(0xFF1D5A71)),
              SizedBox(width: 12),
              Text(
                "Edit Name",
                style: TextStyle(color: Color(0xFF1D5A71), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
      ),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: "Full Name",
          labelStyle: TextStyle(color: Color(0xFF1D5A71)),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0XFF7AA9CA), width: 1),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF1D5A71), width: 2)
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Color(0xFF1D5A71))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D5A71)),
          onPressed: () async {
            final newName = nameController.text.trim();
            if (newName.isNotEmpty) {
              try {
                await supabase
                    .from('profiles')
                    .update({'fullname': newName})
                    .eq('uid', widget.uid);

                if (mounted) {
                  setState(() => _userName = newName);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Name updated successfully!")),
                  );
                }
              } catch (e) {
                debugPrint("Update Error: $e");
              }
            }
          },
          child: const Text("Save", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: const SereneDrawer(),
      appBar: SereneHeader(scaffoldKey: _scaffoldKey, showBackButton: false),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1D5A71)))
          : SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: _buildAccountContent(context),
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildAccountContent(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const Text(
              "Account Profile",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D5A71),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF1D5A71), size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(color: Color(0xFF1D5A71)),
        const SizedBox(height: 30),
        
        _buildInfoTile(
          Icons.person, 
          "Full Name", 
          _userName, 
          onEdit: _editName 
        ),
        _buildInfoTile(Icons.school, "School", _schoolName),
        
        if (_employeeId != null && _employeeId!.isNotEmpty)
          _buildInfoTile(Icons.badge, "Employee ID", _employeeId!),
        
        const SizedBox(height: 40),
      ],
    );
  }

Widget _buildInfoTile(IconData icon, String label, String value, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD0EDF9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF1D5A71)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF1D5A71))),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D5A71),
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF1D5A71), size: 20),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }

}