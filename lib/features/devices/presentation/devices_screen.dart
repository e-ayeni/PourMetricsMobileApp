import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/devices_provider.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(devicesListProvider);
    final isAdmin = ref.watch(authProvider).valueOrNull?.role == 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Coasters'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Set up new coaster',
              onPressed: () => context.push('/devices/setup'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(devicesListProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Failed to load devices',
          onRetry: () => ref.invalidate(devicesListProvider),
        ),
        data: (devices) {
          final online =
              devices.where((d) => _isOnline(d)).length;
          return Column(
            children: [
              _SummaryBar(total: devices.length, online: online),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(devicesListProvider),
                  child: devices.isEmpty
                      ? const Center(
                          child: Text('No coasters registered',
                              style: AppTextStyles.caption))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: devices.length,
                          itemBuilder: (_, i) => _DeviceTile(
                              data: devices[i] as Map<String, dynamic>),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _isOnline(dynamic d) {
    final lastSeen = d['lastSeenAt'] as String?;
    if (lastSeen == null) return false;
    final diff =
        DateTime.now().difference(DateTime.parse(lastSeen));
    return diff.inMinutes < 10;
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.total, required this.online});

  final int total;
  final int online;

  @override
  Widget build(BuildContext context) {
    final offline = total - online;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _SummaryTile(
              label: 'Total', value: '$total', color: AppColors.info),
          const SizedBox(width: 24),
          _SummaryTile(
              label: 'Online', value: '$online', color: AppColors.success),
          const SizedBox(width: 24),
          _SummaryTile(
              label: 'Offline',
              value: '$offline',
              color: offline > 0 ? AppColors.error : AppColors.textMuted),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: AppTextStyles.caption),
        ],
      );
}

// ── Device tile ───────────────────────────────────────────────────────────────

class _DeviceTile extends StatefulWidget {
  const _DeviceTile({required this.data});

  final Map<String, dynamic> data;

  @override
  State<_DeviceTile> createState() => _DeviceTileState();
}

class _DeviceTileState extends State<_DeviceTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final name = d['coasterName'] as String? ?? 'Unknown Coaster';
    final location = d['barLocation'] as String? ?? '';
    final venue = d['venueName'] as String? ?? '';
    final firmware = d['firmwareVersion'] as String? ?? '—';
    final mac = d['macAddress'] as String? ?? '—';
    final batteryV = (d['batteryVoltage'] as num?)?.toDouble() ?? 0.0;
    final lastSeen = d['lastSeenAt'] as String?;

    final isOnline = lastSeen != null &&
        DateTime.now()
                .difference(DateTime.parse(lastSeen))
                .inMinutes <
            10;

    final batteryPct = _batteryPercent(batteryV);
    final batteryColor = batteryPct > 0.4
        ? AppColors.success
        : batteryPct > 0.15
            ? AppColors.warning
            : AppColors.error;

    final lastSeenLabel = lastSeen != null
        ? _relativeTime(DateTime.parse(lastSeen))
        : 'Never';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  // Status dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.title),
                        Text(
                          [if (location.isNotEmpty) location, if (venue.isNotEmpty) venue]
                              .join(' · '),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  // Battery
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(_batteryIcon(batteryPct),
                              color: batteryColor, size: 18),
                          const SizedBox(width: 4),
                          Text('${(batteryPct * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: batteryColor)),
                        ],
                      ),
                      Text(isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                              fontSize: 11,
                              color: isOnline
                                  ? AppColors.success
                                  : AppColors.error)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              // Battery bar
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: batteryPct,
                  minHeight: 4,
                  backgroundColor: AppColors.border,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(batteryColor),
                ),
              ),
              // Expanded details
              if (_expanded) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _DetailRow(
                    icon: Icons.access_time_outlined,
                    label: 'Last seen',
                    value: lastSeenLabel),
                const SizedBox(height: 8),
                _DetailRow(
                    icon: Icons.memory_outlined,
                    label: 'Firmware',
                    value: firmware),
                const SizedBox(height: 8),
                _DetailRow(
                    icon: Icons.wifi_outlined,
                    label: 'MAC address',
                    value: mac,
                    mono: true),
                const SizedBox(height: 8),
                _DetailRow(
                    icon: Icons.battery_charging_full_outlined,
                    label: 'Voltage',
                    value: '${batteryV.toStringAsFixed(2)} V'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  double _batteryPercent(double voltage) {
    // Approximate: 3.7V = full, 3.0V = empty
    return ((voltage - 3.0) / 0.7).clamp(0.0, 1.0);
  }

  IconData _batteryIcon(double pct) {
    if (pct > 0.75) return Icons.battery_full;
    if (pct > 0.5) return Icons.battery_5_bar;
    if (pct > 0.25) return Icons.battery_3_bar;
    if (pct > 0.1) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM HH:mm').format(dt);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text('$label  ', style: AppTextStyles.caption),
          Expanded(
            child: Text(
              value,
              style: mono ? AppTextStyles.mono : AppTextStyles.body,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}
