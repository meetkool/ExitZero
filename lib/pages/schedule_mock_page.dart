import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/mock_interview.dart';
import '../services/interview_service.dart';
import '../theme/app_theme.dart';
import 'mock_interview_detail_page.dart';
import 'components/new_interview_modal.dart';
import 'profile_page.dart';

class ScheduleMockPage extends StatefulWidget {
  const ScheduleMockPage({super.key});

  @override
  State<ScheduleMockPage> createState() => _ScheduleMockPageState();
}

class _ScheduleMockPageState extends State<ScheduleMockPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  int _selectedSegment = 0; // 0 = Upcoming, 1 = Past
  bool _isLoading = false;

  // In-memory events (still useful for calendar)
  final Map<DateTime, List<MockInterview>> _events = {};
  final InterviewService _interviewService = InterviewService();

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _fetchInterviews();
  }

  Future<void> _fetchInterviews() async {
    setState(() => _isLoading = true);
    try {
      final interviews = await _interviewService.getInterviews();
      setState(() {
        _events.clear();
        for (var interview in interviews) {
            _addEventToMap(interview);
        }
      });
    } catch (e) {
      if (mounted) {
        // Log error or show snackbar? 
        // Showing snackbar on init might be annoying if offline, but useful for debug.
        // For now, let's keep it quiet or just log to console if I could.
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addEventToMap(MockInterview event) {
    // Normalizing key to midnight
    final dateKey = DateTime(
      event.dateTime.year,
      event.dateTime.month,
      event.dateTime.day,
    );
    
    if (_events[dateKey] == null) {
      _events[dateKey] = [];
    }
    _events[dateKey]!.add(event);
  }

  List<MockInterview> _getEventsForDay(DateTime day) {
    final normalizeDate = DateTime(day.year, day.month, day.day);
    return _events[normalizeDate] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  Future<void> _handleNewStart(MockInterview newEvent) async {
    setState(() => _isLoading = true);
    try {
      final created = await _interviewService.createInterview(newEvent);
      setState(() {
        _addEventToMap(created);
      });
      if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Interview scheduled successfully!')),
           );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating interview: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteEvent(MockInterview event) async {
      setState(() => _isLoading = true);
      try {
          await _interviewService.deleteInterview(event.id);
          setState(() {
            final dateKey = DateTime(
                event.dateTime.year,
                event.dateTime.month,
                event.dateTime.day,
            );
            _events[dateKey]?.remove(event);
            if (_events[dateKey]?.isEmpty ?? false) {
                _events.remove(dateKey);
            }
          });
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Interview deleted')),
              );
          }
      } catch (e) {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error deleting interview: $e')),
             );
          }
      } finally {
          if (mounted) setState(() => _isLoading = false);
      }
  }

  Future<void> _handleEditEvent(MockInterview oldEvent, MockInterview newEvent) async {
    setState(() => _isLoading = true);
    try {
       // Convert newEvent to map for update
       final updates = newEvent.toJson();
       // Remove non-updatable fields if any
       updates.remove('id');
       // Don't remove status if we want to allow status update, but usually specific endpoints handle status.
       // However, general update might allow it. 
       
       final updated = await _interviewService.updateInterview(oldEvent.id, updates);

       setState(() {
          // Remove old event
          final oldDateKey = DateTime(
            oldEvent.dateTime.year,
            oldEvent.dateTime.month,
            oldEvent.dateTime.day,
          );
          _events[oldDateKey]?.remove(oldEvent);
          if (_events[oldDateKey]?.isEmpty ?? false) {
              _events.remove(oldDateKey);
          }

          // Add updated event
          _addEventToMap(updated);
       });
       if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Interview updated')),
            );
       }
    } catch (e) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating interview: $e')),
            );
        }
    } finally {
        if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleToggleComplete(MockInterview event) async {
      if (event.status == 'completed' || event.status == 'missed') {
          return;
      }
      
      setState(() => _isLoading = true);
      try {
          // Call check-in API
          final updated = await _interviewService.checkIn(event.id);
          
          setState(() {
              // Replace in list
              final dateKey = DateTime(
                event.dateTime.year,
                event.dateTime.month,
                event.dateTime.day,
              );
              
              final list = _events[dateKey];
              if (list != null) {
                  final index = list.indexOf(event);
                  if (index != -1) {
                      list[index] = updated;
                  }
              }
          });
          
          if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Checked in! +10 coins reward!')),
               );
          }
      } catch (e) {
          if (mounted) {
               String msg = e.toString();
               // Simple error message cleanup
               if (msg.contains('Exception:')) msg = msg.replaceAll('Exception:', '').trim();
               
               ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Check-in failed: $msg')),
               );
          }
      } finally {
          if (mounted) setState(() => _isLoading = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Flatten all events
    final allEvents = _events.values.expand((element) => element).toList();
    
    List<MockInterview> visibleEvents;
    if (_selectedSegment == 0) {
      // Upcoming: Future AND Not Completed
      visibleEvents = allEvents.where((e) => !e.isCompleted && e.dateTime.isAfter(now)).toList();
      visibleEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } else {
      // Past: Completed OR Past Time
      visibleEvents = allEvents.where((e) => e.isCompleted || e.dateTime.isBefore(now)).toList();
      visibleEvents.sort((a, b) => b.dateTime.compareTo(a.dateTime)); // Descending for past
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Scrollable Content ──
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              children: [
                _buildHeader(visibleEvents.length),
                _buildCalendarSection(),
                _buildSegmentControl(),
                
                if (_isLoading && _events.isEmpty) // Show loader only if no data yet or full reload
                    const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator(color: AppColors.teal)),
                    )
                else
                    _selectedSegment == 0 
                        ? _buildEventList(visibleEvents)
                        : _buildPastEventList(visibleEvents),
              ],
            ),
          ),

          // ── FAB ──
          Positioned(
            bottom: 32,
            right: 24,
            child: GestureDetector(
              onTap: () => _showNewInterviewModal(context),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
          
          if (_isLoading && _events.isNotEmpty)
                const Positioned(
                    top: 50,
                    right: 24,
                    child: SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2)
                    ),
                ),
        ],
      ),
    );
  }

  Widget _buildHeader(int eventCount) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                        'Schedule',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.0,
                        ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                     padding: const EdgeInsets.only(left: 36),
                     child: Text(
                        '$eventCount ${_selectedSegment == 0 ? "upcoming" : "past"} mocks',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.teal,
                            letterSpacing: 0.5,
                        ),
                    ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.cream,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _GlassPanel(
        child: TableCalendar<MockInterview>(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: _onDaySelected,
          calendarFormat: _calendarFormat,
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.sunday,
          headerStyle: HeaderStyle(
            titleCentered: false,
            formatButtonVisible: false,
            titleTextStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white.withValues(alpha: 0.5)),
            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.5)),
          ),
          daysOfWeekStyle: TextStyle(
            color: AppColors.teal,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ).asDaysOfWeekStyle(),
          calendarStyle: CalendarStyle(
            defaultTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            weekendTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            outsideTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            defaultDecoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(10),
            ),
            weekendDecoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(10),
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.orange,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.4),
                  blurRadius: 15,
                ),
              ],
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.teal),
            ),
            todayTextStyle: const TextStyle(color: AppColors.teal),
            markerDecoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
             markersMaxCount: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentControl() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _SegmentButton(
              label: 'Upcoming',
              isActive: _selectedSegment == 0,
              onTap: () => setState(() => _selectedSegment = 0),
            ),
            _SegmentButton(
              label: 'Past',
              isActive: _selectedSegment == 1,
              onTap: () => setState(() => _selectedSegment = 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList(List<MockInterview> events) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
                'No events found',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: events.map((event) {
            return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EventCard(
                  interview: event,
                  accentColor: _selectedSegment == 0 ? AppColors.teal : AppColors.orange,
                  onEdit: (updated) => _handleEditEvent(event, updated),
                  onDelete: () => _handleDeleteEvent(event),
                  onToggleComplete: _handleToggleComplete,
                ),
            );
        }).toList(),
      ),
    );
  }

  Widget _buildPastEventList(List<MockInterview> events) {
      if (events.isEmpty) {
        return Center(
          child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                  'No past events',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              ),
          ),
        );
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      // Group by day
      final Map<DateTime, List<MockInterview>> grouped = {};
      for (var event in events) {
          final date = DateTime(event.dateTime.year, event.dateTime.month, event.dateTime.day);
          if (!grouped.containsKey(date)) {
              grouped[date] = [];
          }
          grouped[date]!.add(event);
      }

      // Sort dates descending
      final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedDates.expand((date) {
                  String header;
                  if (date == today) {
                      header = 'Today';
                  } else if (date == yesterday) {
                      header = 'Yesterday';
                  } else {
                      final diff = today.difference(date).inDays;
                      if (diff > 0 && diff < 7) {
                          header = '$diff Days Ago';
                      } else {
                          header = DateFormat('MMM d, yyyy').format(date);
                      }
                  }

                  return [
                      // Header
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                              children: [
                                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                  Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                          header.toUpperCase(),
                                          style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.5),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.0,
                                          ),
                                      ),
                                  ),
                                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                              ],
                          ),
                      ),
                      // Events for this day
                      ...grouped[date]!.map((event) {
                          return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _EventCard(
                                  interview: event,
                                  accentColor: AppColors.orange, 
                                  onEdit: (updated) => _handleEditEvent(event, updated),
                                  onDelete: () => _handleDeleteEvent(event),
                                  onToggleComplete: _handleToggleComplete,
                              ),
                          );
                      }),
                  ];
              }).toList(),
          ),
      );
  }

  void _showNewInterviewModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NewInterviewModal(
        onSave: _handleNewStart,
      ),
    );
  }
}

// ── Helper Widgets ──

extension on TextStyle {
  DaysOfWeekStyle asDaysOfWeekStyle() {
    return DaysOfWeekStyle(
      weekdayStyle: this,
      weekendStyle: this,
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _GlassPanel({
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final MockInterview interview;
  final Color accentColor;
  final Function(MockInterview) onEdit;
  final VoidCallback onDelete;
  final Function(MockInterview) onToggleComplete;

  const _EventCard({
    required this.interview,
    required this.accentColor,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(interview.dateTime);
    final dateStr = DateFormat('MMM d').format(interview.dateTime);

    return _GlassPanel(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MockInterviewDetailPage(
                interview: interview,
                onEdit: onEdit,
                onDelete: () {
                    onDelete();
                },
                onToggleComplete: () => onToggleComplete(interview),
            ),
          ),
        );
      },
      child: IntrinsicHeight(
        child: Row(
          children: [
             // Time / Date
            Expanded(
              flex: 1,
              child: Opacity(
                opacity: interview.isCompleted ? 0.5 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                        decoration: interview.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: accentColor, width: 4),
                  ),
                ),
                child: Row(
                    children: [
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Text(
                                interview.title,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cream.withValues(alpha: interview.isCompleted ? 0.5 : 1.0),
                                    decoration: interview.isCompleted ? TextDecoration.lineThrough : null,
                                ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                children: [
                                    Icon(Icons.business, size: 14, color: Colors.white.withValues(alpha: 0.6)),
                                    const SizedBox(width: 6),
                                    Text(
                                    interview.company,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                    ),
                                ],
                                ),
                            ],
                        )),
                        // Checkbox
                        // If missed or cancelled, maybe show different icon?
                        // For now, simple logic.
                        if (interview.status != 'missed')
                        Transform.scale(
                            scale: 1.2,
                            child: Checkbox(
                                value: interview.isCompleted,
                                onChanged: (val) => onToggleComplete(interview),
                                activeColor: AppColors.teal,
                                checkColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                        ),
                        if (interview.status == 'missed')
                          const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: Icon(Icons.error_outline, color: Colors.redAccent),
                          ),
                    ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
