import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/leetcode_status.dart';
import '../../../services/leetcode_status_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bento_card.dart';

class LeetCodeCard extends StatefulWidget {
  const LeetCodeCard({super.key});

  @override
  State<LeetCodeCard> createState() => _LeetCodeCardState();
}

class _LeetCodeCardState extends State<LeetCodeCard> {
  final LeetCodeStatusService _service = LeetCodeStatusService();
  final DateFormat _dateFormat = DateFormat('MMM d, h:mm a');
  final NumberFormat _numberFormat = NumberFormat.decimalPattern();

  LeetCodeStatus? _status;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _isRefreshing = true;
        _error = null;
      });
    }

    try {
      final status = await _service.fetchStatus();
      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _openDetails() {
    final status = _status;
    if (status == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _LeetCodeDetailsSheet(
          status: status,
          dateFormat: _dateFormat,
          numberFormat: _numberFormat,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      height: double.infinity,
      padding: const EdgeInsets.all(18),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF09131B),
          Color(0xFF08283A),
        ],
      ),
      border: Border.all(
        color: AppColors.teal.withValues(alpha: 0.22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final tone = _statusTone(_status);
    final label = _status == null
        ? 'SYNCING'
        : _status!.goalMet
            ? 'GOAL MET'
            : _status!.status.replaceAll('_', ' ').toUpperCase();

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _status?.goalMet == true ? Icons.verified : Icons.code,
            color: tone,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LEETCODE STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cream.withValues(alpha: 0.64),
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: tone.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _isRefreshing ? null : () => _loadStatus(showLoader: false),
          icon: _isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.cream,
                  ),
                )
              : Icon(
                  Icons.refresh,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        key: ValueKey('leetcode-loading'),
        child: CircularProgressIndicator(
          color: AppColors.orange,
        ),
      );
    }

    if (_error != null) {
      return Container(
        key: const ValueKey('leetcode-error'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.burnt.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unable to load status',
              style: TextStyle(
                color: AppColors.burnt,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _loadStatus,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.cream,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final status = _status;
    if (status == null) {
      return const SizedBox.shrink(key: ValueKey('leetcode-empty'));
    }

    return Column(
      key: const ValueKey('leetcode-ready'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Problems',
                value:
                    '${status.progress.uniqueProblems}/${status.goals.uniqueProblems}',
                detail: '${status.progress.problemsLeft} left',
                accent: AppColors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Submissions',
                value:
                    '${status.progress.totalSubmissions}/${status.goals.totalSubmissions}',
                detail: '${status.progress.submissionsLeft} left',
                accent: AppColors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ProgressLine(
          label: 'Accepted problems',
          accent: AppColors.orange,
          current: status.progress.uniqueProblems,
          goal: status.goals.uniqueProblems,
          trailing: '${status.progress.acceptedProblems} accepted',
        ),
        const SizedBox(height: 10),
        _ProgressLine(
          label: 'Submission pace',
          accent: AppColors.teal,
          current: status.progress.totalSubmissions,
          goal: status.goals.totalSubmissions,
          trailing:
              '${status.progress.totalSubmissions} total submissions today',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.schedule,
              label: _formatRemaining(status),
            ),
            _InfoChip(
              icon: Icons.flag,
              label: 'Phase: ${status.enforcer.phase}',
            ),
            _InfoChip(
              icon: Icons.notifications_active,
              label:
                  '${_numberFormat.format(status.enforcer.remindersSentToday)} reminders',
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: Text(
                'Deadline ${_dateFormat.format(status.deadline.toLocal())}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openDetails,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.cream,
              ),
              icon: const Icon(Icons.open_in_full, size: 18),
              label: const Text('Details'),
            ),
          ],
        ),
      ],
    );
  }

  Color _statusTone(LeetCodeStatus? status) {
    if (status == null) {
      return AppColors.cream;
    }
    if (status.goalMet) {
      return const Color(0xFF35D59A);
    }
    if (status.enforcer.pastDeadline) {
      return AppColors.burnt;
    }
    if (status.enforcer.phase == 'pressure') {
      return AppColors.orange;
    }
    return AppColors.tealLight;
  }

  String _formatRemaining(LeetCodeStatus status) {
    if (status.enforcer.pastDeadline) {
      return 'Deadline passed';
    }
    return '${status.enforcer.hoursLeft}h '
        '${status.enforcer.minutesLeft}m left';
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color accent;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final String label;
  final int current;
  final int goal;
  final String trailing;
  final Color accent;

  const _ProgressLine({
    required this.label,
    required this.current,
    required this.goal,
    required this.trailing,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final safeGoal = goal <= 0 ? 1 : goal;
    final progress = (current / safeGoal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$current/$goal',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          trailing,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.cream.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeetCodeDetailsSheet extends StatelessWidget {
  final LeetCodeStatus status;
  final DateFormat dateFormat;
  final NumberFormat numberFormat;

  const _LeetCodeDetailsSheet({
    required this.status,
    required this.dateFormat,
    required this.numberFormat,
  });

  @override
  Widget build(BuildContext context) {
    final tone = status.goalMet
        ? const Color(0xFF35D59A)
        : status.enforcer.pastDeadline
            ? AppColors.burnt
            : AppColors.orange;

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.deep,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(30),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LEETCODE STATUS',
                            style: TextStyle(
                              color: AppColors.cream.withValues(alpha: 0.62),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            status.status.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: tone.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        status.goalMet ? 'GOAL MET' : 'ACTIVE',
                        style: TextStyle(
                          color: tone,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    _SheetSection(
                      title: 'Overview',
                      child: Column(
                        children: [
                          _SheetRow(
                            label: 'Goal met',
                            value: status.goalMet ? 'Yes' : 'No',
                          ),
                          _SheetRow(
                            label: 'Fetched at',
                            value: dateFormat.format(status.fetchedAt.toLocal()),
                          ),
                          _SheetRow(
                            label: 'Server time',
                            value:
                                dateFormat.format(status.serverTime.toLocal()),
                          ),
                          _SheetRow(
                            label: 'Deadline',
                            value: dateFormat.format(status.deadline.toLocal()),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SheetSection(
                      title: 'Progress',
                      child: Column(
                        children: [
                          _SheetRow(
                            label: 'Unique problems',
                            value: status.progress.uniqueProblems.toString(),
                          ),
                          _SheetRow(
                            label: 'Total submissions',
                            value:
                                status.progress.totalSubmissions.toString(),
                          ),
                          _SheetRow(
                            label: 'Accepted problems',
                            value:
                                status.progress.acceptedProblems.toString(),
                          ),
                          _SheetRow(
                            label: 'Problems left',
                            value: status.progress.problemsLeft.toString(),
                          ),
                          _SheetRow(
                            label: 'Submissions left',
                            value: status.progress.submissionsLeft.toString(),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SheetSection(
                      title: 'Goals',
                      child: Column(
                        children: [
                          _SheetRow(
                            label: 'Unique problems goal',
                            value: status.goals.uniqueProblems.toString(),
                          ),
                          _SheetRow(
                            label: 'Submission goal',
                            value: status.goals.totalSubmissions.toString(),
                          ),
                          _SheetRow(
                            label: 'Deadline hour',
                            value: '${status.goals.deadlineHour}:00',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SheetSection(
                      title: 'Enforcer',
                      child: Column(
                        children: [
                          _SheetRow(
                            label: 'Phase',
                            value: status.enforcer.phase,
                          ),
                          _SheetRow(
                            label: 'Hours left',
                            value: status.enforcer.hoursLeft.toString(),
                          ),
                          _SheetRow(
                            label: 'Minutes left',
                            value: status.enforcer.minutesLeft.toString(),
                          ),
                          _SheetRow(
                            label: 'Past deadline',
                            value:
                                status.enforcer.pastDeadline ? 'Yes' : 'No',
                          ),
                          _SheetRow(
                            label: 'Reminders sent today',
                            value: numberFormat.format(
                              status.enforcer.remindersSentToday,
                            ),
                          ),
                          _SheetRow(
                            label: 'Last reminder at',
                            value: status.enforcer.lastReminderAt == null
                                ? 'Never'
                                : dateFormat.format(
                                    status.enforcer.lastReminderAt!.toLocal(),
                                  ),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SheetSection(
                      title: 'Profile',
                      child: _MapBlock(
                        data: status.profile,
                        emptyLabel: 'No LeetCode profile linked yet.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SheetSection(
                      title: 'Problems',
                      child: _ProblemsBlock(
                        problems: status.problems,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SheetSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: AppColors.cream.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _SheetRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBlock extends StatelessWidget {
  final Map<String, dynamic>? data;
  final String emptyLabel;

  const _MapBlock({
    required this.data,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final map = data;
    if (map == null || map.isEmpty) {
      return Text(
        emptyLabel,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontSize: 13,
          height: 1.45,
        ),
      );
    }

    final entries = map.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          _SheetRow(
            label: entries[index].key,
            value: _formatDynamicValue(entries[index].value),
            isLast: index == entries.length - 1,
          ),
      ],
    );
  }
}

class _ProblemsBlock extends StatelessWidget {
  final List<Map<String, dynamic>> problems;

  const _ProblemsBlock({
    required this.problems,
  });

  @override
  Widget build(BuildContext context) {
    if (problems.isEmpty) {
      return Text(
        'No problem activity returned by the endpoint yet.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontSize: 13,
          height: 1.45,
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < problems.length; index++) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Problem ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _MapBlock(
                  data: problems[index],
                  emptyLabel: 'No fields returned.',
                ),
              ],
            ),
          ),
          if (index != problems.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

String _formatDynamicValue(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  if (value is num) {
    return value.toString();
  }
  if (value is String) {
    return value;
  }
  return jsonEncode(value);
}
