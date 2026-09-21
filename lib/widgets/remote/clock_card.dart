import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/device_media.dart';

/// A clock in the shape Android's own uses: a deep squircle, the date above
/// the hour, and the next alarm underneath.
///
/// The alarm line is the system's next alarm, the same one the lock screen
/// shows, so the card agrees with the phone rather than inventing its own.
class ClockCard extends StatefulWidget {
  final double height;
  final Color background;
  final Color accent;
  final Color timeColor;
  final bool use24Hour;
  final bool showAlarm;

  const ClockCard({
    super.key,
    this.height = 190,
    this.background = const Color(0xFF2E4A3F),
    this.accent = const Color(0xFF63D9A6),
    this.timeColor = const Color(0xFFF1F3F0),
    this.use24Hour = false,
    this.showAlarm = true,
  });

  @override
  State<ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends State<ClockCard> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  DateTime? _alarm;

  @override
  void initState() {
    super.initState();
    _loadAlarm();
    // A second is plenty: the face shows minutes, and setState only runs when
    // the rendered string would actually change.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      if (now.minute != _now.minute || now.day != _now.day) {
        if (mounted) setState(() => _now = now);
        if (now.minute % 5 == 0) _loadAlarm();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadAlarm() async {
    if (!widget.showAlarm) return;
    final at = await DeviceMediaService.nextAlarm();
    if (!mounted) return;
    setState(() => _alarm = at);
  }

  String get _time => DateFormat(
    widget.use24Hour ? 'HH:mm' : 'h:mm',
  ).format(_now);

  String get _date => DateFormat('EEE, MMM d').format(_now);

  String? get _alarmLabel {
    final at = _alarm;
    if (at == null) return null;
    final sameDay = at.day == _now.day && at.month == _now.month;
    return sameDay
        ? DateFormat('HH:mm').format(at)
        : DateFormat('EEE HH:mm').format(at);
  }

  @override
  Widget build(BuildContext context) {
    final alarm = _alarmLabel;

    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: Center(
        child: AspectRatio(
          // Slightly wider than tall, like the launcher tile it is copying.
          aspectRatio: 1.28,
          child: Container(
            decoration: BoxDecoration(
              color: widget.background,
              // A very large radius is what gives the squircle look; clamped
              // so it cannot exceed half the height and turn into a stadium.
              borderRadius: BorderRadius.circular(
                (widget.height * 0.34).clamp(24.0, 72.0),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: (widget.height * 0.095).clamp(11.0, 20.0),
                    fontWeight: FontWeight.w500,
                    color: widget.accent,
                  ),
                ),
                // The hour takes whatever room is left, scaled to fit rather
                // than at a fixed size, so the card can be resized freely.
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        _time,
                        style: TextStyle(
                          fontSize: 96,
                          height: 1,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -2,
                          color: widget.timeColor,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.showAlarm)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.alarm,
                        size: (widget.height * 0.085).clamp(10.0, 18.0),
                        color: alarm == null
                            ? widget.accent.withValues(alpha: 0.4)
                            : widget.accent,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          alarm ?? 'No alarm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: (widget.height * 0.09).clamp(10.0, 19.0),
                            fontWeight: FontWeight.w500,
                            color: alarm == null
                                ? widget.accent.withValues(alpha: 0.4)
                                : widget.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
