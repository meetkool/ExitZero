/// The widgets that ship inside the app.
///
/// The store lists these next to the ones downloaded from the inventory, so
/// "Widgets" means everything on the dashboard rather than only the remote
/// ones. They cannot be uninstalled — there is nothing to remove — but they
/// can be switched off, which takes them off the dashboard.
class BuiltInWidget {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String accent;

  const BuiltInWidget({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.accent,
  });
}

class BuiltInWidgets {
  BuiltInWidgets._();

  /// Ids here must match the [BentoGridItem] ids the dashboard builds.
  static const List<BuiltInWidget> all = [
    BuiltInWidget(
      id: 'notifications',
      name: 'Alerts',
      description: 'Latest notifications and system alerts.',
      icon: 'notifications',
      accent: '#3A86FF',
    ),
    BuiltInWidget(
      id: 'survival',
      name: 'Daily Survival',
      description: 'Your survival percentage and time remaining today.',
      icon: 'local_fire_department',
      accent: '#F77F00',
    ),
    BuiltInWidget(
      id: 'alarm_status',
      name: 'Alarm System',
      description: 'Whether the alarm is armed and waiting.',
      icon: 'alarm',
      accent: '#E75414',
    ),
    BuiltInWidget(
      id: 'leetcode',
      name: 'LeetCode Status',
      description: 'Submission streak and problem breakdown.',
      icon: 'code',
      accent: '#126782',
    ),
    BuiltInWidget(
      id: 'video-tile',
      name: 'Visualizer',
      description: 'Looping video tile.',
      icon: 'movie',
      accent: '#8338EC',
    ),
    BuiltInWidget(
      id: 'accountability',
      name: 'Accountability Engine',
      description: 'The countdown that keeps you honest.',
      icon: 'timeline',
      accent: '#E75414',
    ),
    BuiltInWidget(
      id: 'outreach',
      name: 'Outreach',
      description: 'Emails sent against your daily target.',
      icon: 'send',
      accent: '#126782',
    ),
    BuiltInWidget(
      id: 'life-score',
      name: 'Life Score',
      description: 'Total score and the next reward milestone.',
      icon: 'emoji_events',
      accent: '#FCBF49',
    ),
    BuiltInWidget(
      id: 'interviews',
      name: 'Interviews',
      description: 'Upcoming mock interviews.',
      icon: 'group',
      accent: '#F77F00',
    ),
    BuiltInWidget(
      id: 'logs',
      name: 'System Logs',
      description: 'Activity timeline for today and beyond.',
      icon: 'terminal',
      accent: '#126782',
    ),
  ];

  static BuiltInWidget? byId(String id) {
    for (final w in all) {
      if (w.id == id) return w;
    }
    return null;
  }
}
