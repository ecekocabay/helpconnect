import 'package:flutter/material.dart';
import '../../models/emergency.dart';
import '../../routes.dart';
import 'create_request_screen.dart';
import 'request_detail_screen.dart';
import '../../widgets/emergency_card.dart';
import '../profile/profile_screen.dart';

class HelpSeekerHomeScreen extends StatefulWidget {
  const HelpSeekerHomeScreen({super.key});

  @override
  State<HelpSeekerHomeScreen> createState() => _HelpSeekerHomeScreenState();
}

class _HelpSeekerHomeScreenState extends State<HelpSeekerHomeScreen> {
  int _currentIndex = 0;

  // Mock data for now – later this will come from backend
  final List<Emergency> _emergencies = [
    Emergency(
      id: '1',
      title: 'Urgent Blood Donation Needed',
      description: 'O+ blood required within 4 hours at City Hospital.',
      category: 'Medical',
      urgency: 'High',
      location: 'City Hospital',
    ),
    Emergency(
      id: '2',
      title: 'Missing Dog in Neighborhood',
      description: 'Golden retriever missing near Park Street since morning.',
      category: 'Missing Pet',
      urgency: 'Medium',
      location: 'Park Street',
    ),
    Emergency(
      id: '3',
      title: 'Help with Groceries',
      description: 'Elderly neighbor needs help carrying groceries upstairs.',
      category: 'Daily Support',
      urgency: 'Low',
      location: 'Block A Apartments',
    ),
  ];

  Future<void> _openCreateRequest() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateRequestScreen(),
      ),
    );
    // Later: refresh list from backend after returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Seeker – Active Emergencies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'My Requests',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.myRequests);
            },
          ),
        ],
      ),
      body: _emergencies.isEmpty
          ? const Center(
              child: Text(
                'No emergencies yet.\nCreate your first Help Request.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _emergencies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final e = _emergencies[index];
                return EmergencyCard(
                  emergency: e,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestDetailScreen(emergency: e),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateRequest,
        icon: const Icon(Icons.add),
        label: const Text('New Help Request'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);

          if (index == 0) {
            // Home – already here
          } else if (index == 1) {
            // My Requests
            Navigator.pushNamed(context, AppRoutes.myRequests);
          } else if (index == 2) {
            // Profile
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const ProfileScreen(roleLabel: 'Help Seeker'),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'My Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}