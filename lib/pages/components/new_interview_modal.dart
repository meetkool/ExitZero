import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/mock_interview.dart';
import '../../theme/app_theme.dart';

class NewInterviewModal extends StatefulWidget {
  final Function(MockInterview) onSave;
  final MockInterview? initialInterview;

  const NewInterviewModal({
    super.key, 
    required this.onSave,
    this.initialInterview,
  });

  @override
  State<NewInterviewModal> createState() => _NewInterviewModalState();
}

class _NewInterviewModalState extends State<NewInterviewModal> {
  late TextEditingController _titleController;
  late TextEditingController _companyController;
  late TextEditingController _roleController;
  late TextEditingController _platformController;
  late TextEditingController _linkController;
  late TextEditingController _topicsController;
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _durationMinutes = 60;
  bool _isMock = true;
  Set<String> _selectedReminders = {'1 Hour Before'};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialInterview;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _companyController = TextEditingController(text: initial?.company ?? '');
    _roleController = TextEditingController(text: initial?.role ?? '');
    _platformController = TextEditingController(text: initial?.platform ?? '');
    _linkController = TextEditingController(text: initial?.meetingLink ?? '');
    _topicsController = TextEditingController(text: initial?.notes ?? '');
    _durationMinutes = initial?.durationMinutes ?? 60;
    _isMock = initial?.isMock ?? true;
    
    if (initial != null) {
      _selectedDate = initial.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(initial.dateTime);
      _selectedReminders = Set.from(initial.reminders);
      _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(initial.dateTime));
      _timeController = TextEditingController(text: DateFormat('h:mm a').format(initial.dateTime)); // Using local format logic
    } else {
       _dateController = TextEditingController();
       _timeController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _roleController.dispose();
    _platformController.dispose();
    _linkController.dispose();
    _topicsController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }
  
  void _submit() {
      if (_titleController.text.isEmpty || _selectedDate == null || _selectedTime == null) {
          // simple validation
          return;
      }
      
      final dateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
      );
      
      final newEvent = MockInterview(
          id: widget.initialInterview?.id ?? '', // ID handled by backend if empty
          title: _titleController.text,
          company: _companyController.text.isEmpty ? 'Unknown' : _companyController.text,
          role: _roleController.text.isEmpty ? 'Candidate' : _roleController.text,
          platform: _platformController.text.isEmpty ? 'Google Meet' : _platformController.text,
          meetingLink: _linkController.text.isEmpty ? null : _linkController.text,
          dateTime: dateTime,
          durationMinutes: _durationMinutes,
          isMock: _isMock,
          notes: _topicsController.text,
          reminders: _selectedReminders,
          status: widget.initialInterview?.status ?? 'scheduled',
      );
      
      widget.onSave(newEvent);
      Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF001E2E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                    ),
                    Text(
                      widget.initialInterview == null ? 'New Interview' : 'Edit Interview',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextButton(
                      onPressed: _submit,
                      child: Text('Save', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),

              // Form content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _ModalInput(label: 'Interview Title', controller: _titleController),
                    const SizedBox(height: 20),
                    Row(
                        children: [
                            Expanded(child: _ModalInput(label: 'Company', controller: _companyController)),
                            const SizedBox(width: 16),
                            Expanded(child: _ModalInput(label: 'Platform', controller: _platformController)),
                        ],
                    ),
                    const SizedBox(height: 20),
                    _ModalInput(label: 'Role / Position', controller: _roleController),
                    const SizedBox(height: 20),
                    _ModalInput(label: 'Meeting Link (Optional)', controller: _linkController),
                    const SizedBox(height: 20),
                    
                    // Duration Selector
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(
                                'Duration',
                                style: TextStyle(
                                    color: AppColors.cream.withValues(alpha: 0.5),
                                    fontSize: 12,
                                ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                                height: 50,
                                child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [30, 45, 60, 90, 120].map((mins) {
                                        final isSelected = _durationMinutes == mins;
                                        return Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: GestureDetector(
                                                onTap: () => setState(() => _durationMinutes = mins),
                                                child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                    decoration: BoxDecoration(
                                                        color: isSelected ? AppColors.teal : Colors.white.withValues(alpha: 0.05),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                            color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
                                                        ),
                                                    ),
                                                    child: Text(
                                                        '$mins m',
                                                        style: TextStyle(
                                                            color: isSelected ? Colors.white : Colors.white70,
                                                            fontWeight: FontWeight.w600,
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        );
                                    }).toList(),
                                ),
                            ),
                        ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child: _ModalInput(
                                label: 'Date', 
                                isDate: true, 
                                controller: _dateController,
                                onDateSelected: (d) {
                                    setState(() {
                                        _selectedDate = d;
                                        _dateController.text = DateFormat('yyyy-MM-dd').format(d);
                                    });
                                },
                            ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _ModalInput(
                                label: 'Time', 
                                isTime: true, 
                                controller: _timeController,
                                onTimeSelected: (t) {
                                    setState(() {
                                        _selectedTime = t;
                                        _timeController.text = t.format(context);
                                    });
                                },
                            ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // is_mock Toggle
                    Container(
                        decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 2)),
                        ),
                        child: SwitchListTile(
                            title: const Text('Is Mock Interview?', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            value: _isMock, 
                            onChanged: (val) => setState(() => _isMock = val),
                            activeColor: AppColors.teal,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                    ),
                    const SizedBox(height: 24),

                    // Reminders
                    const Text(
                      'Reminders',
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ReminderChip(
                          label: '1 Day Before',
                          selected: _selectedReminders.contains('1 Day Before'),
                          onTap: () => _toggleReminder('1 Day Before'),
                        ),
                        _ReminderChip(
                          label: '1 Hour Before',
                          selected: _selectedReminders.contains('1 Hour Before'),
                          onTap: () => _toggleReminder('1 Hour Before'),
                        ),
                        _ReminderChip(
                          label: '15 Mins Before',
                          selected: _selectedReminders.contains('15 Mins Before'),
                          onTap: () => _toggleReminder('15 Mins Before'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _ModalInput(label: 'Topics / Focus Area', maxLines: 4, controller: _topicsController),
                  ],
                ),
              ),
              
              // Bottom Action
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            shadowColor: AppColors.orange.withValues(alpha: 0.4),
                            elevation: 8,
                        ),
                        child: Text(
                             widget.initialInterview == null ? 'SCHEDULE' : 'SAVE CHANGES',
                             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _toggleReminder(String label) {
    setState(() {
      if (_selectedReminders.contains(label)) {
        _selectedReminders.remove(label);
      } else {
        _selectedReminders.add(label);
      }
    });
  }
}

class _ModalInput extends StatelessWidget {
  final String label;
  final int maxLines;
  final bool isDate;
  final bool isTime;
  final TextEditingController? controller;
  final ValueChanged<DateTime>? onDateSelected;
  final ValueChanged<TimeOfDay>? onTimeSelected;

  const _ModalInput({
    required this.label,
    this.maxLines = 1,
    this.isDate = false,
    this.isTime = false,
    this.controller,
    this.onDateSelected,
    this.onTimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.cream.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              TextField(
                controller: controller,
                maxLines: maxLines,
                decoration: InputDecoration(
                   border: InputBorder.none,
                   focusedBorder: InputBorder.none,
                   enabledBorder: InputBorder.none,
                   contentPadding: EdgeInsets.zero,
                   hintText: isDate ? 'Select Date' : (isTime ? 'Select Time' : ''),
                   hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                   suffixIcon: isDate ? Icon(Icons.calendar_today, size: 16, color: AppColors.cream.withValues(alpha: 0.5)) : 
                               (isTime ? Icon(Icons.access_time, size: 16, color: AppColors.cream.withValues(alpha: 0.5)) : null),
                ),
                style: TextStyle(color: AppColors.cream, fontSize: 16),
                readOnly: isDate || isTime,
                onTap: () async {
                    if (isDate) {
                        final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030), initialDate: DateTime.now());
                        if (picked != null) onDateSelected?.call(picked);
                    } else if (isTime) {
                         final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                         if (picked != null) onTimeSelected?.call(picked);
                    }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReminderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReminderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white.withValues(alpha: 0.2),
          ),
          boxShadow: selected ? [
             const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
                const Icon(Icons.check, size: 16, color: Colors.white),
                const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
