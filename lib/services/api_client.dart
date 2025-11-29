import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/emergency.dart';

class ApiClient {
  // TODO: if your Invoke URL changed, update here:
  static const String _baseUrl =
      'https://g0ul86kc5m.execute-api.eu-central-1.amazonaws.com';

  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// GET /emergencies
  Future<List<Emergency>> fetchEmergencies() async {
    final uri = Uri.parse('$_baseUrl/emergencies');

    final response = await _client.get(uri, headers: {
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

  /// POST /help-requests
  ///
  /// Returns the created requestId on success.
  Future<String> createHelpRequest({
    required String helpSeekerId,
    required String title,
    required String description,
    required String category,
    required String urgency,
    required String location,
    String? imageKey,
  }) async {
    final uri = Uri.parse('$_baseUrl/help-requests');

    final body = {
      'helpSeekerId': helpSeekerId,
      'title': title,
      'description': description,
      'category': category,
      'urgency': urgency,
      'location': location,
      'imageKey': imageKey,
    };

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to create help request (code ${response.statusCode})');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final String? requestId = data['requestId'] as String?;

    if (requestId == null) {
      throw Exception('createHelpRequest: response missing requestId');
    }

    return requestId;
  }
  /// GET /my-requests?helpSeekerId=...
  Future<List<Emergency>> fetchMyRequests(String helpSeekerId) async {
    final uri = Uri.parse(
      '$_baseUrl/my-requests?helpSeekerId=$helpSeekerId',
    );

    final response = await _client.get(uri, headers: {
      'Content-Type': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load my requests (code ${response.statusCode})');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List<dynamic> items = data['items'] ?? [];

    return items.map((item) => Emergency.fromJson(item)).toList();
  }
}