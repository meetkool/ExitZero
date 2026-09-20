import 'package:flutter/material.dart';
import '../../services/camera_capability.dart';

/// Reports whether this phone can stream both lenses at once.
///
/// A diagnostic, not decoration: true dual-camera needs a native Camera2
/// session and optional hardware support, and there is no point building that
/// until the device has said whether it can do it.
class CameraCapabilityCard extends StatefulWidget {
  final Color color;
  final double height;

  const CameraCapabilityCard({
    super.key,
    required this.color,
    this.height = 150,
  });

  @override
  State<CameraCapabilityCard> createState() => _CameraCapabilityCardState();
}

class _CameraCapabilityCardState extends State<CameraCapabilityCard> {
  CameraCapability? _result;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run({bool force = false}) async {
    setState(() => _busy = true);
    final r = await CameraCapabilityService.probe(force: force);
    if (!mounted) return;
    setState(() {
      _result = r;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;

    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: _busy && r == null
          ? Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(widget.color),
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            )
          : _report(r!),
    );
  }

  Widget _report(CameraCapability r) {
    final good = r.supported;
    final tone = good ? const Color(0xFF2E9E5B) : const Color(0xFFE75414);

    return GestureDetector(
      onTap: () => _run(force: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                good ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: tone,
              ),
              const SizedBox(width: 7),
              Text(
                good ? 'BOTH AT ONCE: YES' : 'BOTH AT ONCE: NO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: tone,
                ),
              ),
            ],
          ),

          if (r.reason.isNotEmpty)
            Text(
              r.reason,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),

          if (r.pairs.isNotEmpty)
            Text(
              'Concurrent sets: ${r.pairs.map((p) => p.join('+')).join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),

          Text(
            [
              if (r.device.isNotEmpty) r.device,
              if (r.release.isNotEmpty) 'Android ${r.release} (API ${r.sdkInt})',
              '${r.frontCount} front · ${r.backCount} back',
            ].join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              height: 1.3,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
