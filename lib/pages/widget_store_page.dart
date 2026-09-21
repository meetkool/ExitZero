import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/widget_manifest.dart';
import '../services/builtin_widgets.dart';
import '../services/installed_widgets_store.dart';
import '../services/widget_data_service.dart';
import '../services/widget_registry_service.dart';
import '../services/widget_repo_config.dart';
import '../theme/app_theme.dart';
import '../widgets/remote/widget_dsl.dart';

/// The widget inventory: everything published in the widgets repo, with the
/// installed ones marked.
class WidgetStorePage extends StatefulWidget {
  const WidgetStorePage({super.key});

  @override
  State<WidgetStorePage> createState() => _WidgetStorePageState();
}

class _WidgetStorePageState extends State<WidgetStorePage> {
  List<WidgetRegistryEntry> _entries = const [];
  Set<String> _installed = {};
  Set<String> _hiddenBuiltIns = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final entries = await WidgetRegistryService.fetchRegistry(
      forceRefresh: force,
    );
    final installed = await InstalledWidgetsStore.installedIds();
    final hidden = await InstalledWidgetsStore.hiddenBuiltIns();

    // Pull fresh manifests for everything already installed.
    //
    // Without this an installed widget was frozen at whatever it looked like
    // on the day it was added: the dashboard reads manifests from the cache,
    // and only installing wrote to that cache. Publishing a fix to a widget
    // someone already had therefore never reached them, which defeats the
    // point of the inventory.
    if (force && installed.isNotEmpty) {
      final byId = {for (final e in entries) e.id: e};
      var changed = false;
      for (final id in installed) {
        final entry = byId[id];
        if (entry == null) continue;
        final fresh = await WidgetRegistryService.fetchManifest(
          entry,
          forceRefresh: true,
        );
        if (fresh != null) changed = true;
      }
      if (changed) InstalledWidgetsStore.notifyChanged();
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _installed = installed.toSet();
      _hiddenBuiltIns = hidden;
      _loading = false;
      _error = entries.isEmpty
          ? 'Could not reach the inventory. The widgets built into the app are still listed above.'
          : null;
    });
  }

  Future<void> _toggleBuiltIn(BuiltInWidget w, bool enabled) async {
    await InstalledWidgetsStore.setBuiltInEnabled(w.id, enabled);
    if (!mounted) return;
    setState(() {
      if (enabled) {
        _hiddenBuiltIns.remove(w.id);
      } else {
        _hiddenBuiltIns.add(w.id);
      }
    });
  }

  Future<void> _toggle(WidgetRegistryEntry entry) async {
    if (_installed.contains(entry.id)) {
      await InstalledWidgetsStore.uninstall(entry.id);
      await WidgetDataService.clear(entry.id);
      // Drop the cached manifest too, so removing and adding a widget back is
      // a genuine reset rather than handing the same stale copy over again.
      await WidgetRegistryService.forgetManifest(entry.id);
      if (!mounted) return;
      setState(() => _installed.remove(entry.id));
      return;
    }

    // Always go to the network when installing. Returning whatever happened
    // to be cached made adding a widget back a no-op: the user saw the old
    // version and had no way to reach the published one.
    final manifest = await WidgetRegistryService.fetchManifest(
      entry,
      forceRefresh: true,
    );
    if (!mounted) return;

    if (manifest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not download ${entry.name}.'),
          backgroundColor: AppColors.burnt,
        ),
      );
      return;
    }

    if (!manifest.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${entry.name} needs a newer version of the app.'),
          backgroundColor: AppColors.burnt,
        ),
      );
      return;
    }

    // Widgets that need a username or key ask for it before installing.
    Map<String, String> values = {};
    if (manifest.config.isNotEmpty) {
      final entered = await _askForConfig(manifest);
      if (entered == null) return;
      values = entered;
    }

    await InstalledWidgetsStore.install(entry.id, config: values);
    if (!mounted) return;
    setState(() => _installed.add(entry.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.name} added to your dashboard.'),
        backgroundColor: AppColors.teal,
      ),
    );
  }

  Future<Map<String, String>?> _askForConfig(WidgetManifest manifest) async {
    final controllers = {
      for (final f in manifest.config)
        f.key: TextEditingController(text: f.defaultValue),
    };

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.deep,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            manifest.name,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in manifest.config)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[f.key],
                    style: const TextStyle(color: Colors.white),
                    keyboardType: f.type == 'number'
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: f.label,
                      hintText: f.hint,
                      labelStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
            TextButton(
              onPressed: () {
                final values = <String, String>{};
                for (final f in manifest.config) {
                  values[f.key] = controllers[f.key]!.text.trim();
                }
                final missing = manifest.config.any(
                  (f) => f.required && (values[f.key] ?? '').isEmpty,
                );
                if (missing) return;
                Navigator.of(dialogContext).pop(values);
              },
              child: const Text(
                'Add',
                style: TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    for (final c in controllers.values) {
      c.dispose();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Widgets',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => _load(force: true),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '${BuiltInWidgets.all.length - _hiddenBuiltIns.length + _installed.length}'
                ' on your dashboard  ·  ${_entries.length} in the inventory',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orange),
      );
    }

    return RefreshIndicator(
      color: AppColors.orange,
      backgroundColor: AppColors.dark,
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        children: [
          _sectionLabel('BUILT IN'),
          const SizedBox(height: 10),
          for (final w in BuiltInWidgets.all) ...[
            _builtInRow(w),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          _sectionLabel('FROM THE INVENTORY'),
          const SizedBox(height: 10),
          if (_entries.isEmpty)
            _inventoryEmpty()
          else
            for (final e in _entries) ...[
              _row(e),
              const SizedBox(height: 12),
            ],
          _browseLink(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.6,
      color: Colors.white.withValues(alpha: 0.45),
    ),
  );

  /// A card that ships with the app. It cannot be removed, only switched off.
  Widget _builtInRow(BuiltInWidget w) {
    final enabled = !_hiddenBuiltIns.contains(w.id);
    final accent = WidgetColors.resolve(w.accent, fallback: AppColors.orange);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled
              ? accent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: enabled ? 0.2 : 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              WidgetIcons.resolve(w.icon),
              color: enabled ? accent : Colors.white.withValues(alpha: 0.3),
              size: 19,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: enabled ? 1 : 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  w.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: enabled ? 0.55 : 0.3),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) => _toggleBuiltIn(w, v),
            activeTrackColor: accent,
          ),
        ],
      ),
    );
  }

  Widget _inventoryEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off,
            size: 26,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? 'Nothing published yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _load(force: true),
            icon: const Icon(Icons.refresh, size: 16, color: AppColors.orange),
            label: const Text(
              'Try again',
              style: TextStyle(color: AppColors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(WidgetRegistryEntry entry) {
    final installed = _installed.contains(entry.id);
    final accent = WidgetColors.resolve(
      entry.accent,
      fallback: AppColors.orange,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: installed
              ? accent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              WidgetIcons.resolve(entry.icon),
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'v${entry.version}',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _toggle(entry),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: installed
                    ? Colors.white.withValues(alpha: 0.08)
                    : accent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: installed
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                installed ? 'Remove' : 'Add',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: installed
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.dark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _browseLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: TextButton.icon(
          onPressed: () async {
            final uri = Uri.parse(WidgetRepoConfig.browseUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          icon: Icon(
            Icons.open_in_new,
            size: 16,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          label: Text(
            'Browse the inventory on GitHub',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
