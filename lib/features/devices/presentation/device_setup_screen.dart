import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class DeviceSetupScreen extends StatelessWidget {
  const DeviceSetupScreen({super.key});

  static const _portalIp = '192.168.4.1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up New Coaster')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Intro
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors, color: AppColors.primaryDark, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Before you start',
                          style: AppTextStyles.title),
                      const SizedBox(height: 4),
                      Text(
                        'Power on the coaster. The LED will pulse blue '
                        'while it waits to be configured.',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          _Step(
            number: 1,
            icon: Icons.wifi,
            title: 'Connect to the coaster\'s network',
            body: 'Open your phone\'s Wi-Fi settings and connect to the '
                'network named:',
            highlight: 'PourMetrics-XXXX',
            highlightNote: '(the last 4 characters are unique to each device)',
          ),

          _Step(
            number: 2,
            icon: Icons.open_in_browser,
            title: 'Open the setup page',
            body: 'A browser page should open automatically. If it doesn\'t, '
                'open your browser and go to:',
            highlight: _portalIp,
            onHighlightTap: () {
              Clipboard.setData(const ClipboardData(text: _portalIp));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('IP address copied')),
              );
            },
            highlightNote: 'Tap to copy',
          ),

          _Step(
            number: 3,
            icon: Icons.edit_outlined,
            title: 'Enter your network details',
            body: 'Fill in your venue\'s Wi-Fi name, password, and the '
                'PourMetrics backend URL, then tap Save & Connect.',
          ),

          _Step(
            number: 4,
            icon: Icons.check_circle_outline,
            title: 'Done',
            body: 'The coaster will reboot and connect to your network. '
                'Reconnect your phone to your normal Wi-Fi — '
                'the coaster will appear here within a minute.',
            isLast: true,
          ),

          const SizedBox(height: 28),

          // Re-provision note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'To re-configure a coaster (e.g. after a Wi-Fi change), '
                    'hold the BOOT button for 3 seconds while powering on. '
                    'This clears the saved credentials and restarts provisioning.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// ── Step card ─────────────────────────────────────────────────────────────────

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
    this.highlight,
    this.highlightNote,
    this.onHighlightTap,
    this.isLast = false,
  });

  final int number;
  final IconData icon;
  final String title;
  final String body;
  final String? highlight;
  final String? highlightNote;
  final VoidCallback? onHighlightTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryDark,
                child: Text('$number',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: AppColors.primaryDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(title, style: AppTextStyles.title),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: AppTextStyles.caption),
                  if (highlight != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: onHighlightTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(highlight!,
                                style: AppTextStyles.mono.copyWith(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700)),
                            if (onHighlightTap != null) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.copy,
                                  size: 14, color: AppColors.textMuted),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (highlightNote != null) ...[
                      const SizedBox(height: 4),
                      Text(highlightNote!,
                          style: AppTextStyles.caption.copyWith(
                              fontStyle: FontStyle.italic)),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
