class Offer {
  final String offerId;
  final String requestId;
  final String volunteerId;
  final String? note;
  final int? estimatedArrivalMinutes;
  final String? status;
  final String? createdAt;

  Offer({
    required this.offerId,
    required this.requestId,
    required this.volunteerId,
    this.note,
    this.estimatedArrivalMinutes,
    this.status,
    this.createdAt,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      offerId: (json['offer_id'] ?? json['offerId'] ?? '') as String,
      requestId: (json['request_id'] ?? json['requestId'] ?? '') as String,
      volunteerId:
          (json['volunteer_id'] ?? json['volunteerId'] ?? '') as String,
      note: json['note'] as String?,
      estimatedArrivalMinutes:
          json['estimated_arrival_minutes'] is int
              ? json['estimated_arrival_minutes'] as int
              : json['estimated_arrival_minutes'] is String
                  ? int.tryParse(
                      json['estimated_arrival_minutes'] as String)
                  : null,
      status: json['status'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}