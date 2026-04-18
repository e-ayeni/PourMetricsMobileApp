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
        title: const Text('Devices'),
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
          final list = devices.cast<Map<String, dynamic>>();
          final online = list.where(_isOnline).length;
          final offline = list.length - online;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(devicesListProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _DeviceOverview(
                    total: list.length, online: online, offline: offline),
                const SizedBox(height: 20),
                const Text('Your coasters', style: AppTextStyles.title),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('No coasters registered',
                          style: AppTextStyles.caption),
                    ),
                  )
                else
                  ...list.map((device) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DeviceCard(data: device),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  static bool _isOnline(Map<String, dynamic> device) {
    final lastSeen = device['lastSeenAt'] as String?;
    if (lastSeen == null) return false;
    final diff = DateTime.now().difference(DateTime.parse(lastSeen));
    return diff.inMinutes < 10;
  }
}

class _DeviceOverview extends StatelessWidget {
  const _DeviceOverview({
    required this.total,
    required this.online,
    required this.offline,
  });

  final int total;
  final int online;
  final int offline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
              label: 'Total', value: '$total', color: AppColors.info),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
              label: 'Online', value: '$online', color: AppColors.success),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'Offline',
            value: '$offline',
            color: offline > 0 ? AppColors.error : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final id = data['id']?.toString() ?? '';
    final name = data['coasterName'] as String? ??
        data['barLocation'] as String? ??
        'Smart Coaster';
    final venueName = data['venueName'] as String?;
    final venueId = data['venueId']?.toString();
    final location = data['barLocation'] as String?;
    final currentBottle = data['currentBottle'] as Map<String, dynamic>?;
    final currentBottleName = currentBottle?['productName'] as String?;
    final firmware = data['firmwareVersion'] as String? ?? '—';
    final mac = data['macAddress'] as String? ?? '—';
    final batteryV = (data['batteryVoltage'] as num?)?.toDouble() ?? 0;
    final online = DevicesScreen._isOnline(data);
    final batteryPct = ((batteryV - 3.0) / 0.7).clamp(0.0, 1.0);
    final batteryColor = batteryPct > 0.4
        ? AppColors.success
        : batteryPct > 0.15
            ? AppColors.warning
            : AppColors.error;
    final lastSeenLabel = _relativeTime(data['lastSeenAt'] as String?);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    online ? AppColors.primaryLight : AppColors.surfaceMuted,
                child: Icon(
                  online ? Icons.sensors : Icons.sensors_off,
                  color: online ? AppColors.primaryDark : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.title),
                    Text(
                      [
                        if (location != null && location.isNotEmpty) location,
                        if (venueName != null && venueName.isNotEmpty) venueName
                      ].join(' · '),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: online ? 'Online' : 'Offline',
                color: online ? AppColors.success : AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Battery',
                  value: '${(batteryPct * 100).toStringAsFixed(0)}%',
                  color: batteryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  label: 'Last seen',
                  value: lastSeenLabel,
                  color: online ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (currentBottleName != null) ...[
            const SizedBox(height: 12),
            _ContextCard(
              icon: Icons.local_drink_outlined,
              title: 'Current bottle',
              subtitle: currentBottleName,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.push(
                  Uri(
                    path: '/inventory/add-product',
                    queryParameters: {
                      'mode': 'guided',
                      'deviceId': id,
                      'deviceName': name,
                      if (venueId != null) 'venueId': venueId,
                      if (venueName != null) 'venueName': venueName,
                    },
                  ).toString(),
                ),
                icon: const Icon(Icons.scale_outlined),
                label: const Text('Measure product'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push(
                  Uri(
                    path: '/inventory/register-bottle',
                    queryParameters: {
                      'deviceId': id,
                      'deviceName': name,
                      if (venueId != null) 'venueId': venueId,
                      if (venueName != null) 'venueName': venueName,
                    },
                  ).toString(),
                ),
                icon: const Icon(Icons.nfc_rounded),
                label: const Text('Register bottle'),
              ),
              if (currentBottle?['id'] != null)
                TextButton.icon(
                  onPressed: () =>
                      context.push('/inventory/bottle/${currentBottle!['id']}'),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View bottle'),
                ),
              if (!online)
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Check power, Wi-Fi, and device placement for this coaster.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('Troubleshoot'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Firmware $firmware · $mac', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  String _relativeTime(String? value) {
    if (value == null) return 'Never';
    final dt = DateTime.parse(value);
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM HH:mm').format(dt);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AppTextStyles.tag.copyWith(color: color)),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value,
              style: AppTextStyles.body
                  .copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
