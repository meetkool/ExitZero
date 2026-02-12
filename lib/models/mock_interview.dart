
class MockInterview {
  final String id;
  final String title;
  final String company;
  final String role; // e.g. 'SDE-1', 'Frontend', 'DevOps'
  final DateTime dateTime; // maps to start_time
  final int durationMinutes;
  final String platform; // 'Google Meet', 'Zoom', etc.
  final String? meetingLink;
  final String status; // 'scheduled', 'completed', 'missed', 'cancelled'
  final int stakeAmount;
  final bool isMock;
  final String? notes;
  final Set<String> reminders;
  final String timeZone;

  MockInterview({
    required this.id,
    required this.title,
    required this.company,
    required this.role,
    required this.dateTime,
    this.durationMinutes = 60,
    this.platform = 'Google Meet',
    this.meetingLink,
    required this.status,
    this.stakeAmount = 50,
    this.isMock = true,
    this.notes,
    required this.reminders,
    this.timeZone = 'UTC',
  });

  bool get isCompleted => status == 'completed';

  factory MockInterview.fromJson(Map<String, dynamic> json) {
    return MockInterview(
      id: json['id'] as String,
      title: json['title'] as String,
      company: json['company'] as String,
      role: json['role'] as String? ?? 'Candidate', // Default if missing
      dateTime: DateTime.parse(json['start_time'] as String).toLocal(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      platform: json['platform'] as String? ?? 'Google Meet',
      meetingLink: json['meeting_link'] as String?,
      status: json['status'] as String,
      stakeAmount: (json['stake_amount'] as num?)?.toInt() ?? 50,
      isMock: json['is_mock'] as bool? ?? true,
      notes: json['notes'] as String?,
      // Reminders might be a comma-separated string or list in backend? 
      // Based on description: "reminders" field exists. Typically JSON array or string.
      // Assuming JSON array of strings for now based on typical API design for list fields, 
      // but if it's a string, we'll parse it. Let's handle List<dynamic>.
      reminders: (json['reminders'] as List<dynamic>?)?.map((e) {
        final val = e as int;
        if (val == 1440) return '1 Day Before';
        if (val == 60) return '1 Hour Before';
        if (val == 15) return '15 Mins Before';
        return '$val Mins Before';
      }).toSet() ?? {},
      timeZone: json['time_zone'] as String? ?? 'UTC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, 
      'title': title,
      'company': company,
      'role': role,
      'start_time': dateTime.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'platform': platform,
      'meeting_link': meetingLink,
      'status': status,
      'stake_amount': stakeAmount,
      'is_mock': isMock,
      'notes': notes,
      'reminders': reminders.map((r) {
        if (r == '1 Day Before') return 1440;
        if (r == '1 Hour Before') return 60;
        if (r == '15 Mins Before') return 15;
        return 0; // fallback
      }).toList(),
      'time_zone': timeZone, // Backend handles timezone, defaults to UTC now explicit
    };
  }
  
  MockInterview copyWith({
      String? id,
      String? title,
      String? company,
      String? role,
      DateTime? dateTime,
      int? durationMinutes,
      String? platform,
      String? meetingLink,
      String? status,
      int? stakeAmount,
      bool? isMock,
      String? notes,
      Set<String>? reminders,
      String? timeZone,
  }) {
      return MockInterview(
          id: id ?? this.id,
          title: title ?? this.title,
          company: company ?? this.company,
          role: role ?? this.role,
          dateTime: dateTime ?? this.dateTime,
          durationMinutes: durationMinutes ?? this.durationMinutes,
          platform: platform ?? this.platform,
          meetingLink: meetingLink ?? this.meetingLink,
          status: status ?? this.status,
          stakeAmount: stakeAmount ?? this.stakeAmount,
          isMock: isMock ?? this.isMock,
          notes: notes ?? this.notes,
          reminders: reminders ?? this.reminders,
          timeZone: timeZone ?? this.timeZone,
      );
  }
}
