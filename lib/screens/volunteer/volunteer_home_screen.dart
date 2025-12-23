import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/emergency.dart';
import '../../services/api_client.dart';
import '../../widgets/emergency_card.dart';
import 'package:helpconnect/widgets/app_bar_buttons.dart';
import '../profile/profile_screen.dart';
import '../help_seeker/request_detail_screen.dart';
import 'package:helpconnect/route_names.dart';
import 'my_offers_screen.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  final ApiClient _apiClient = ApiClient();

  List<Emergency> _items = [];
  bool _loading = false;
  String? _error;

  bool _locationEnabled = false;
  double _radiusKm = 10;

  // Map disabled for now (Google Maps removed). Keep fallback center coordinates
  double _centerLat = 35.1856;
  double _centerLng = 33.3823;

  @override
  void initState() {
    super.initState();
    _loadNearby();
  }

  Future<Position?> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _loadNearby() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pos = await _getLocation();

      if (pos == null) {
        // fallback to all emergencies
        final data = await _apiClient.fetchEmergencies();
        if (!mounted) return;
        // Filter out CLOSED requests
        final activeOnly = data.where((e) => e.status.toUpperCase() != 'CLOSED').toList();
        setState(() {
          _locationEnabled = false;
          _items = activeOnly;
        });
        return;
      }

      final data = await _apiClient.fetchNearbyEmergencies(
        lat: pos.latitude,
        lng: pos.longitude,
        radiusKm: _radiusKm,
      );

      if (!mounted) return;
      // Filter out CLOSED requests
      final activeOnly = data.where((e) => e.status.toUpperCase() != 'CLOSED').toList();
      setState(() {
        _locationEnabled = true;
        _items = activeOnly;
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
      });
    } catch (e) {
      // fallback to all emergencies
      try {
        final data = await _apiClient.fetchEmergencies();
        if (!mounted) return;
        // Filter out CLOSED requests
        final activeOnly = data.where((e) => e.status.toUpperCase() != 'CLOSED').toList();
        setState(() {
          _locationEnabled = false;
          _items = activeOnly;
          _error = 'Nearby failed, showing all: $e';
        });
      } catch (e2) {
        if (!mounted) return;
        setState(() => _error = 'Failed to load emergencies: $e2');
      }
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Emergency> get _withLocation =>
      _items.where((e) => e.latitude != null && e.longitude != null).toList();

  GoogleMapController? _mapController;
  Set<Marker> get _markers {
    return _withLocation.map((e) {
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

  void _switchRole() {
    Navigator.pushReplacementNamed(context, RouteNames.roleSelection);
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen(roleLabel: 'Volunteer')),
    );
  }

  void _openMyOffers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyOffersScreen()),
    );
  }

  void _openDetail(Emergency e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(
          emergency: e,
          showVolunteerActions: true,
        ),
      ),
    );
  }

  Future<void> _changeRadius(double km) async {
    setState(() => _radiusKm = km);
    await _loadNearby();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _locationEnabled
        ? 'Nearby emergencies (radius ${_radiusKm.toStringAsFixed(0)} km)'
        : 'All emergencies (location not used)';

    final mapItems = _withLocation;

    return Scaffold(
      appBar: standardAppBar(
        title: 'Home',
        actions: [
          appBarTextButton(label: 'Switch Role', onPressed: _switchRole),
          appBarTextButton(label: 'My Offers', onPressed: _openMyOffers),
          appBarTextButton(
            label: 'Refresh',
            onPressed: _loading ? null : _loadNearby,
          ),
          appBarTextButton(label: 'Profile', onPressed: _openProfile),
        ],
      ),
      body: Column(
        children: [
          // Top controls (labels only)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _loading ? null : () => _changeRadius(5),
                      child: const Text('Radius 5 km'),
                    ),
                    OutlinedButton(
                      onPressed: _loading ? null : () => _changeRadius(10),
                      child: const Text('Radius 10 km'),
                    ),
                    OutlinedButton(
                      onPressed: _loading ? null : () => _changeRadius(20),
                      child: const Text('Radius 20 km'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),

          // Map area: Google Map displaying nearby requests as markers.
          SizedBox(
            height: 260,
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: mapItems.isEmpty
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
                        if (_withLocation.isNotEmpty) {
                          final first = _withLocation.first;
                          final lat = first.latitude ?? _centerLat;
                          final lng = first.longitude ?? _centerLng;
                          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 13));
                        }
                      },
                    ),
            ),
          ),

          // List below map
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(
                        child: Text(
                          'No emergencies available right now.',
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
    );
  }
}