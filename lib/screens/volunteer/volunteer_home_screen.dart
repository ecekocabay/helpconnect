import 'package:flutter/material.dart';
import '../../models/emergency.dart';
import '../help_seeker/request_detail_screen.dart';
import '../../widgets/emergency_card.dart';
import '../profile/profile_screen.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  int _currentIndex = 0;

  // Mock data – same style as Help Seeker
  final List<Emergency> _allEmergencies = [
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
      title: 'Flooded Basement Help',
      description: 'Small basement flooding after heavy rain. Need pumps and help.',
      category: 'Environmental',
      urgency: 'Medium',
      location: 'Riverside District',
    ),
    Emergency(
      id: '4',
      title: 'Help with Groceries',
      description: 'Elderly neighbor needs help carrying groceries upstairs.',
      category: 'Daily Support',
      urgency: 'Low',
      location: 'Block A Apartments',
    ),
  ];

  // Filters
  String _selectedCategory = 'All';
  String _selectedUrgency = 'All';

  List<String> get _categories => const [
        'All',
        'Medical',
        'Missing Pet',
        'Environmental',
        'Daily Support',
      ];

  List<String> get _urgencies => const [
        'All',
        'Low',
        'Medium',
        'High',
      ];

  List<Emergency> get _filteredEmergencies {
    return _allEmergencies.where((e) {
      final matchesCategory =
          _selectedCategory == 'All' || e.category == _selectedCategory;
      final matchesUrgency =
          _selectedUrgency == 'All' || e.urgency == _selectedUrgency;
      return matchesCategory && matchesUrgency;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final emergencies = _filteredEmergencies;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer – Emergencies Near You'),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by Category',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Filter by Urgency',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: _urgencies.map((urg) {
                    final isSelected = _selectedUrgency == urg;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(urg),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedUrgency = urg);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(),
          // List
          Expanded(
            child: emergencies.isEmpty
                ? const Center(
                    child: Text(
                      'No emergencies match your filters.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: emergencies.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final e = emergencies[index];
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
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);

          if (index == 0) {
            // Emergencies – already here
          } else if (index == 1) {
            // Profile
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const ProfileScreen(roleLabel: 'Volunteer'),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber),
            label: 'Emergencies',
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