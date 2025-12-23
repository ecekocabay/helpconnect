import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/offer.dart';
import '../models/emergency.dart';
import 'auth_service.dart';

class ApiClient {
  // ✅ Main (user/volunteer) API
  static const String _baseUrl =
      'https://g0ul86kc5m.execute-api.eu-central-1.amazonaws.com/prod';

  // ✅ Admin API (HelpConnectAdmin)
  // IMPORTANT: replace this with the real invoke URL for HelpConnectAdmin.
  // Example:
  // https://abcd1234.execute-api.eu-central-1.amazonaws.com/prod
  static const String _adminBaseUrl =
      'https://75qmsmgsj2.execute-api.eu-central-1.amazonaws.com/prod';

  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  // -------------------------
  // Emergencies
  // -------------------------

  Future<List<Emergency>> fetchEmergencies() async {
    final uri = Uri.parse('$_baseUrl/emergencies');
    final response = await _client.get(uri, headers: await _headers());

    if (response.statusCode != 200) {
      throw Exception(
        'fetchEmergencies failed (code ${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final Map<String, dynamic> data =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    final List<dynamic> items = (data['items'] as List?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Emergency.fromJson)
        .toList();
  }

  Future<List<Emergency>> fetchNearbyEmergencies({
    required double lat,
    required double lng,
    double radiusKm = 10,
  }) async {
    final uri = Uri.parse('$_baseUrl/emergencies/nearby').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radiusKm': radiusKm.toString(),
      },
    );

    final response = await _client.get(uri, headers: await _headers());

    if (response.statusCode != 200) {
      throw Exception(
          'fetchNearbyEmergencies failed: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (decoded['items'] as List?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Emergency.fromJson)
        .toList();
  }

  Future<Emergency> getHelpRequest(String requestId) async {
    final uri = Uri.parse('$_baseUrl/help-requests/$requestId');
    final response = await _client.get(uri, headers: await _headers());

    if (response.statusCode != 200) {
      throw Exception(
        'getHelpRequest failed (code ${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('getHelpRequest: invalid response body');
    }

    return Emergency.fromJson(decoded);
  }

  // -------------------------
  // Help Seeker
  // -------------------------

  Future<String> createHelpRequest({
    required String title,
    required String description,
    required String category,
    required String urgency,
    required String location,
    double? latitude,
    double? longitude,
    String? imageKey,
  }) async {
    final uri = Uri.parse('$_baseUrl/help-requests');

    final body = {
      'title': title,
      'description': description,
      'category': category,
      'urgency': urgency,
      'location': location,
      'imageKey': imageKey,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };

    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'createHelpRequest failed (code ${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('createHelpRequest: invalid response body');
    }

    final requestId =
        (decoded['requestId'] ?? decoded['request_id']) as String?;
    if (requestId == null || requestId.isEmpty) {
      throw Exception('createHelpRequest: response missing requestId');
    }

    return requestId;
  }

  Future<List<Emergency>> fetchMyRequests() async {
    final uri = Uri.parse('$_baseUrl/my-requests');
    final response = await _client.get(uri, headers: await _headers());

    if (response.statusCode != 200) {
      throw Exception(
        'fetchMyRequests failed (code ${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final Map<String, dynamic> data =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    final List<dynamic> items = (data['items'] as List?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Emergency.fromJson)
        .toList();
  }

  Future<List<Offer>> fetchMyOffers() async {
    final uri = Uri.parse('$_baseUrl/my-offers');
    final response = await _client.get(uri, headers: await _headers());

    if (response.statusCode != 200) {
      throw Exception(
        'fetchMyOffers failed (code ${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final Map<String, dynamic> data =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    final List<dynamic> items = (data['items'] as List?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Offer.fromJson)
        .toList();
  }

  // -------------------------
  // Offers
  // -------------------------

  Future<void> offerHelp({
    required String requestId,
    String? note,
    int? estimatedArrivalMinutes,
  }) async {
    final uri = Uri.parse('$_baseUrl/offers');

    final body = {
      'requestId': requestId,
      if (note != null) 'note': note,
      if (estimatedArrivalMinutes != null)
        'estimatedArrivalMinutes': estimatedArrivalMinutes,
    };

    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(
        'offerHelp failed (code ${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<List<Offer>> fetchOffersForRequest(String requestId) async {
    final uri = Uri.parse('$_baseUrl/offers').replace(
      queryParameters: {'requestId': requestId},
    );

    final response = await _client.get(uri, headers: await _headers());

    if (response.statusCode != 200) {
      throw Exception(
        'fetchOffersForRequest failed (code ${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    dynamic rawItems;
    if (decoded is Map<String, dynamic>) {
      rawItems = decoded['items'];
    } else {
      rawItems = decoded;
    }

    if (rawItems is! List) return [];

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(Offer.fromJson)
        .toList();
  }

  Future<void> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    final uri = Uri.parse('$_baseUrl/accept-offer');

    final body = {
      'requestId': requestId,
      'offerId': offerId,
    };

    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'acceptOffer failed (code ${response.statusCode}): ${response.body}',
      );
    }
  }

  // -------------------------
  // Close Request (PATCH)
  // -------------------------

  Future<void> closeRequest({required String requestId}) async {
    final uri = Uri.parse('$_baseUrl/help-requests/$requestId/close');

    final response = await _client.patch(
      uri,
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'closeRequest failed (code ${response.statusCode}): ${response.body}',
      );
    }
  }

  // -------------------------
  // Admin (HelpConnectAdmin API)
  // -------------------------

  Future<Map<String, dynamic>> adminInitialize() async {
    final uri = Uri.parse('$_adminBaseUrl/admin/initialize');
    final res = await _client.post(uri, headers: await _headers());
    return _decodeJsonOrThrow(res, 'adminInitialize');
  }

  Future<Map<String, dynamic>> adminReset() async {
    final uri = Uri.parse('$_adminBaseUrl/admin/reset');
    final res = await _client.post(uri, headers: await _headers());
    return _decodeJsonOrThrow(res, 'adminReset');
  }

  Future<Map<String, dynamic>> adminBackup() async {
    final uri = Uri.parse('$_adminBaseUrl/admin/backup');
    final res = await _client.post(uri, headers: await _headers());
    return _decodeJsonOrThrow(res, 'adminBackup');
  }

  Future<Map<String, dynamic>> adminView() async {
    final uri = Uri.parse('$_adminBaseUrl/admin/view');
    final res = await _client.get(uri, headers: await _headers());
    return _decodeJsonOrThrow(res, 'adminView');
  }

  Future<Map<String, dynamic>> adminModify(Map<String, dynamic> body) async {
  final uri = Uri.parse('$_adminBaseUrl/admin/modify');

  final res = await _client.patch(
    uri,
    headers: await _headers(),
    body: jsonEncode(body),
  );

  return _decodeJsonOrThrow(res, 'adminModify');
}

  Map<String, dynamic> _decodeJsonOrThrow(http.Response res, String opName) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$opName failed (code ${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'raw': decoded};
  }

  // -------------------------
  // Images
  // -------------------------

  Future<Map<String, dynamic>> getUploadUrl({
    required String requestId,
    required String contentType,
  }) async {
    final uri = Uri.parse('$_baseUrl/images/upload-url');

    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({
        'requestId': requestId,
        'request_id': requestId,
        'contentType': contentType,
        'content_type': contentType,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'getUploadUrl failed: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('getUploadUrl: invalid response body');
    }

    return decoded;
  }

  Future<void> uploadToS3Presigned({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    final res = await _client.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('S3 upload failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> attachImageToRequest({
    required String requestId,
    required String imageKey,
    required String imageId,
  }) async {
    final uri = Uri.parse('$_baseUrl/requests/$requestId/images');

    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({
        'imageKey': imageKey,
        'image_id': imageId,
        'imageId': imageId,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'attachImageToRequest failed (code ${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> listRequestImages({
    required String requestId,
  }) async {
    final uri = Uri.parse('$_baseUrl/requests/$requestId/images');

    final response = await _client.get(uri, headers: await _headers());

    if (response.statusCode != 200) {
      throw Exception(
        'listRequestImages failed (code ${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final items = decoded['images'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    }

    return [];
  }

  Future<String> getViewUrl({required String key}) async {
    final uri = Uri.parse('$_baseUrl/images/view-url')
        .replace(queryParameters: {'key': key});

    final res = await _client.get(uri, headers: await _headers());

    if (res.statusCode != 200) {
      throw Exception('getViewUrl failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('getViewUrl: invalid response body');
    }

    final viewUrl = decoded['viewUrl'] as String?;
    if (viewUrl == null || viewUrl.isEmpty) {
      throw Exception('getViewUrl: response missing viewUrl');
    }

    return viewUrl;
  }

  // -------------------------
  // Notification settings
  // -------------------------

  Future<bool> getNotificationEnabled() async {
    final uri = Uri.parse('$_baseUrl/notification-settings');
    final res = await _client.get(uri, headers: await _headers());

    if (res.statusCode != 200) {
      throw Exception(
          'getNotificationEnabled failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['notify_enabled'] as bool?) ?? true;
  }

  Future<void> setNotificationEnabled(bool enabled) async {
    final uri = Uri.parse('$_baseUrl/notification-settings');

    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({'notify_enabled': enabled}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'setNotificationEnabled failed (code ${response.statusCode}): ${response.body}');
    }
  }

  // -------------------------
  // Auth headers
  // -------------------------

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.instance.getAccessToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }
}