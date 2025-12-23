import 'package:flutter/material.dart';
import '../../models/emergency.dart';
import '../../services/api_client.dart';
import '../../widgets/emergency_card.dart';
import 'package:helpconnect/widgets/app_bar_buttons.dart';
import 'request_detail_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final ApiClient _apiClient = ApiClient();
  List<Emergency> _requests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _requests = await _apiClient.fetchMyRequests();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: standardAppBar(
        title: 'My Requests',
        actions: [
          appBarTextButton(label: 'Back', onPressed: () => Navigator.pop(context)),
          appBarTextButton(label: 'Refresh', onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _requests.length,
              itemBuilder: (_, i) => EmergencyCard(
                emergency: _requests[i],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RequestDetailScreen(emergency: _requests[i]),
                    ),
                  );
                },
              ),
            ),
    );
  }
}