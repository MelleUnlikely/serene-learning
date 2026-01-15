import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _departmentController = TextEditingController();
  
  final String _selectedRole = 'Teacher'; 
  
  List<Map<String, dynamic>> _schools = [];
  int? _selectedSchoolId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSchools();
  }

  Future<void> _fetchSchools() async {
    try {
      final data = await Supabase.instance.client.from('schools').select('schoolid, schoolname');
      setState(() {
        _schools = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint("Error fetching schools: $e");
    }
  }

  Future<void> _handleRegister() async {
    if (_fullNameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _employeeIdController.text.isEmpty ||
        _departmentController.text.isEmpty) {
      _showSnackBar("Please fill in all details.", Colors.orange);
      return;
    }
    
    if (_selectedSchoolId == null) {
      _showSnackBar("Please select your school.", Colors.orange);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar("Passwords do not match!", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      //Authorization Check
      final authCheck = await Supabase.instance.client
          .from('authorizedstaff')
          .select()
          .eq('employeeid', _employeeIdController.text.trim())
          .eq('schoolid', _selectedSchoolId!)
          .eq('role', 'Teacher')
          .eq('isclaimed', false)
          .maybeSingle();

      if (authCheck == null) {
        _showSnackBar("Invalid ID or already claimed for this school.", Colors.red);
        setState(() => _isLoading = false);
        return; 
      }

      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'fullname': _fullNameController.text.trim(),
          'roletype': _selectedRole,
          'schoolid': _selectedSchoolId,
          'employeeid': _employeeIdController.text.trim(),
          'department': _departmentController.text.trim(),
        },
      );

      if (res.user != null) {
        //Mark ID as used
        await Supabase.instance.client
            .from('authorizedstaff')
            .update({'isclaimed': true})
            .eq('employeeid', _employeeIdController.text.trim());

        if (mounted) {
          _showSnackBar("Verification email sent! Please check your inbox.", Colors.green);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _fullNameController, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            
            DropdownButtonFormField<int>(
              initialValue: _selectedSchoolId,
              decoration: const InputDecoration(labelText: "Your School", border: OutlineInputBorder()),
              items: _schools.map((s) => DropdownMenuItem<int>(value: s['schoolid'], child: Text(s['schoolname']))).toList(),
              onChanged: (val) => setState(() => _selectedSchoolId = val),
            ),
            const SizedBox(height: 15),

            TextField(controller: _employeeIdController, decoration: const InputDecoration(labelText: "Employee ID", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _departmentController, decoration: const InputDecoration(labelText: "Department", border: OutlineInputBorder())),
            const SizedBox(height: 15),

            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 15),
            TextField(controller: _confirmPasswordController, decoration: const InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 30),
            
            _isLoading 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: _handleRegister, 
                  child: const Text("Register as Teacher")
                ),
          ],
        ),
      ),
    );
  }
}