import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/widgets/error_view.dart';
import '../providers/alerts_provider.dart';

class AlertConfigScreen extends ConsumerStatefulWidget {
  const AlertConfigScreen({super.key});

  @override
  ConsumerState<AlertConfigScreen> createState() => _AlertConfigScreenState();
}

class _AlertConfigScreenState extends ConsumerState<AlertConfigScreen> {
  bool _saving = false;

  // Editable state — initialised from fetched config
  bool? _enabled;
  double? _oversizeMl;
  TimeOfDay? _afterHoursStart;
  TimeOfDay? _afterHoursEnd;

  void _initFrom(Map<String, dynamic> config) {
    _enabled ??= config['enabled'] as bool? ?? true;
    if (_oversizeMl == null) {
      _oversizeMl =
          (config['oversizeThresholdMl'] as num?)?.toDouble() ?? 50.0;
    }
    if (_afterHoursStart == null) {
      _afterHoursStart = _parseTime(
          config['afterHoursStart'] as String? ?? '23:00');
    }
    if (_afterHoursEnd == null) {
      _afterHoursEnd = _parseTime(
          config['afterHoursEnd'] as String? ?? '06:00');
    }
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).put(
        '${ApiConstants.alerts}/config',
        data: {
          'enabled': _enabled,
          'oversizeThresholdMl': _oversizeMl?.round(),
          'afterHoursStart': _formatTime(_afterHoursStart!),
          'afterHoursEnd': _formatTime(_afterHoursEnd!),
        },
      );
      if (!mounted) return;
      ref.invalidate(alertConfigProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Alert settings saved'),
            backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to save'),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(alertConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Settings'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryDark))
                : const Text('Save',
                    style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Failed to load config',
          onRetry: () => ref.invalidate(alertConfigProvider),
        ),
        data: (config) {
          _initFrom(config);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Master toggle ───────────────────────────────────────────
              Card(
                child: SwitchListTile(
                  value: _enabled ?? true,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: const Text('Alerts enabled',
                      style: AppTextStyles.title),
                  subtitle: const Text('Turn off to silence all alerts',
                      style: AppTextStyles.caption),
                  activeColor: AppColors.primaryDark,
                ),
              ),

              const SizedBox(height: 20),

              // ── Oversize threshold ──────────────────────────────────────
              _Section(
                title: 'Oversize Pour Threshold',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_oversizeMl?.round() ?? 50} ml',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'triggers an alert',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    Slider(
                      value: _oversizeMl ?? 50,
                      min: 20,
                      max: 120,
                      divisions: 20,
                      activeColor: AppColors.primaryDark,
                      onChanged: (_enabled ?? true)
                          ? (v) => setState(() => _oversizeMl = v)
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('20 ml', style: AppTextStyles.caption),
                        const Text('120 ml', style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── After-hours window ──────────────────────────────────────
              _Section(
                title: 'After-Hours Window',
                child: Column(
                  children: [
                    _TimePicker(
                      label: 'Starts at',
                      time: _afterHoursStart ?? const TimeOfDay(hour: 23, minute: 0),
                      enabled: _enabled ?? true,
                      onChanged: (t) =>
                          setState(() => _afterHoursStart = t),
                    ),
                    const SizedBox(height: 12),
                    _TimePicker(
                      label: 'Ends at',
                      time: _afterHoursEnd ?? const TimeOfDay(hour: 6, minute: 0),
                      enabled: _enabled ?? true,
                      onChanged: (t) =>
                          setState(() => _afterHoursEnd = t),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pours between ${_formatTime(_afterHoursStart ?? const TimeOfDay(hour: 23, minute: 0))} '
                            'and ${_formatTime(_afterHoursEnd ?? const TimeOfDay(hour: 6, minute: 0))} '
                            'will be flagged.',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.title),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}

class _TimePicker extends StatelessWidget {
  const _TimePicker({
    required this.label,
    required this.time,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay time;
  final bool enabled;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled
            ? () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: time,
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context)
                          .colorScheme
                          .copyWith(primary: AppColors.primaryDark),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) onChanged(picked);
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? AppColors.primaryLight : AppColors.border,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time,
                  size: 18,
                  color: enabled
                      ? AppColors.primaryDark
                      : AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.body.copyWith(
                        color: enabled
                            ? AppColors.primaryDark
                            : AppColors.textMuted)),
              ),
              Text(
                time.format(context),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: enabled
                      ? AppColors.primaryDark
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
}
