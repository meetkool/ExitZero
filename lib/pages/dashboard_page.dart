import 'dart:convert';
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

  /// When true the grid is in edit mode (header + handles are visible).
  bool _gridEditing = false;

  /// True only while dragging/resizing (scroll temporarily disabled).
  bool _gridInteracting = false;

  /// Current layout state (order + size) for persistence.
  List<BentoGridLayoutItem> _layoutState = [];

  /// Forces BentoGrid to resync from new items (e.g. reset / load).
  int _layoutVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadLayout();
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
      // Daily Survival
      const BentoGridItem(
        id: 'survival',
        columnSpan: 2,
        height: 160,
        minHeight: 120,
        maxHeight: 240,
        card: DailySurvivalCard(
          percentage: 72,
          status: 'Safe',
          timeRemaining: '4 hrs remaining',
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

      // LeetCode (left) + Video Tile (right)
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

      // Outreach (half width)
      const BentoGridItem(
        id: 'outreach',
        columnSpan: 1,
        height: 150,
        minHeight: 100,
        maxHeight: 220,
        card: OutreachCard(sent: 2, total: 5),
      ),

      // Life Score (half width, next to Outreach)
      const BentoGridItem(
        id: 'life-score',
        columnSpan: 1,
        height: 150,
        minHeight: 120,
        maxHeight: 220,
        card: LifeScoreCard(
          score: 450,
          nextRewardAt: 500,
        ),
      ),

      // Interviews
      const BentoGridItem(
        id: 'interviews',
        columnSpan: 2,
        height: 100,
        minHeight: 80,
        maxHeight: 160,
        card: InterviewsCard(
          companyLetter: 'G',
          title: 'Google Mock',
          schedule: 'Thursday, 10:00 AM',
          daysLeft: 2,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.asset(
                                'assets/app_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'DASHBOARD',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.cream.withValues(alpha: 0.6),
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                        Container(
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
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Bento Grid ──
                  //
                  // Long-press any card → edit mode.
                  // Then drag to reorder, resize from any side handle,
                  // or double-tap to toggle width.
                  BentoGrid(
                    layoutVersion: _layoutVersion,
                    onLayoutChanged: _handleLayoutChanged,
                    onResetRequested: _resetLayout,
                    onInteractionChanged: (active) {
                      setState(() => _gridInteracting = active);
                    },
                    onEditModeChanged: (editing) {
                      setState(() => _gridEditing = editing);
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
                onTap: () {
                  // TODO: Open log/action menu
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
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
}
