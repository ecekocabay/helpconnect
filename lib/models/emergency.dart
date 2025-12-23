class Emergency {
  final String id;
  final String title;
  final String description;
  final String category;
  final String urgency;
  final String location;
  
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  /// OPEN | IN_PROGRESS | COMPLETED (or CLOSED if you use that)
  final String status;

  /// Cognito sub
  final String helpSeekerId;

  final String? acceptedOfferId;
  final String? acceptedVolunteerId;

  final String? createdAt;

  Emergency({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    required this.location,
    required this.status,
    required this.helpSeekerId,
    this.acceptedOfferId,
    this.acceptedVolunteerId,
    this.createdAt,
    this.latitude,
    this.longitude,
    this.distanceKm,
  });

  factory Emergency.fromJson(Map<String, dynamic> json) {
    return Emergency(
      id: (json['request_id'] ?? json['id']) as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      urgency: json['urgency'] as String? ?? '',
      location: json['location'] as String? ?? '',
      status: (json['status'] ?? 'OPEN') as String,
      helpSeekerId:
          (json['help_seeker_id'] ?? json['helpSeekerId'] ?? '') as String,
      acceptedOfferId:
          (json['accepted_offer_id'] ?? json['acceptedOfferId']) as String?,
      acceptedVolunteerId:
          (json['accepted_volunteer_id'] ?? json['acceptedVolunteerId'])
              as String?,
      createdAt: (json['created_at'] ?? json['createdAt']) as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': id,
      'title': title,
      'description': description,
      'category': category,
      'urgency': urgency,
      'location': location,
      'status': status,
      'help_seeker_id': helpSeekerId,
      if (acceptedOfferId != null) 'accepted_offer_id': acceptedOfferId,
      if (acceptedVolunteerId != null)
        'accepted_volunteer_id': acceptedVolunteerId,
      if (createdAt != null) 'created_at': createdAt,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (distanceKm != null) 'distanceKm': distanceKm,
    };
  }

  bool get isOpen => status.trim().toUpperCase() == 'OPEN';
  bool get isInProgress => status.trim().toUpperCase() == 'IN_PROGRESS';
  bool get isCompleted =>
      status.trim().toUpperCase() == 'COMPLETED' ||
      status.trim().toUpperCase() == 'CLOSED';
}