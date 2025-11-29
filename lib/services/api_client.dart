import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/emergency.dart';

class ApiClient {
  // TODO: replace with your own Invoke URL if it's different
  static const String _baseUrl =
      'https://g0ul86kc5m.execute-api.eu-central-1.amazonaws.com';

  // GET /emergencies
  Future<List<Emergency>> fetchEmergencies() async {
    final uri = Uri.parse('$_baseUrl/emergencies');

    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load emergencies (code ${response.statusCode})');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List<dynamic> items = data['items'] ?? [];

    return items.map((item) => Emergency.fromJson(item)).toList();
  }

  // later we can add:
  // Future<List<Emergency>> fetchMyRequests(String helpSeekerId) async {...}
  // Future<Emergency> fetchRequestDetail(String id) async {...}
  // Future<void> createHelpRequest(...) async {...}
}