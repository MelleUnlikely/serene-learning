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
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        
        // We set a massive bottom margin to push it to the top of the screen
        margin: EdgeInsets.only(
          bottom: 70, //para mapunta sa taas ung snackbar
          left: 590,
          right: 590,
        ),
        
        dismissDirection: DismissDirection.up, // Allows user to swipe it away upwards
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Extends the background behind the app bar
      extendBodyBehindAppBar: true, 
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
              image: AssetImage("assets/images/background.png"),
              fit: BoxFit.cover,
          ),
        ),
        child: Align(
          alignment: const Alignment(0, -0.9),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 30), // Space for top
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Sign Up",
                        style: TextStyle(
                          fontSize: 26, 
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFF1D5A71)
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      //Input Fields
                      _buildInputField(_fullNameController, "Full Name"),
                      const SizedBox(height: 20),
                      
                      _buildInputField(_emailController, "Email"),
                      const SizedBox(height: 20),

                      //Dropdown for school selection
                      DropdownButtonFormField<int>(
                        value: _selectedSchoolId,
                        decoration: const InputDecoration(
                          labelText: "Select School",
                          labelStyle: const TextStyle(color: Color(0xFF1D5A71), fontSize: 14, fontWeight: FontWeight.bold),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0XFF7AA9CA))),
                        ),
                        items: _schools.map((s) => DropdownMenuItem<int>(
                          value: s['schoolid'], 
                          child: Text(s['schoolname'])
                        )).toList(),
                        onChanged: (val) => setState(() => _selectedSchoolId = val),
                      ),
                      const SizedBox(height: 20),

                      _buildInputField(_employeeIdController, "Employee ID"),
                      const SizedBox(height: 20),

                      _buildInputField( _departmentController, "Department"),
                      const SizedBox(height: 20,),

                      _buildInputField(_passwordController, "Password", isObscure: true),
                      const SizedBox(height: 20),
                      
                      _buildInputField(_confirmPasswordController, "Confirm Password", isObscure: true),
                      const SizedBox(height: 40),

                      // Signup Button
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFa5ceeb),
                                foregroundColor: const Color(0xFF006064),
                                elevation: 0,
                                minimumSize: const Size(180, 45),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: _handleRegister,
                              child: const Text("Sign up", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                      
                      const SizedBox(height: 20),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account? ",
                          style: TextStyle(color: Color(0xFF006064),
                          fontWeight: FontWeight.bold)),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(
                                context
                              );
                            },
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                color: Color(0xFF006064), 
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to keep the code clean and consistent
  Widget _buildInputField(TextEditingController controller, String label, {bool isObscure = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF1D5A71), fontSize: 14, fontWeight: FontWeight.bold),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0XFF7AA9CA), width: 1),
        ),
      ),
    );
  }
}