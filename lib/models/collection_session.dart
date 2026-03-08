class CollectionSession {
  final String sessionId;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final int totalSamples;
  final Map<String, dynamic> metadata;

  const CollectionSession({
    required this.sessionId,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.status,
    this.totalSamples = 0,
    required this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'status': status,
      'totalSamples': totalSamples,
      'metadata': metadata,
    };
  }

  factory CollectionSession.fromMap(Map<String, dynamic> map) {
    return CollectionSession(
      sessionId: map['sessionId'] ?? '',
      userId: map['userId'] ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] ?? 0),
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'])
          : null,
      status: map['status'] ?? 'started',
      totalSamples: map['totalSamples'] ?? 0,
      metadata: map['metadata'] ?? {},
    );
  }

  CollectionSession copyWith({
    String? sessionId,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    int? totalSamples,
    Map<String, dynamic>? metadata,
  }) {
    return CollectionSession(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      totalSamples: totalSamples ?? this.totalSamples,
      metadata: metadata ?? this.metadata,
    );
  }
}
