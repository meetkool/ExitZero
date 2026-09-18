import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/widget_manifest.dart';
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

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _installed = installed.toSet();
      _loading = false;
      _error = entries.isEmpty
          ? 'No widgets found. Check your connection, or the inventory has not been published yet.'
          : null;
    });
  }

  Future<void> _toggle(WidgetRegistryEntry entry) async {
    if (_installed.contains(entry.id)) {
      await InstalledWidgetsStore.uninstall(entry.id);
      await WidgetDataService.clear(entry.id);
      if (!mounted) return;
      setState(() => _installed.remove(entry.id));
      return;
    }

    final manifest = await WidgetRegistryService.fetchManifest(entry);
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
                '${_installed.length} installed  ·  ${_entries.length} available',
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

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.widgets_outlined,
                size: 40,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Nothing here yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => _load(force: true),
                icon: const Icon(Icons.refresh, color: AppColors.orange),
                label: const Text(
                  'Try again',
                  style: TextStyle(color: AppColors.orange),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.orange,
      backgroundColor: AppColors.dark,
      onRefresh: () => _load(force: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        itemCount: _entries.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == _entries.length) return _browseLink();
          return _row(_entries[i]);
        },
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
