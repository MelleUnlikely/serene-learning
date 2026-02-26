import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'registration_screen.dart'; 
import '../teacher/class_screen.dart'; 
import '../admin/admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        final userData = await Supabase.instance.client
            .from('profiles')
            .select('roletype, userid, schoolid')
            .eq('email', response.user!.email!)
            .single();  

      if (userData['roletype'] == 'Teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CreateClassScreen(teacherId: userData['userid'])),
        );
      } 
      else if (userData['roletype'] == 'School Administrator') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
          builder: (context) => AdminDashboard(schoolId: userData['schoolid']),
        ),
        );
      }
    }
      } catch (e) {
      // This helps you see the REAL error in the console
      debugPrint("Login error details: $e");
      
      // Show a more descriptive error to the user
      String errorMsg = "Login Failed. Please check your email/password.";
      if (e.toString().contains("PostgrestException")) {
        errorMsg = "Profile not found. Please contact admin.";
      }
      
      _showSnackBar(errorMsg, Colors.red);
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
        
        margin: EdgeInsets.only(
          bottom: 120, //para mapunta sa taas ung snackbar
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
      backgroundColor: Colors.transparent, 
      extendBodyBehindAppBar: true, 
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(//for the bg
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
                //logo muna
                Image.asset(
                  "assets/images/logo.png",
                  height: 180
                ),
                
                //lalagyan nila username + password + sign up
                Container(
                  constraints: const BoxConstraints(maxWidth: 350),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(30), //corner
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueGrey.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Login",
                        style: TextStyle(
                          fontSize: 28, 
                          fontWeight: FontWeight.w600, 
                          color: Color(0xFF1D5A71)
                        ),
                      ),
                      
                      //for username field
                      TextField(
                        cursorColor: Color(0xFF1D5A71),
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "Email", //changed from username into email.
                          labelStyle: TextStyle(color: Color(0xFF1D5A71), fontWeight: FontWeight.bold),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0XFF7AA9CA), width: 1),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF1D5A71), width: 2)
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      //for password na field
                      TextField(
                        cursorColor: Color(0xFF1D5A71),
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: TextStyle(color: Color(0xFF1D5A71), fontWeight: FontWeight.bold),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: const BorderSide(color: Color(0XFF7AA9CA), width: 1),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF1D5A71), width: 2)
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      //login button
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFa5ceeb),
                                foregroundColor: const Color(0xFF006064),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size(200, 45),
                              ),
                              onPressed: _handleLogin,
                              child: const Text("Login",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                      
                      const SizedBox(height: 40),

                      //for sign up
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have account? ",
                          style: TextStyle(color: Color(0xFF006064),
                          fontWeight: FontWeight.bold)),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                              );
                            },
                            child: const Text(
                              "Sign up",
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
}