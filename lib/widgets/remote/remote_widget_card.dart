import 'package:flutter/material.dart';
import '../../models/widget_manifest.dart';
import '../../services/widget_data_service.dart';
import '../../theme/app_theme.dart';
import '../bento_card.dart';
import 'remote_widget_renderer.dart';
import 'widget_dsl.dart';

/// Runtime for one installed remote widget.
///
/// Owns the data fetch and the loading / error states; the manifest owns
/// everything that gets drawn inside the card.
class RemoteWidgetCard extends StatefulWidget {
  final WidgetManifest manifest;
  final Map<String, String> config;

  const RemoteWidgetCard({
    super.key,
    required this.manifest,
    this.config = const {},
  });

  @override
  State<RemoteWidgetCard> createState() => _RemoteWidgetCardState();
}

class _RemoteWidgetCardState extends State<RemoteWidgetCard> {
  WidgetDataResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RemoteWidgetCard old) {
    super.didUpdateWidget(old);
    if (old.manifest.id != widget.manifest.id ||
        old.manifest.version != widget.manifest.version) {
      _load();
    }
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);

    final result = await WidgetDataService.load(
      widget.manifest,
      widget.config,
      forceRefresh: force,
    );

    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  Color get _accent =>
      WidgetColors.resolve(widget.manifest.accent, fallback: AppColors.orange);

  @override
  Widget build(BuildContext context) {
    final manifest = widget.manifest;

    // A manifest written for a newer app build: say so rather than drawing
    // half of it.
    if (!manifest.isSupported) {
      return _shell(
        child: _notice(
          icon: Icons.system_update,
          title: 'Update required',
          detail: '${manifest.name} needs a newer version of the app.',
        ),
      );
    }

    if (_loading && _result == null) {
      return _shell(
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(_accent),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
      );
    }

    final result = _result;

    // Only a hard failure with nothing cached becomes an error card.
    if (result != null && result.hasError && result.data == null) {
      return _shell(
        child: _notice(
          icon: Icons.cloud_off,
          title: manifest.name,
          detail: result.error ?? 'Unavailable',
          onRetry: () => _load(force: true),
        ),
      );
    }

    final ctx = WidgetBindingContext(
      data: result?.data,
      config: widget.config,
    );

    return _shell(
      onTap: () => _load(force: true),
      child: RemoteWidgetRenderer.buildBody(
        manifest.body,
        ctx,
        accent: _accent,
      ),
    );
  }

  Widget _shell({required Widget child, VoidCallback? onTap}) {
    return BentoCard(
      glassmorphism: false,
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: child,
    );
  }

  Widget _notice({
    required IconData icon,
    required String title,
    required String detail,
    VoidCallback? onRetry,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRetry,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 14, color: _accent),
                const SizedBox(width: 4),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
