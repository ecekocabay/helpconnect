import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/emergency.dart';
import '../../services/api_client.dart';
import '../../widgets/emergency_card.dart';
import 'package:helpconnect/widgets/app_bar_buttons.dart';
import 'package:helpconnect/route_names.dart';

import 'request_detail_screen.dart';
import '../profile/profile_screen.dart';

class HelpSeekerHomeScreen extends StatefulWidget {
  const HelpSeekerHomeScreen({super.key});

  @override
  State<HelpSeekerHomeScreen> createState() => _HelpSeekerHomeScreenState();
}

class _HelpSeekerHomeScreenState extends State<HelpSeekerHomeScreen> {
  final ApiClient _apiClient = ApiClient();
  List<Emergency> _items = [];
  bool _loading = false;
  // Map state
  double _centerLat = 35.1856;
  double _centerLng = 33.3823;
  GoogleMapController? _mapController;

  Set<Marker> get _markers {
    return _items.where((e) => e.latitude != null && e.longitude != null).map((e) {
      final lat = e.latitude ?? _centerLat;
      final lng = e.longitude ?? _centerLng;
      return Marker(
        markerId: MarkerId(e.id),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(title: e.title.isEmpty ? 'Request' : e.title, snippet: e.description),
        onTap: () => _openDetail(e),
      );
    }).toSet();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final data = await _apiClient.fetchEmergencies();
      if (!mounted) return;
      // Filter out CLOSED requests - they can be viewed in "My Requests"
      final activeOnly = data.where((e) => e.status.toUpperCase() != 'CLOSED').toList();
      setState(() => _items = activeOnly);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchRole() {
    Navigator.pushReplacementNamed(context, RouteNames.roleSelection);
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(roleLabel: 'Seeker'),
      ),
    );
  }

  Future<void> _openCreateRequest() async {
    // Uses routes.dart mapping -> CreateRequestScreen
    final result = await Navigator.pushNamed(context, RouteNames.createRequest);

    // If create screen returns true/anything, refresh list
    if (!mounted) return;
    if (result != null) {
      await _load();
    } else {
      // Even if result is null, still refresh (safe)
      await _load();
    }
  }

  void _openDetail(Emergency e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(emergency: e),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: standardAppBar(
        title: 'Home',
        actions: [
          appBarTextButton(
            label: 'Switch Role',
            onPressed: _switchRole,
          ),
          appBarTextButton(
            label: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
          appBarTextButton(
            label: 'My Requests',
            onPressed: () => Navigator.pushNamed(context, RouteNames.myRequests),
          ),
          appBarTextButton(
            label: 'Profile',
            onPressed: _openProfile,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Map area
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: _items.where((e) => e.latitude != null && e.longitude != null).isEmpty
                        ? const Center(child: Text('No requests with location to show.'))
                        : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(_centerLat, _centerLng),
                              zoom: 12,
                            ),
                            markers: _markers,
                            myLocationEnabled: true,
                            onMapCreated: (c) {
                              _mapController = c;
                              final withLoc = _items.where((e) => e.latitude != null && e.longitude != null).toList();
                              if (withLoc.isNotEmpty) {
                                final first = withLoc.first;
                                _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(first.latitude!, first.longitude!), 13));
                              }
                            },
                          ),
                  ),
                ),

                // List below map
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Text(
                            'No help requests yet.\nCreate one using the button below.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          itemBuilder: (_, i) => EmergencyCard(
                            emergency: _items[i],
                            onTap: () => _openDetail(_items[i]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateRequest,
        label: const Text('New Request'),
      ),
    );
  }
}