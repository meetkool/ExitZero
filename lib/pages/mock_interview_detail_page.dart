import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../models/mock_interview.dart'; // For MockInterview
import 'components/new_interview_modal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class MockInterviewDetailPage extends StatefulWidget {
  final MockInterview interview;
  final Function(MockInterview) onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleComplete;

  const MockInterviewDetailPage({
    super.key, 
    required this.interview,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleComplete,
  });

  @override
  State<MockInterviewDetailPage> createState() => _MockInterviewDetailPageState();
}

class _MockInterviewDetailPageState extends State<MockInterviewDetailPage> {
  late MockInterview _interview;

  @override
  void initState() {
    super.initState();
    _interview = widget.interview;
  }

  void _handleEdit(MockInterview updatedInterview) {
    setState(() {
      _interview = updatedInterview;
    });
    widget.onEdit(updatedInterview);
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001E2E),
        title: const Text('Delete Interview?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this interview?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onDelete();
              Navigator.pop(context); // Close detail page
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Interview Details',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _handleDelete,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white70),
            onPressed: _shareInterview,
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.teal),
            onPressed: () {
               showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => NewInterviewModal(
                    initialInterview: _interview,
                    onSave: _handleEdit,
                  ),
                );
            },
          ),
          const SizedBox(width: 8), // Padding
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Company
            Text(
              _interview.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.business, size: 16, color: AppColors.teal),
                      const SizedBox(width: 8),
                      Text(
                        _interview.company,
                        style: TextStyle(
                          color: AppColors.teal,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 16, color: AppColors.teal),
                      const SizedBox(width: 8),
                      Text(
                        _interview.role,
                        style: TextStyle(
                          color: AppColors.teal.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.video_camera_back, size: 16, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(
                        _interview.platform,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Date & Time Grid
            Row(
              children: [
                Expanded(
                  child: _DetailCard(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: dateFormat.format(_interview.dateTime),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DetailCard(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: timeFormat.format(_interview.dateTime),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            
            // Meeting Link Section
            if (_interview.meetingLink != null && _interview.meetingLink!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                          children: [
                             Icon(Icons.video_call, color: AppColors.teal),
                             const SizedBox(width: 8),
                             Text(
                               'MEETING LINK',
                               style: TextStyle(
                                 color: AppColors.teal,
                                 fontWeight: FontWeight.bold,
                                 fontSize: 12,
                                 letterSpacing: 1.0,
                               ),
                             ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _launchMeeting,
                          child: Text(
                            _interview.meetingLink!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.teal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                           width: double.infinity,
                           height: 48,
                           child: ElevatedButton(
                             onPressed: _launchMeeting,
                             style: ElevatedButton.styleFrom(
                               backgroundColor: AppColors.teal,
                               foregroundColor: Colors.white,
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                             ),
                             child: const Text('Join Meeting', style: TextStyle(fontWeight: FontWeight.bold)),
                           ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
            ],

            const Divider(color: Colors.white10),
            const SizedBox(height: 24),

            // Topics / Notes
            const Text(
              'TOPICS / FOCUS AREA',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                _interview.notes?.isNotEmpty == true ? _interview.notes! : 'No topics specified.',
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Reminders
            if (_interview.reminders.isNotEmpty) ...[
                const Text(
                  'REMINDERS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _interview.reminders.map((r) => _ReminderChip(label: r)).toList(),
                ),
                const SizedBox(height: 48),
            ],

            // Mark as Completed Button
            SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                    onPressed: () {
                        // Optimistic update or wait?
                        // Since check-in is strict, maybe wait?
                        // But UI feels better if immediate.
                        // However, check-in might fail.
                        // Let's call callback.
                        widget.onToggleComplete();
                        
                        // We assume success for UI feedback? 
                        // Or we should wait for parent to tell us?
                        // Ideally onToggleComplete returns the updated interview.
                        // For now, let's just assume if it was not completed, it becomes completed.
                        // But we also need to update the local _interview object with 'completed' status.
                        // And we need to construct it correctly.
                        
                        setState(() {
                             // This is just a UI toggle for now, ideally strictly synced
                             // But since we can't await the void callback result easily without changing signature...
                             // I'll just toggle the status locally to 'completed' if it was 'scheduled'.
                             if (_interview.status == 'scheduled') {
                                 _interview = _interview.copyWith(status: 'completed');
                             }
                        });
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _interview.isCompleted ? Colors.transparent : AppColors.teal,
                        foregroundColor: _interview.isCompleted ? AppColors.teal : Colors.white,
                        elevation: _interview.isCompleted ? 0 : 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppColors.teal, width: 2),
                        ),
                    ),
                    icon: Icon(_interview.isCompleted ? Icons.check_circle : Icons.check_circle_outline),
                    label: Text(
                        _interview.isCompleted ? 'COMPLETED' : 'MARK AS COMPLETED',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _launchMeeting() async {
    final url = _interview.meetingLink;
    if (url == null || url.isEmpty) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No meeting link available.')),
            );
        }
        return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Could not launch meeting URL: $url')),
           );
       }
    }
  }

  void _shareInterview() {
     final timeStr = DateFormat('EEEE, MMMM d, yyyy h:mm a').format(_interview.dateTime);
     Share.share(
       'Mock Interview: ${_interview.title}\n'
       'Company: ${_interview.company}\n'
       'Role: ${_interview.role}\n'
       'Date: $timeStr\n'
       'Platform: ${_interview.platform}\n'
       'Link: ${_interview.meetingLink ?? "N/A"}'
     );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.orange, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, 
                fontSize: 15, 
                fontWeight: FontWeight.w600
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderChip extends StatelessWidget {
  final String label;

  const _ReminderChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_active, size: 14, color: AppColors.teal),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.teal,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
