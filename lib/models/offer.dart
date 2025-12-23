class Offer {
  final String offerId;
  final String requestId;
  final String volunteerId;

  // ✅ NEW
  final String? volunteerEmail;

  final String? note;
  final int? estimatedArrivalMinutes;
  final String? status;
  final String? createdAt;

  Offer({
    required this.offerId,
    required this.requestId,
    required this.volunteerId,
    this.volunteerEmail, // ✅ NEW
    this.note,
    this.estimatedArrivalMinutes,
    this.status,
    this.createdAt,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      offerId: (json['offer_id'] ?? json['offerId'] ?? '') as String,
      requestId: (json['request_id'] ?? json['requestId'] ?? '') as String,
      volunteerId: (json['volunteer_id'] ?? json['volunteerId'] ?? '') as String,

      // ✅ accepts either snake_case or camelCase, and older offers will be null
      volunteerEmail:
          (json['volunteer_email'] ?? json['volunteerEmail']) as String?,

      note: json['note'] as String?,
      estimatedArrivalMinutes: _parseInt(
        json['estimated_arrival_minutes'] ?? json['estimatedArrivalMinutes'],
      ),
      status: json['status'] as String?,
      createdAt: (json['created_at'] ?? json['createdAt']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'offer_id': offerId,
      'request_id': requestId,
      'volunteer_id': volunteerId,

      // ✅ only include if present
      if (volunteerEmail != null) 'volunteer_email': volunteerEmail,

      if (note != null) 'note': note,
      if (estimatedArrivalMinutes != null)
        'estimated_arrival_minutes': estimatedArrivalMinutes,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}