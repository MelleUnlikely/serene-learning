import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'registration_screen.dart'; 
import '../teacher/class_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final bool _isLoading = false;

Future<void> _handleLogin() async {
  try {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (response.user != null) {
      // Fetch the role and school info
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
      } else if (userData['roletype'] == 'School Administrator') {
      }
    }
  } catch (e) {
    _showSnackBar("Login Failed: $e", Colors.red);
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
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                //logo muna
                Image.asset(
                  "assets/images/logo.png",
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 25),//parang gap
                
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
                      const SizedBox(height: 40),
                      
                      //for username field
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "Username",
                          labelStyle: TextStyle(color: Color(0xFF1D5A71), fontWeight: FontWeight.bold),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0XFF7AA9CA), width: 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      //for password na field
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Password",
                          labelStyle: TextStyle(color: Color(0xFF1D5A71), fontWeight: FontWeight.bold),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0XFF7AA9CA), width: 1),
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