import 'dart:convert';
import 'dart:async'; // For StreamSubscription
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/bento_grid.dart';
import 'dashboard/cards/daily_survival_card.dart';
import 'dashboard/cards/accountability_card.dart';
import 'dashboard/cards/leetcode_card.dart';
import 'dashboard/cards/outreach_card.dart';
import 'dashboard/cards/interviews_card.dart';
import 'dashboard/cards/system_logs.dart';
import 'dashboard/cards/video_tile_card.dart';
import 'dashboard/cards/life_score_card.dart';
import '../pages/profile_page.dart';
import '../../services/interview_service.dart';
import '../../models/mock_interview.dart';
import 'dashboard/cards/interviews_carousel.dart';
import 'package:intl/intl.dart';
import 'mock_interview_detail_page.dart'; // For navigation from modal
import '../models/app_notification.dart';
import '../services/notification_store.dart';
import '../services/ntfy_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/notification_manager.dart';
import 'notifications_page.dart';
import 'dashboard/cards/notification_card.dart';
import 'dashboard/cards/alarm_card.dart';
import 'package:alarm/alarm.dart';
import '../pages/alarm_page.dart';
/// Main dashboard screen — bento-grid layout with FAB.
///
/// Converts to "edit layout" mode when the user long-presses any card.
/// While editing, scrolling is disabled so pan gestures go to the grid.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _layoutStorageKey = 'bento_grid_layout_v1';



  /// True only while dragging/resizing (scroll temporarily disabled).
  bool _gridInteracting = false;

  /// Current layout state (order + size) for persistence.
  List<BentoGridLayoutItem> _layoutState = [];

  /// Forces BentoGrid to resync from new items (e.g. reset / load).
  int _layoutVersion = 0;

  final InterviewService _interviewService = InterviewService();
  List<MockInterview> _todaysInterviews = [];
  bool _isLoadingInterviews = true;
  StreamSubscription? _interviewSubscription;

  // Notification State
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    LocalNotificationService.initialize();
    NotificationManager().initialize();
    _loadLayout();
    _fetchTodaysInterviews();
    
    // Subscribe to global updates
    _interviewSubscription = InterviewService.onInterviewsUpdated.listen((_) {
      if (mounted) {
        _fetchTodaysInterviews();
      }
    });

    _notificationSubscription = NotificationManager().notificationsStream.listen((_) {
      if (mounted) {
        setState(() {
          _layoutVersion++;
        });
      }
    });
  }

  @override
  void dispose() {
    _interviewSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchTodaysInterviews() async {
    try {
      // Fetch all scheduled interviews instead of restricting to "today"
      // This ensures we show relevant upcoming data even if dates/timezones vary.
      final interviews = await _interviewService.getInterviews(status: 'scheduled');
      
      // Sort by date (soonest first)
      interviews.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      if (!mounted) return;
      setState(() {
        _todaysInterviews = interviews;
        _isLoadingInterviews = false;
        _layoutVersion++; // Force rebuild of grid items to pick up new data
      });
    } catch (e) {
      print('Error fetching interviews: $e');
      if (mounted) {
        setState(() => _isLoadingInterviews = false);
      }
    }
  }

  void _handleNotificationTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsPage(),
      ),
    ); 
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_layoutStorageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = decoded
          .whereType<Map>()
          .map((e) => BentoGridLayoutItem.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        _layoutState = loaded;
        _layoutVersion++;
      });
    } catch (_) {
      // Ignore malformed state and fall back to defaults.
    }
  }

  Future<void> _saveLayout() async {
    if (_layoutState.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_layoutState.map((e) => e.toJson()).toList());
    await prefs.setString(_layoutStorageKey, raw);
  }

  Future<void> _resetLayout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_layoutStorageKey);
    setState(() {
      _layoutState = [];
      _layoutVersion++;
    });
  }

  void _handleLayoutChanged(List<BentoGridLayoutItem> layout) {
    _layoutState = layout;
  }

  List<BentoGridItem> _defaultItems() {
    return [
      // Notifications
      BentoGridItem(
        id: 'notifications',
        columnSpan: 1,
        height: 140,
        minHeight: 120,
        maxHeight: 240,
        card: NotificationCard(
          notifications: NotificationManager().notifications,
          onTap: _handleNotificationTap,
        ),
      ),
      // Daily Survival
      const BentoGridItem(
        id: 'survival',
        columnSpan: 2,
        height: 140, // Updated height
        minHeight: 120,
        maxHeight: 240,
        card: DailySurvivalCard(
          percentage: 72,
          status: 'Safe',
          timeRemaining: '4 hrs remaining',
        ),
      ),

      // Alarm Status
      BentoGridItem(
        id: 'alarm_status',
        columnSpan: 2,
        height: 110,
        minHeight: 100,
        maxHeight: 160,
        card: AlarmCard(
          onTap: () async {
            // First check if an alarm is actively ringing
            final alarms = await Alarm.getAlarms();
            if (alarms.isNotEmpty) {
               Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AlarmPage(alarmId: alarms.first.id)),
               );
            } else {
               // If none ringing, show normal notifications page filtered to alarms
               Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (context) => const NotificationsPage(filterTag: 'alarm'),
                 ),
               );
            }
          },
        ),
      ),

      // LeetCode (left)
      BentoGridItem(
        id: 'leetcode',
        columnSpan: 1,
        height: 150,
        minHeight: 100,
        maxHeight: 220,
        card: LeetCodeCard(
          submissions: 0,
          target: 1,
          onRefresh: () {},
        ),
      ),
      
      // Video Tile (right)
      const BentoGridItem(
        id: 'video-tile',
        columnSpan: 1,
        height: 150,
        minHeight: 120,
        maxHeight: 240,
        card: VideoTileCard(
          videoSource: 'assets/joji_visualizer.mp4',
          isAsset: true,
          isLive: false,
          showInfo: false,
        ),
      ),
      
      // Accountability Engine
      const BentoGridItem(
        id: 'accountability',
        columnSpan: 2,
        height: 100,
        minHeight: 80,
        maxHeight: 160,
        card: AccountabilityCard(),
      ),

      // Outreach (half width)
      const BentoGridItem(
        id: 'outreach',
        columnSpan: 1,
        height: 120, // Updated height
        minHeight: 100,
        maxHeight: 220,
        card: OutreachCard(sent: 2, total: 5),
      ),

      // Life Score (half width, next to Outreach)
      const BentoGridItem(
        id: 'life-score',
        columnSpan: 1,
        height: 120, // Updated height
        minHeight: 100,
        maxHeight: 220,
        card: LifeScoreCard(
          score: 450,
          nextRewardAt: 500,
        ),
      ),

      // Interviews (Carousel)
      BentoGridItem(
        id: 'interviews',
        columnSpan: 2,
        height: 90, // Updated height
        minHeight: 80,
        maxHeight: 160,
        card: InterviewsCarousel(
          interviews: _todaysInterviews,
          onSeeAll: () => _showTodaysInterviewsModal(context),
        ),
      ),

      // System Logs
      const BentoGridItem(
        id: 'logs',
        columnSpan: 2,
        height: 260,
        minHeight: 180,
        maxHeight: 400,
        card: SystemLogs(
          entries: [
            LogEntry(
              message: 'System armed.',
              time: '10:00 AM',
              isActive: true,
            ),
            LogEntry(
              message: 'Waiting for submissions...',
              time: 'Now',
            ),
          ],
        ),
      ),
    ];
  }

  // ... (keeping _buildItems and _applyLayout as they are, no changes needed there conceptually, just reusing existing logic)

  List<BentoGridItem> _buildItems() {
    final defaults = _defaultItems();
    if (_layoutState.isEmpty) return defaults;

    final byId = {for (final item in defaults) item.id: item};
    final used = <String>{};
    final items = <BentoGridItem>[];

    for (final saved in _layoutState) {
      final base = byId[saved.id];
      if (base == null) continue;
      used.add(saved.id);
      items.add(_applyLayout(base, saved));
    }

    for (final base in defaults) {
      if (!used.contains(base.id)) {
        items.add(base);
      }
    }

    return items;
  }

  BentoGridItem _applyLayout(
    BentoGridItem base,
    BentoGridLayoutItem saved,
  ) {
    final span = saved.columnSpan.clamp(base.minSpan, base.maxSpan).toInt();
    final height = saved.height.clamp(base.minHeight, base.maxHeight);
    return BentoGridItem(
      id: base.id,
      columnSpan: span,
      minSpan: base.minSpan,
      maxSpan: base.maxSpan,
      height: height,
      minHeight: base.minHeight,
      maxHeight: base.maxHeight,
      resizable: base.resizable,
      card: base.card,
    );
  }

  void _showActionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          // Correct modal styling from HTML
          decoration: BoxDecoration(
            color: const Color(0xFF001e2e).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               // Handle
               Container(
                 width: 40,
                 height: 4,
                 decoration: BoxDecoration(
                   color: Colors.white.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(2),
                 ),
                 margin: const EdgeInsets.only(bottom: 24),
               ),
               
               // Title
               Text(
                 'LOG ACTIVITY',
                 style: TextStyle(
                   color: AppColors.cream.withValues(alpha: 0.6),
                   fontSize: 14,
                   fontWeight: FontWeight.bold,
                   letterSpacing: 1.0,
                 ),
               ),
               const SizedBox(height: 32),

               // Grid Buttons
               Row(
                 children: [
                   Expanded(
                     child: _buildModalButton(
                       icon: Icons.send,
                       color: AppColors.orange,
                       label: 'Log Outreach',
                       onTap: () {},
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: _buildModalButton(
                       icon: Icons.calendar_month,
                       color: AppColors.teal,
                       label: 'Schedule Mock',
                       onTap: () async {
                         Navigator.pop(context);
                         await Navigator.pushNamed(context, '/schedule-mock');
                         if (context.mounted) {
                            _fetchTodaysInterviews();
                         }
                       },
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 32),

               // Close button
               TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: Text(
                   'Close',
                   style: TextStyle(
                     color: AppColors.cream.withValues(alpha: 0.6),
                     fontSize: 16,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
               ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Scrollable content ──
            SingleChildScrollView(
              // Freeze scrolling while the grid is in edit mode
              physics: _gridInteracting
                  ? const NeverScrollableScrollPhysics()
                  : null, // platform default
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // ── Header ──
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    color: Colors.black.withValues(alpha: 0.8), // Using withValues for alpha
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Icon(
                                Icons.dashboard,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'DASHBOARD',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.4),
                                letterSpacing: 3, // tracking-[0.2em] approx
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilePage(),
                            ),
                          ),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.teal.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              color: AppColors.cream,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Bento Grid ──
                  BentoGrid(
                    layoutVersion: _layoutVersion,
                    onLayoutChanged: _handleLayoutChanged,
                    onResetRequested: _resetLayout,
                    onInteractionChanged: (active) {
                      setState(() => _gridInteracting = active);
                    },
                    onEditModeChanged: (editing) {
                      if (!editing) {
                        _saveLayout();
                      }
                    },
                    items: _buildItems(),
                  ),
                ],
              ),
            ),

            // ── FAB ──
            Positioned(
              bottom: 32,
              right: 24,
              child: GestureDetector(
                onTap: () => _showActionModal(context),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF77F00).withValues(alpha: 0.3), // glow-orange
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showTodaysInterviewsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: const Color(0xFF001e2e).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            children: [
               // Handle
               Container(
                 width: 40,
                 height: 4,
                 decoration: BoxDecoration(
                   color: Colors.white.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(2),
                 ),
                 margin: const EdgeInsets.only(bottom: 24),
               ),
               
               // Title
               Text(
                 'UPCOMING INTERVIEWS',
                 style: TextStyle(
                   color: AppColors.teal,
                   fontSize: 14,
                   fontWeight: FontWeight.bold,
                   letterSpacing: 1.0,
                 ),
               ),
               const SizedBox(height: 20),

               // List
               Expanded(
                 child: _todaysInterviews.isEmpty 
                    ? const Center(child: Text("No interviews today", style: TextStyle(color: Colors.white54)))
                    : ListView.separated(
                        itemCount: _todaysInterviews.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                           final interview = _todaysInterviews[index];
                           final timeStr = DateFormat('h:mm a').format(interview.dateTime);
                           return ListTile(
                             onTap: () {
                               Navigator.pop(context); // Close modal
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (context) => MockInterviewDetailPage(
                                     interview: interview,
                                     onEdit: (updated) {
                                       // Stream will update dashboard
                                     }, 
                                     onDelete: () async {
                                        await _interviewService.deleteInterview(interview.id);
                                     },
                                     onToggleComplete: () async {
                                        final newStatus = interview.status == 'completed' ? 'scheduled' : 'completed';
                                        await _interviewService.updateInterviewStatus(interview.id, newStatus);
                                     },
                                   ),
                                 ),
                               );
                             },
                             tileColor: Colors.white.withValues(alpha: 0.05),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                             leading: CircleAvatar(
                               backgroundColor: AppColors.teal.withValues(alpha: 0.2),
                               child: Text(
                                 interview.company.isNotEmpty ? interview.company[0] : '?',
                                 style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold),
                               ),
                             ),
                             title: Text(interview.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                             subtitle: Text('${interview.role} • $timeStr', style: const TextStyle(color: Colors.white54)),
                             trailing: Icon(Icons.chevron_right, color: Colors.white24),
                           );
                        },
                      ),
               ),

               // "See All" Button
               Padding(
                 padding: const EdgeInsets.symmetric(vertical: 24),
                 child: SizedBox(
                   width: double.infinity,
                   height: 50,
                   child: ElevatedButton(
                     onPressed: () async {
                       Navigator.pop(context);
                       await Navigator.pushNamed(context, '/schedule-mock'); // Navigate to full schedule
                       if (context.mounted) {
                          _fetchTodaysInterviews();
                       }
                     },
                     style: ElevatedButton.styleFrom(
                       backgroundColor: AppColors.teal,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                     child: const Text('View Full Schedule', style: TextStyle(color: Colors.white, fontSize: 16)),
                   ),
                 ),
               ),
            ],
          ),
        );
      },
    );
  }
}
