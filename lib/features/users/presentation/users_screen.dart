import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/widgets/error_view.dart';
import '../providers/users_provider.dart';

const _roles = ['Admin', 'Manager', 'Bartender', 'Viewer'];

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(usersListProvider),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Invite user',
            onPressed: () => _showInviteDialog(context, ref),
          ),
        ],
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Failed to load team',
          onRetry: () => ref.invalidate(usersListProvider),
        ),
        data: (users) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(usersListProvider),
          child: users.isEmpty
              ? const Center(
                  child: Text('No users found', style: AppTextStyles.caption))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: users.length,
                  itemBuilder: (_, i) =>
                      _UserTile(data: users[i] as Map<String, dynamic>),
                ),
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _InviteDialog(ref: ref),
    );
  }
}

// ── User tile ─────────────────────────────────────────────────────────────────

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = data['id'] as String? ?? '';
    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final role = data['role'] as String? ?? 'Viewer';
    final isActive = data['isActive'] as bool? ?? true;
    final displayName =
        [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  isActive ? AppColors.primaryLight : AppColors.border,
              child: Text(
                initial,
                style: TextStyle(
                    color: isActive
                        ? AppColors.primaryDark
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                          displayName.isNotEmpty ? displayName : email,
                          style: AppTextStyles.body),
                      if (!isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('INACTIVE',
                              style: AppTextStyles.tag
                                  .copyWith(color: AppColors.error)),
                        ),
                      ],
                    ],
                  ),
                  Text(email, style: AppTextStyles.caption),
                ],
              ),
            ),
            // Role dropdown
            _RoleDropdown(
              userId: id,
              currentRole: role,
              isActive: isActive,
            ),
            // Deactivate / reactivate menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.textMuted, size: 20),
              onSelected: (action) =>
                  _handleAction(context, ref, id, action, isActive),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: isActive ? 'deactivate' : 'reactivate',
                  child: Row(
                    children: [
                      Icon(
                          isActive
                              ? Icons.block_outlined
                              : Icons.check_circle_outline,
                          color: isActive
                              ? AppColors.error
                              : AppColors.success,
                          size: 18),
                      const SizedBox(width: 8),
                      Text(isActive ? 'Deactivate' : 'Reactivate'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref,
      String id, String action, bool isActive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'deactivate' ? 'Deactivate user?' : 'Reactivate user?'),
        content: Text(action == 'deactivate'
            ? 'This user will lose access immediately.'
            : 'This user will regain access.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action == 'deactivate' ? 'Deactivate' : 'Reactivate',
                  style: TextStyle(
                      color: action == 'deactivate'
                          ? AppColors.error
                          : AppColors.success))),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(dioProvider).patch(
        '${ApiConstants.users}/$id',
        data: {'isActive': action == 'reactivate'},
      );
      ref.invalidate(usersListProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Action failed'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }
}

// ── Role dropdown ─────────────────────────────────────────────────────────────

class _RoleDropdown extends ConsumerWidget {
  const _RoleDropdown({
    required this.userId,
    required this.currentRole,
    required this.isActive,
  });

  final String userId;
  final String currentRole;
  final bool isActive;

  Color _roleColor(String role) => switch (role) {
        'Admin' => AppColors.error,
        'Manager' => AppColors.warning,
        'Bartender' => AppColors.primaryDark,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isActive ? () => _showRolePicker(context, ref) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _roleColor(currentRole).withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _roleColor(currentRole).withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentRole,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _roleColor(currentRole))),
            if (isActive) ...[
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down,
                  size: 16, color: _roleColor(currentRole)),
            ],
          ],
        ),
      ),
    );
  }

  void _showRolePicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _roles
              .map((r) => RadioListTile<String>(
                    title: Text(r),
                    value: r,
                    groupValue: currentRole,
                    activeColor: AppColors.primaryDark,
                    onChanged: (v) async {
                      Navigator.pop(ctx);
                      if (v == null || v == currentRole) return;
                      try {
                        await ref.read(dioProvider).patch(
                          '${ApiConstants.users}/$userId',
                          data: {'role': v},
                        );
                        ref.invalidate(usersListProvider);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Failed to update role'),
                                backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ── Invite dialog ─────────────────────────────────────────────────────────────

class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final _emailCtrl = TextEditingController();
  String _selectedRole = 'Bartender';
  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(dioProvider).post(
        '${ApiConstants.users}/invite',
        data: {'email': email, 'role': _selectedRole},
      );
      if (!mounted) return;
      ref.invalidate(usersListProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Invite sent to $email'),
            backgroundColor: AppColors.success),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to send invite'),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Team Member'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Role', style: AppTextStyles.label),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(),
            items: _roles
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setState(() => _selectedRole = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Send Invite'),
        ),
      ],
    );
  }
}
