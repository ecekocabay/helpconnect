import 'package:flutter/material.dart';

class HelpSeekerHomeScreen extends StatelessWidget {
  const HelpSeekerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help Seeker Home"),
      ),
      body: const Center(
        child: Text(
          "Emergencies will appear here",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}