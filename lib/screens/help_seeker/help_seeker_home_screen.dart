import 'package:flutter/material.dart';

import '../../models/emergency.dart';
import '../../routes.dart';
import 'create_request_screen.dart';
import 'request_detail_screen.dart';
import '../../widgets/emergency_card.dart';
import '../profile/profile_screen.dart';
import '../../services/api_client.dart';

class HelpSeekerHomeScreen extends StatefulWidget {
  const HelpSeekerHomeScreen({super.key});

  @override
  State<HelpSeekerHomeScreen> createState() => _HelpSeekerHomeScreenState();
}

class _HelpSeekerHomeScreenState extends State<HelpSeekerHomeScreen> {
  final ApiClient _apiClient = ApiClient();

  int _currentIndex = 0;

  // Data from backend
  List<Emergency> _emergencies = [];
  bool _isLoading = false;
  String? _errorMessage;

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
      // For now Help Seeker home shows the same public feed as Volunteer.
      final items = await _apiClient.fetchEmergencies();
      setState(() {
        _emergencies = items;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load emergencies: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openCreateRequest() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateRequestScreen(),
      ),
    );
    // After creating a request, refresh the list
    await _loadEmergencies();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Seeker – Active Emergencies'),
        actions: [
          TextButton(
            onPressed: _loadEmergencies,
            child: const Text(
              'Refresh',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.myRequests);
            },
            child: const Text(
              'My Requests',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.redAccent),
                    ),
                  ),
                )
              : _emergencies.isEmpty
                  ? const Center(
                      child: Text(
                        'No emergencies yet.\nCreate your first Help Request.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _emergencies.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final e = _emergencies[index];
                        return EmergencyCard(
                          emergency: e,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RequestDetailScreen(
                                  emergency: e,
                                  showVolunteerActions:
                                      false, // Help Seeker: read-only
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateRequest,
        // no icon – text only
        label: const Text('New Help Request'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);

          if (index == 0) {
            // Home – already here
          } else if (index == 1) {
            Navigator.pushNamed(context, AppRoutes.myRequests);
          } else if (index == 2) {
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
            // no icon, empty box instead
            icon: SizedBox.shrink(),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: SizedBox.shrink(),
            label: 'My Requests',
          ),
          BottomNavigationBarItem(
            icon: SizedBox.shrink(),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}