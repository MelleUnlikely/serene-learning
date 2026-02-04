import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentPerformanceScreen extends StatefulWidget{
  final int classId;

  const StudentPerformanceScreen({super.key, required this.classId});

  @override
  State<StudentPerformanceScreen> createState() => _StudentPerformanceScreenState();
}

class _StudentPerformanceScreenState extends State<StudentPerformanceScreen>{
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "Student Performance Analytics",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D5A71),
            ),
          ),
        ),
        
        // This is where your charts or student list will go
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.analytics_outlined, size: 80, color: Colors.black12),
                const SizedBox(height: 10),
                Text(
                  "Displaying performance for Class ID: ${widget.classId}",
                  style: const TextStyle(color: Colors.grey),
                ),
                const Text("Fetch your Supabase data here!"),
              ],
            ),
          ),
        ),
      ],
    );
  }
}