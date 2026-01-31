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
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              // --- THIS IS THE "BOX" FOR YOUR CONTENTS ---
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400), // Perfect for Web!
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9), // Makes the box stand out
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Shrinks box to fit content
                  children: [
                    const Text(
                      "Welcome Back",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _emailController, 
                      decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordController, 
                      decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()), 
                      obscureText: true,
                    ),
                    const SizedBox(height: 30),
                    
                    _isLoading 
                      ? const CircularProgressIndicator() 
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50), // Full width button
                          ),
                          onPressed: _handleLogin, 
                          child: const Text("Login"),
                        ),
                    
                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                        );
                      },
                      child: const Text("Don't have an account? Sign Up"),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}