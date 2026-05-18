class LeetCodeStatus {
  final String status;
  final bool goalMet;
  final DateTime fetchedAt;
  final DateTime serverTime;
  final DateTime deadline;
  final LeetCodeProgress progress;
  final LeetCodeGoals goals;
  final LeetCodeEnforcer enforcer;
  final List<Map<String, dynamic>> problems;
  final Map<String, dynamic>? profile;

  const LeetCodeStatus({
    required this.status,
    required this.goalMet,
    required this.fetchedAt,
    required this.serverTime,
    required this.deadline,
    required this.progress,
    required this.goals,
    required this.enforcer,
    required this.problems,
    required this.profile,
  });

  factory LeetCodeStatus.fromJson(Map<String, dynamic> json) {
    return LeetCodeStatus(
      status: json['status']?.toString() ?? 'unknown',
      goalMet: json['goalMet'] == true,
      fetchedAt: _readDateTime(json['fetchedAt']),
      serverTime: _readDateTime(json['serverTime']),
      deadline: _readDateTime(json['deadline']),
      progress: LeetCodeProgress.fromJson(
        _readMap(json['progress']),
      ),
      goals: LeetCodeGoals.fromJson(
        _readMap(json['goals']),
      ),
      enforcer: LeetCodeEnforcer.fromJson(
        _readMap(json['enforcer']),
      ),
      problems: _readListOfMaps(json['problems']),
      profile: json['profile'] is Map<String, dynamic>
          ? json['profile'] as Map<String, dynamic>
          : null,
    );
  }
}

class LeetCodeProgress {
  final int uniqueProblems;
  final int totalSubmissions;
  final int acceptedProblems;
  final int problemsLeft;
  final int submissionsLeft;

  const LeetCodeProgress({
    required this.uniqueProblems,
    required this.totalSubmissions,
    required this.acceptedProblems,
    required this.problemsLeft,
    required this.submissionsLeft,
  });

  factory LeetCodeProgress.fromJson(Map<String, dynamic> json) {
    return LeetCodeProgress(
      uniqueProblems: _readInt(json['uniqueProblems']),
      totalSubmissions: _readInt(json['totalSubmissions']),
      acceptedProblems: _readInt(json['acceptedProblems']),
      problemsLeft: _readInt(json['problemsLeft']),
      submissionsLeft: _readInt(json['submissionsLeft']),
    );
  }
}

class LeetCodeGoals {
  final int uniqueProblems;
  final int totalSubmissions;
  final int deadlineHour;

  const LeetCodeGoals({
    required this.uniqueProblems,
    required this.totalSubmissions,
    required this.deadlineHour,
  });

  factory LeetCodeGoals.fromJson(Map<String, dynamic> json) {
    return LeetCodeGoals(
      uniqueProblems: _readInt(json['uniqueProblems']),
      totalSubmissions: _readInt(json['totalSubmissions']),
      deadlineHour: _readInt(json['deadlineHour']),
    );
  }
}

class LeetCodeEnforcer {
  final String phase;
  final int hoursLeft;
  final int minutesLeft;
  final bool pastDeadline;
  final int remindersSentToday;
  final DateTime? lastReminderAt;

  const LeetCodeEnforcer({
    required this.phase,
    required this.hoursLeft,
    required this.minutesLeft,
    required this.pastDeadline,
    required this.remindersSentToday,
    required this.lastReminderAt,
  });

  factory LeetCodeEnforcer.fromJson(Map<String, dynamic> json) {
    return LeetCodeEnforcer(
      phase: json['phase']?.toString() ?? 'unknown',
      hoursLeft: _readInt(json['hoursLeft']),
      minutesLeft: _readInt(json['minutesLeft']),
      pastDeadline: json['pastDeadline'] == true,
      remindersSentToday: _readInt(json['remindersSentToday']),
      lastReminderAt: _readNullableDateTime(json['lastReminderAt']),
    );
  }
}

DateTime _readDateTime(dynamic value) {
  final parsed = _readNullableDateTime(value);
  if (parsed == null) {
    throw const FormatException('Missing date');
  }
  return parsed;
}

DateTime? _readNullableDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return null;
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _readListOfMaps(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map(
        (item) => item.map(
          (key, entry) => MapEntry(key.toString(), entry),
        ),
      )
      .toList(growable: false);
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
