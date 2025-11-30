import 'package:flutter/material.dart';
import '../../models/emergency.dart';
import '../help_seeker/request_detail_screen.dart';
import '../../widgets/emergency_card.dart';
import '../../services/api_client.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  final ApiClient _apiClient = ApiClient();

  // Data
  List<Emergency> _allEmergencies = [];
  bool _isLoading = false;
  String? _errorMessage;

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
  void initState() {
    super.initState();
    _loadEmergencies();
  }

  Future<void> _loadEmergencies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _apiClient.fetchEmergencies();
      setState(() {
        _allEmergencies = items;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load emergencies: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergencies = _filteredEmergencies;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer – Emergencies Near You'),
        actions: [
          TextButton(
            onPressed: _loadEmergencies,
            child: const Text(
              'Refresh',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : emergencies.isEmpty
                        ? const Center(
                            child: Text(
                              'No emergencies match your filters.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: emergencies.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final e = emergencies[index];
                              return EmergencyCard(
                                emergency: e,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RequestDetailScreen(
                                        emergency: e,
                                        showVolunteerActions: true,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}