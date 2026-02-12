import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bento_card.dart';

/// A single log entry for the timeline.
class LogEntry {
  final String message;
  final String time;
  final bool isActive;

  const LogEntry({
    required this.message,
    required this.time,
    this.isActive = false,
  });
}

/// System-logs card with horizontal filter pills and a vertical timeline.
///
/// Usage:
/// ```dart
/// SystemLogs(
///   entries: [
///     LogEntry(message: 'System armed.', time: '10:00 AM', isActive: true),
///     LogEntry(message: 'Waiting...', time: 'Now'),
///   ],
/// )
/// ```
class SystemLogs extends StatefulWidget {
  final List<LogEntry> entries;
  final List<String> filters;

  const SystemLogs({
    super.key,
    required this.entries,
    this.filters = const ['Today', '2 Days', '1 Week', '1 Month'],
  });

  @override
  State<SystemLogs> createState() => _SystemLogsState();
}

class _SystemLogsState extends State<SystemLogs> {
  int _activeFilter = 0;
  double _logOpacity = 1.0;

  void _selectFilter(int index) {
    if (index == _activeFilter) return;

    // Brief dim effect when switching filters
    setState(() {
      _activeFilter = index;
      _logOpacity = 0.5;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _logOpacity = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      glassmorphism: false,
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)), // tile border
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title ──
          Text(
            'SYSTEM LOGS',
            style: TextStyle(
              color: const Color(0xFF126782),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2, // tracking updated
            ),
          ),
          const SizedBox(height: 16),

          // ── Filter pills ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(widget.filters.length, (i) {
                final isActive = i == _activeFilter;
                return Padding(
                  padding: EdgeInsets.only(
                      right: i < widget.filters.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => _selectFilter(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF126782).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF126782)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        widget.filters[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
                          color: isActive
                              ? const Color(0xFF126782)
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // ── Timeline entries ──
          AnimatedOpacity(
            opacity: _logOpacity,
            duration: const Duration(milliseconds: 200),
            child: _buildTimeline(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Stack(
      children: [
        // Vertical line
        Positioned(
          left: 4, // Updated left position
          top: 4, // Updated top/bottom according to design
          bottom: 4,
          child: Container(
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),

        // Entries
        Column(
          children: List.generate(widget.entries.length, (i) {
            final entry = widget.entries[i];
            final isLast = i == widget.entries.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dot
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: entry.isActive
                          ? const Color(0xFF126782)
                          : Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2), // ring-4 ring-black simulated with border (or thicker border)
                      boxShadow: const [
                         BoxShadow(
                           color: Colors.black,
                           spreadRadius: 2, // ring effect
                         )
                      ],
                    ),
                  ),
                  const SizedBox(width: 12), // Gap 3 (12px)

                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: entry.isActive
                                ? AppColors.cream
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        // const SizedBox(height: 0),
                        Text(
                          entry.time,
                          style: TextStyle(
                            fontSize: 9,
                            fontFamily: 'monospace',
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}
